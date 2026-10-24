import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/queued_write.dart';
import '../../notifications/data/app_notification.dart';
import 'post_like.dart';
import 'post_repository.dart';

/// Akses dokumen like `posts/{postId}/likes/{uid}` (T-083, FR-K4).
///
/// ID dokumen like sama dengan UID pengguna, sehingga satu pengguna hanya
/// dapat menyukai satu postingan satu kali. Toggle menulis atau menghapus
/// dokumen like dan mengubah `likeCount` postingan dalam transaksi yang sama
/// agar hitungan selalu sinkron.
class PostLikeRepository {
  PostLikeRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection(FirestorePaths.posts);

  DocumentReference<Map<String, dynamic>> _post(String postId) =>
      _posts.doc(postId);

  DocumentReference<Map<String, dynamic>> _like(String postId, String uid) =>
      _post(postId).collection(FirestorePaths.likes).doc(uid);

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.notifications);
  }

  /// Stream status like pengguna saat ini untuk [postId].
  ///
  /// Snapshot default Firestore dipakai agar status dari cache tetap tampil
  /// saat offline. Hasil `true` berarti dokumen like milik pengguna ada.
  Stream<bool> watchIsLiked(String postId) {
    return _guardRead(() {
      final User user = _requireUser();
      return _like(postId, user.uid).snapshots().map(
        (DocumentSnapshot<Map<String, dynamic>> snapshot) => snapshot.exists,
      );
    });
  }

  /// Menyukai atau membatalkan like postingan [postId] untuk pengguna saat
  /// ini, lalu mengembalikan status dan jumlah like terbaru.
  ///
  /// Dokumen like dan `likeCount` diubah dalam satu transaksi. Karena ID
  /// dokumen like adalah UID pengguna, menekan like berulang kali hanya
  /// berganti antara menambah dan mengurangi satu, tidak pernah menambah dua
  /// kali untuk pengguna yang sama.
  ///
  /// Saat like baru dibuat pada postingan pengguna lain, transaksi yang sama
  /// juga membuat notifikasi `like` untuk penulis postingan (T-086, FR-K8).
  /// Notifikasi hanya dibuat di cabang pembuatan like, sehingga satu like
  /// tidak pernah menghasilkan notifikasi ganda.
  ///
  /// Transaksi tidak dapat berjalan saat offline. Bila [queueOffline] bernilai
  /// `true`, perubahan like dan `likeCount` ditulis lewat batch agar masuk
  /// antrean Firestore. [wasLiked] dan [likeCount] adalah nilai yang sedang
  /// tampil di layar, dipakai untuk menghitung hasil tanpa menunggu server.
  Future<PostLikeResult> toggleLike(
    String postId, {
    bool queueOffline = false,
    bool wasLiked = false,
    int likeCount = 0,
  }) async {
    final User user = _requireUser();
    if (queueOffline) {
      return _queueOfflineToggle(
        postId: postId,
        user: user,
        wasLiked: wasLiked,
        currentCount: likeCount,
      );
    }
    return _guardWrite(
      () => _firestore.runTransaction<PostLikeResult>((
        Transaction transaction,
      ) async {
        final DocumentReference<Map<String, dynamic>> postReference = _post(
          postId,
        );
        final DocumentReference<Map<String, dynamic>> likeReference = _like(
          postId,
          user.uid,
        );
        final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
            await transaction.get(postReference);
        if (!postSnapshot.exists) {
          throw const PostFailure(AppStrings.communityPostNotFound);
        }
        final DocumentSnapshot<Map<String, dynamic>> likeSnapshot =
            await transaction.get(likeReference);
        final int currentCount = _readLikeCount(postSnapshot.data());
        final String postAuthorId =
            postSnapshot.data()?['authorId'] as String? ?? '';

        if (likeSnapshot.exists) {
          transaction.delete(likeReference);
          if (currentCount <= 0) {
            return const PostLikeResult(isLiked: false, likeCount: 0);
          }
          transaction.update(postReference, <String, dynamic>{
            'likeCount': FieldValue.increment(-1),
          });
          return PostLikeResult(isLiked: false, likeCount: currentCount - 1);
        }

        transaction.set(likeReference, <String, dynamic>{
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postReference, <String, dynamic>{
          'likeCount': FieldValue.increment(1),
        });
        if (postAuthorId.isNotEmpty && postAuthorId != user.uid) {
          final String actorName = _actorName(user);
          final DocumentReference<Map<String, dynamic>> notificationReference =
              _notifications(postAuthorId).doc();
          transaction.set(
            notificationReference,
            AppNotification(
              id: notificationReference.id,
              type: AppNotification.typeLike,
              actorId: user.uid,
              actorName: actorName,
              refType: AppNotification.refTypePost,
              refId: postId,
              text: AppStrings.notificationLikeText(actorName),
            ).toMap(),
          );
        }
        return PostLikeResult(isLiked: true, likeCount: currentCount + 1);
      }),
      fallback: AppStrings.communityLikeError,
    );
  }

  /// Menulis perubahan like lewat batch saat perangkat offline.
  ///
  /// Penulis postingan dibaca dari cache untuk notifikasi. Bila cache tidak
  /// tersedia, like tetap ditulis dan notifikasi dilewati agar aksi utama
  /// pengguna tidak gagal.
  Future<PostLikeResult> _queueOfflineToggle({
    required String postId,
    required User user,
    required bool wasLiked,
    required int currentCount,
  }) async {
    String postAuthorId = '';
    try {
      final DocumentSnapshot<Map<String, dynamic>> postSnapshot = await _post(
        postId,
      ).get();
      postAuthorId = postSnapshot.data()?['authorId'] as String? ?? '';
    } on FirebaseException {
      // Postingan tidak ada di cache; notifikasi dilewati.
    }

    final DocumentReference<Map<String, dynamic>> postReference = _post(postId);
    final DocumentReference<Map<String, dynamic>> likeReference = _like(
      postId,
      user.uid,
    );
    final WriteBatch batch = _firestore.batch();

    if (wasLiked) {
      batch.delete(likeReference);
      if (currentCount > 0) {
        batch.update(postReference, <String, dynamic>{
          'likeCount': FieldValue.increment(-1),
        });
      }
      queueOfflineWrite(batch.commit());
      return PostLikeResult(
        isLiked: false,
        likeCount: currentCount > 0 ? currentCount - 1 : 0,
      );
    }

    batch.set(likeReference, <String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(postReference, <String, dynamic>{
      'likeCount': FieldValue.increment(1),
    });
    if (postAuthorId.isNotEmpty && postAuthorId != user.uid) {
      final String actorName = _actorName(user);
      final DocumentReference<Map<String, dynamic>> notificationReference =
          _notifications(postAuthorId).doc();
      batch.set(
        notificationReference,
        AppNotification(
          id: notificationReference.id,
          type: AppNotification.typeLike,
          actorId: user.uid,
          actorName: actorName,
          refType: AppNotification.refTypePost,
          refId: postId,
          text: AppStrings.notificationLikeText(actorName),
        ).toMap(),
      );
    }
    queueOfflineWrite(batch.commit());
    return PostLikeResult(isLiked: true, likeCount: currentCount + 1);
  }

  /// Memetakan galat baca status like menjadi pesan yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityLikeStatusNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityLikeStatusPermissionDenied;
      default:
        return AppStrings.communityLikeStatusError;
    }
  }

  /// Memetakan galat toggle like menjadi pesan yang ramah.
  static String mapFirestoreWriteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityLikeNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityLikePermissionDenied;
      case 'not-found':
        return AppStrings.communityPostNotFound;
      default:
        return AppStrings.communityLikeError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const PostFailure(AppStrings.communitySignInRequired);
    }
    return user;
  }

  static int _readLikeCount(Map<String, dynamic>? data) {
    final int count = (data?['likeCount'] as num?)?.toInt() ?? 0;
    return count < 0 ? 0 : count;
  }

  static String _actorName(User user) {
    final String name = user.displayName?.trim() ?? '';
    return name.isEmpty ? AppStrings.communityPostAuthorFallback : name;
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on PostFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw PostFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const PostFailure(AppStrings.communityLikeStatusError);
    }
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String fallback,
  }) async {
    try {
      return await action();
    } on PostFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw PostFailure(mapFirestoreWriteError(error));
    } on Exception {
      throw PostFailure(fallback);
    }
  }
}

/// Akses [PostLikeRepository] bersama lewat Riverpod.
final Provider<PostLikeRepository> postLikeRepositoryProvider =
    Provider<PostLikeRepository>((Ref ref) => PostLikeRepository());
