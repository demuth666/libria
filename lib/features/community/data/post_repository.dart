import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../notifications/data/app_notification.dart';
import 'post.dart';
import 'reply.dart';

/// Batas jumlah postingan yang dimuat per halaman feed Komunitas.
const int postPageSize = 20;

/// Batas panjang isi postingan dalam karakter (FR-K2).
const int postContentMaxLength = 1000;

/// Batas jumlah balasan yang dimuat per halaman Detail Postingan.
const int replyPageSize = 20;

/// Galat postingan dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class PostFailure implements Exception {
  const PostFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses ke koleksi `posts` di Firestore (PRD bagian 8 dan 5.8).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk data postingan; semua akses lewat kelas ini (lihat
/// [postRepositoryProvider]). Feed dibaca sebagai stream dengan batas jumlah
/// dokumen, lalu [limit] dinaikkan bertahap oleh pengendali feed untuk memuat
/// halaman berikutnya.
class PostRepository {
  PostRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection(FirestorePaths.posts);

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.notifications);
  }

  /// Stream feed postingan terbaru (FR-K1).
  ///
  /// Hasil diurutkan `createdAt` menurun dan dibatasi [limit] dokumen. Snapshot
  /// default Firestore dipakai sehingga data cache tetap tampil saat offline.
  /// Halaman berikutnya dimuat dengan memanggil ulang method ini memakai
  /// [limit] yang lebih besar.
  Stream<List<Post>> watchFeed({int limit = postPageSize}) {
    final int pageSize = limit < 1 ? 1 : limit;
    return _guardRead(() {
      _requireUser();
      return _posts
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      Post.fromMap(doc.id, doc.data()),
                )
                .toList(growable: false),
          );
    });
  }

  /// Stream satu postingan berdasarkan ID untuk layar Detail Postingan.
  ///
  /// Dipakai agar jumlah balasan pada kartu postingan langsung berubah setiap
  /// kali balasan ditambah atau dihapus. Nilai `null` berarti dokumen sudah
  /// tidak ada. Snapshot default Firestore tetap dipakai sehingga postingan
  /// yang pernah dimuat masih tampil saat offline.
  Stream<Post?> watchPost(String id) {
    return _guardRead(() {
      _requireUser();
      return _posts.doc(id).snapshots().map((
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) {
          return null;
        }
        return Post.fromMap(snapshot.id, data);
      });
    });
  }

  /// Stream balasan sebuah postingan, terbaru lebih dulu (FR-K3).
  ///
  /// Hasil dibatasi [limit] dokumen. Halaman berikutnya dimuat dengan
  /// memanggil ulang method ini memakai [limit] yang lebih besar, mengikuti
  /// paginasi feed. Snapshot default Firestore dipakai sehingga balasan yang
  /// pernah dimuat tetap tampil saat offline.
  Stream<List<Reply>> watchReplies(String postId, {int limit = replyPageSize}) {
    final int pageSize = limit < 1 ? 1 : limit;
    return _guardRead(() {
      _requireUser();
      return _posts
          .doc(postId)
          .collection(FirestorePaths.replies)
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      Reply.fromMap(doc.id, doc.data()),
                )
                .toList(growable: false),
          );
    });
  }

  /// Mengambil satu postingan berdasarkan ID, atau `null` bila tidak ada.
  Future<Post?> getById(String id) async {
    try {
      _requireUser();
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _posts
          .doc(id)
          .get();
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Post.fromMap(snapshot.id, data);
    } on PostFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw PostFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const PostFailure(AppStrings.communityLoadError);
    }
  }

  /// Membuat postingan baru dan mengembalikan ID dokumennya (FR-K2).
  ///
  /// Penulis diambil dari pengguna yang sedang masuk agar sesuai aturan
  /// Firestore. Nama dan foto penulis memakai nilai yang diberikan bila ada,
  /// lalu data akun, dan terakhir nama cadangan. Jumlah like dan balasan
  /// dimulai dari nol.
  Future<String> createPost({
    required String content,
    String? authorName,
    String? authorPhotoUrl,
    String? bookId,
    String? bookTitle,
  }) async {
    final User user = _requireUser();
    final String? validationError = validateContent(content);
    if (validationError != null) {
      throw PostFailure(validationError);
    }

    final String? normalizedBookId = _normalizeOptionalText(bookId);
    final DocumentReference<Map<String, dynamic>> reference = _posts.doc();
    final Post post = Post(
      id: reference.id,
      authorId: user.uid,
      authorName: _resolveAuthorName(user, authorName),
      authorPhotoUrl:
          _normalizeOptionalText(authorPhotoUrl) ??
          _normalizeOptionalText(user.photoURL),
      content: content.trim(),
      bookId: normalizedBookId,
      bookTitle: normalizedBookId == null
          ? null
          : _normalizeOptionalText(bookTitle),
    );

    await _guardWrite<void>(
      () => reference.set(buildCreateMap(post)),
      mapError: mapFirestoreCreateError,
      fallback: AppStrings.communityPostCreateError,
    );
    return reference.id;
  }

  /// Menghapus postingan berdasarkan ID (FR-K6).
  Future<void> deletePost(String id) async {
    _requireUser();
    await _guardWrite<void>(
      () => _posts.doc(id).delete(),
      mapError: mapFirestoreDeleteError,
      fallback: AppStrings.communityPostDeleteError,
    );
  }

  /// Menambahkan balasan pada sebuah postingan (FR-K3).
  ///
  /// Dokumen balasan dan kenaikan `replyCount` ditulis dalam satu batch agar
  /// jumlah balasan pada postingan selalu bertambah bersama balasannya.
  /// Penulis diambil dari pengguna yang sedang masuk; nama dan foto memakai
  /// nilai yang diberikan bila ada, lalu data akun, dan terakhir nama
  /// cadangan.
  ///
  /// Bila balasan ditujukan pada postingan pengguna lain, batch yang sama juga
  /// membuat notifikasi `reply` untuk penulis postingan (T-086, FR-K8).
  Future<String> addReply({
    required String postId,
    required String content,
    String? authorName,
    String? authorPhotoUrl,
  }) async {
    final User user = _requireUser();
    final String? validationError = validateReplyContent(content);
    if (validationError != null) {
      throw PostFailure(validationError);
    }

    final DocumentReference<Map<String, dynamic>> postReference = _posts.doc(
      postId,
    );
    final DocumentReference<Map<String, dynamic>> replyReference = postReference
        .collection(FirestorePaths.replies)
        .doc();

    final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
        await _guardWrite<DocumentSnapshot<Map<String, dynamic>>>(
          () => postReference.get(),
          mapError: mapFirestoreReplyCreateError,
          fallback: AppStrings.communityReplyCreateError,
        );
    final Map<String, dynamic>? postData = postSnapshot.data();
    if (postData == null) {
      throw const PostFailure(AppStrings.communityPostNotFound);
    }
    final String postAuthorId = postData['authorId'] as String? ?? '';

    final Reply reply = Reply(
      id: replyReference.id,
      authorId: user.uid,
      authorName: _resolveAuthorName(user, authorName),
      authorPhotoUrl:
          _normalizeOptionalText(authorPhotoUrl) ??
          _normalizeOptionalText(user.photoURL),
      content: content.trim(),
    );

    await _guardWrite<void>(
      () {
        final WriteBatch batch = _firestore.batch();
        batch.set(replyReference, reply.toMap());
        batch.update(postReference, <String, dynamic>{
          'replyCount': FieldValue.increment(1),
        });
        if (postAuthorId.isNotEmpty && postAuthorId != user.uid) {
          final DocumentReference<Map<String, dynamic>> notificationReference =
              _notifications(postAuthorId).doc();
          batch.set(
            notificationReference,
            AppNotification(
              id: notificationReference.id,
              type: AppNotification.typeReply,
              actorId: user.uid,
              actorName: reply.authorName,
              refType: AppNotification.refTypePost,
              refId: postId,
              text: AppStrings.notificationReplyText(reply.authorName),
            ).toMap(),
          );
        }
        return batch.commit();
      },
      mapError: mapFirestoreReplyCreateError,
      fallback: AppStrings.communityReplyCreateError,
    );
    return replyReference.id;
  }

  /// Menghapus balasan milik pengguna yang sedang masuk (FR-K6).
  ///
  /// Kepemilikan diperiksa lebih dulu, lalu dokumen balasan dan penurunan
  /// `replyCount` ditulis dalam satu batch agar jumlah balasan tetap sinkron.
  Future<void> deleteReply({
    required String postId,
    required String replyId,
  }) async {
    final User user = _requireUser();
    final DocumentReference<Map<String, dynamic>> postReference = _posts.doc(
      postId,
    );
    final DocumentReference<Map<String, dynamic>> replyReference = postReference
        .collection(FirestorePaths.replies)
        .doc(replyId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _guardWrite<DocumentSnapshot<Map<String, dynamic>>>(
          () => replyReference.get(),
          mapError: mapFirestoreReplyDeleteError,
          fallback: AppStrings.communityReplyDeleteError,
        );
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      throw const PostFailure(AppStrings.communityReplyNotFound);
    }
    if (data['authorId'] != user.uid) {
      throw const PostFailure(AppStrings.communityReplyDeleteNotAllowed);
    }

    await _guardWrite<void>(
      () {
        final WriteBatch batch = _firestore.batch();
        batch.delete(replyReference);
        batch.update(postReference, <String, dynamic>{
          'replyCount': FieldValue.increment(-1),
        });
        return batch.commit();
      },
      mapError: mapFirestoreReplyDeleteError,
      fallback: AppStrings.communityReplyDeleteError,
    );
  }

  /// Memeriksa isi postingan. Mengembalikan `null` bila valid.
  ///
  /// Isi wajib terisi dan tidak boleh melebihi [postContentMaxLength] karakter
  /// setelah spasi di awal dan akhir dibuang.
  static String? validateContent(String content) {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return AppStrings.communityPostContentRequired;
    }
    if (trimmed.length > postContentMaxLength) {
      return AppStrings.communityPostContentTooLong(postContentMaxLength);
    }
    return null;
  }

  /// Memeriksa isi balasan. Mengembalikan `null` bila valid.
  static String? validateReplyContent(String content) {
    if (content.trim().isEmpty) {
      return AppStrings.communityReplyContentRequired;
    }
    return null;
  }

  /// Peta field untuk membuat dokumen postingan baru.
  ///
  /// Bebas dari akses Firestore sehingga bisa diuji langsung. Penulis dan
  /// `createdAt` diisi sesuai aturan keamanan; `likeCount` dan `replyCount`
  /// dipaksa nol karena aturan hanya mengizinkan nilai awal itu.
  static Map<String, dynamic> buildCreateMap(Post post) {
    return <String, dynamic>{
      'authorId': post.authorId,
      'authorName': post.authorName,
      'authorPhotoUrl': post.authorPhotoUrl,
      'content': post.content.trim(),
      'bookId': post.bookId,
      'bookTitle': post.bookTitle,
      'likeCount': 0,
      'replyCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Memetakan galat baca Firestore menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityLoadPermissionDenied;
      default:
        return AppStrings.communityLoadError;
    }
  }

  /// Memetakan galat pembuatan postingan menjadi pesan yang ramah.
  static String mapFirestoreCreateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityPostCreateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityPostCreatePermissionDenied;
      default:
        return AppStrings.communityPostCreateError;
    }
  }

  /// Memetakan galat hapus postingan menjadi pesan yang ramah.
  static String mapFirestoreDeleteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityPostDeleteNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityPostDeletePermissionDenied;
      default:
        return AppStrings.communityPostDeleteError;
    }
  }

  /// Memetakan galat pembuatan balasan menjadi pesan yang ramah.
  static String mapFirestoreReplyCreateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityReplyCreateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityReplyCreatePermissionDenied;
      default:
        return AppStrings.communityReplyCreateError;
    }
  }

  /// Memetakan galat hapus balasan menjadi pesan yang ramah.
  static String mapFirestoreReplyDeleteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityReplyDeleteNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityReplyDeletePermissionDenied;
      default:
        return AppStrings.communityReplyDeleteError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const PostFailure(AppStrings.communitySignInRequired);
    }
    return user;
  }

  static String _resolveAuthorName(User user, String? authorName) {
    final String provided = authorName?.trim() ?? '';
    if (provided.isNotEmpty) {
      return provided;
    }
    final String accountName = user.displayName?.trim() ?? '';
    if (accountName.isNotEmpty) {
      return accountName;
    }
    return AppStrings.communityPostAuthorFallback;
  }

  static String? _normalizeOptionalText(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
      throw const PostFailure(AppStrings.communityLoadError);
    }
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on PostFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw PostFailure(mapError(error));
    } on Exception {
      throw PostFailure(fallback);
    }
  }
}

/// Akses [PostRepository] bersama lewat Riverpod.
final Provider<PostRepository> postRepositoryProvider =
    Provider<PostRepository>((Ref ref) => PostRepository());
