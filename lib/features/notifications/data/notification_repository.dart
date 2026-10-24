import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import 'app_notification.dart';

/// Batas jumlah notifikasi yang dimuat per halaman.
const int notificationPageSize = 30;

/// Batas jumlah dokumen yang diubah dalam satu batch saat menandai semua
/// notifikasi terbaca. Firestore membatasi satu batch maksimal 500 operasi.
const int _notificationBatchSize = 400;

/// Galat notifikasi dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class NotificationFailure implements Exception {
  const NotificationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses subkoleksi `users/{uid}/notifications` (PRD bagian 8, FR-K8).
///
/// Widget tidak memanggil Firestore secara langsung; daftar notifikasi,
/// jumlah belum dibaca, dan perubahan status baca semuanya lewat kelas ini
/// (lihat [notificationRepositoryProvider]).
class NotificationRepository {
  NotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.notifications);
  }

  /// Stream notifikasi terbaru lebih dulu dengan batas [limit] dokumen.
  ///
  /// Snapshot default Firestore dipakai sehingga notifikasi yang pernah
  /// dimuat tetap tampil saat offline. Halaman berikutnya dimuat dengan
  /// memanggil ulang method ini memakai [limit] yang lebih besar.
  Stream<List<AppNotification>> watchNotifications({
    int limit = notificationPageSize,
  }) {
    final int pageSize = limit < 1 ? 1 : limit;
    return _guardRead(() {
      final User user = _requireUser();
      return _notifications(user.uid)
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      AppNotification.fromMap(doc.id, doc.data()),
                )
                .toList(growable: false),
          );
    });
  }

  /// Stream jumlah notifikasi yang belum dibaca untuk lencana Beranda.
  ///
  /// Query hanya memakai satu filter (`read == false`) sehingga tidak
  /// membutuhkan indeks komposit tambahan.
  Stream<int> watchUnreadCount() {
    return _guardRead(() {
      final User user = _requireUser();
      return _notifications(user.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                snapshot.docs.length,
          );
    });
  }

  /// Menandai satu notifikasi sebagai sudah dibaca.
  Future<void> markRead(String notificationId) async {
    final User user = _requireUser();
    await _guardWrite<void>(
      () =>
          _notifications(user.uid)
              .doc(notificationId)
              .update(<String, dynamic>{'read': true}),
      fallback: AppStrings.notificationsUpdateError,
    );
  }

  /// Menandai semua notifikasi yang belum dibaca sebagai sudah dibaca.
  ///
  /// Mengembalikan jumlah notifikasi yang diperbarui. Dokumen diubah per
  /// batch agar jumlah notifikasi yang banyak tetap aman.
  Future<int> markAllRead() async {
    final User user = _requireUser();
    return _guardWrite<int>(() async {
      final CollectionReference<Map<String, dynamic>> collection =
          _notifications(user.uid);
      int updated = 0;
      while (true) {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await collection
            .where('read', isEqualTo: false)
            .limit(_notificationBatchSize)
            .get();
        if (snapshot.docs.isEmpty) {
          break;
        }
        final WriteBatch batch = _firestore.batch();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          batch.update(doc.reference, <String, dynamic>{'read': true});
        }
        await batch.commit();
        updated += snapshot.docs.length;
        if (snapshot.docs.length < _notificationBatchSize) {
          break;
        }
      }
      return updated;
    }, fallback: AppStrings.notificationsUpdateError);
  }

  /// Memetakan galat baca Firestore menjadi pesan yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.notificationsLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.notificationsLoadPermissionDenied;
      default:
        return AppStrings.notificationsLoadError;
    }
  }

  /// Memetakan galat ubah status baca menjadi pesan yang ramah.
  static String mapFirestoreWriteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.notificationsUpdateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.notificationsUpdatePermissionDenied;
      default:
        return AppStrings.notificationsUpdateError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const NotificationFailure(AppStrings.notificationsSignInRequired);
    }
    return user;
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on NotificationFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw NotificationFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const NotificationFailure(AppStrings.notificationsLoadError);
    }
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String fallback,
  }) async {
    try {
      return await action();
    } on NotificationFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw NotificationFailure(mapFirestoreWriteError(error));
    } on Exception {
      throw NotificationFailure(fallback);
    }
  }
}

/// Akses [NotificationRepository] bersama lewat Riverpod.
final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>((Ref ref) => NotificationRepository());
