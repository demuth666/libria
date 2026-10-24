import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/queued_write.dart';
import 'journal.dart';

/// Galat jurnal dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class JournalFailure implements Exception {
  const JournalFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses ke subkoleksi `users/{uid}/journals` di Firestore (T-060, FR-J1 dan
/// FR-J2).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk data jurnal; semua akses lewat kelas ini (lihat
/// [journalRepositoryProvider]).
class JournalRepository {
  JournalRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _journalsCollection(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.journals);
  }

  /// Menambahkan entri jurnal baru dan mengembalikan ID dokumennya.
  ///
  /// [sessionId] opsional (FR-J1); diisi saat jurnal dibuat dari tawaran
  /// setelah sesi (T-061). `createdAt` dan `updatedAt` memakai server
  /// timestamp.
  ///
  /// [queueOffline] diisi `true` saat perangkat tanpa koneksi agar penulisan
  /// langsung masuk antrean Firestore tanpa menunggu konfirmasi server.
  Future<String> addJournal({
    required String bookId,
    required String bookTitle,
    required String content,
    String? sessionId,
    bool queueOffline = false,
  }) async {
    final User user = _requireUser();
    final DocumentReference<Map<String, dynamic>> reference =
        _journalsCollection(user.uid).doc();
    final Journal journal = Journal(
      id: reference.id,
      bookId: bookId,
      bookTitle: bookTitle,
      content: content,
      sessionId: sessionId,
    );

    final Future<void> write = reference.set(journal.toMap());
    if (queueOffline) {
      queueOfflineWrite(write);
    } else {
      await _guardWrite<void>(
        () => write,
        mapError: mapFirestoreSaveError,
        fallback: AppStrings.journalSaveError,
      );
    }
    return reference.id;
  }

  /// Mengubah isi entri jurnal.
  ///
  /// Buku dan sesi terkait tidak dapat diubah; hanya `content` dan
  /// `updatedAt` yang ditulis agar `bookId`, `bookTitle`, `sessionId`, dan
  /// `createdAt` yang sudah ada tidak tertimpa.
  ///
  /// [queueOffline] diisi `true` saat perangkat tanpa koneksi.
  Future<void> updateJournal(
    String journalId, {
    required String content,
    bool queueOffline = false,
  }) async {
    final User user = _requireUser();
    final Future<void> write = _journalsCollection(user.uid)
        .doc(journalId)
        .update(<String, dynamic>{
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    if (queueOffline) {
      queueOfflineWrite(write);
      return;
    }
    await _guardWrite<void>(
      () => write,
      mapError: mapFirestoreSaveError,
      fallback: AppStrings.journalSaveError,
    );
  }

  /// Menghapus satu entri jurnal.
  Future<void> deleteJournal(String journalId) async {
    final User user = _requireUser();
    await _guardWrite<void>(
      () => _journalsCollection(user.uid).doc(journalId).delete(),
      mapError: mapFirestoreDeleteError,
      fallback: AppStrings.journalDeleteError,
    );
  }

  /// Stream jurnal pengguna, terbaru lebih dulu (FR-J2).
  ///
  /// [bookId] membatasi hasil ke satu buku; `null` menampilkan seluruh
  /// jurnal. Query memakai batas [limit] agar daftar panjang tetap
  /// berpaginasi. Snapshot default Firestore dipakai sehingga data cache
  /// tetap tampil saat offline.
  Stream<List<Journal>> watchJournals({String? bookId, int limit = 20}) {
    assert(limit > 0);
    return _guardRead(() {
      final User user = _requireUser();
      Query<Map<String, dynamic>> query = _journalsCollection(user.uid);
      if (bookId != null) {
        query = query.where('bookId', isEqualTo: bookId);
      }
      query = query.orderBy('createdAt', descending: true).limit(limit);
      return query.snapshots().map(
        (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  Journal.fromMap(doc.id, doc.data()),
            )
            .toList(growable: false),
      );
    });
  }

  /// Stream satu entri jurnal, atau `null` bila tidak ada.
  ///
  /// Dipakai formulir ubah agar perubahan dari layar lain langsung terlihat
  /// tanpa memuat ulang.
  Stream<Journal?> watchJournal(String journalId) {
    return _guardRead(() {
      final User user = _requireUser();
      return _journalsCollection(user.uid)
          .doc(journalId)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
            final Map<String, dynamic>? data = snapshot.data();
            return data == null ? null : Journal.fromMap(journalId, data);
          });
    });
  }

  /// Memeriksa isi jurnal. Mengembalikan `null` bila valid.
  static String? validateContent(String content) {
    if (content.trim().isEmpty) {
      return AppStrings.journalContentRequired;
    }
    return null;
  }

  /// Memetakan galat baca Firestore menjadi pesan bahasa Indonesia yang
  /// ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.journalLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.journalLoadPermissionDenied;
      default:
        return AppStrings.journalLoadError;
    }
  }

  /// Memetakan galat simpan Firestore menjadi pesan bahasa Indonesia yang
  /// ramah.
  static String mapFirestoreSaveError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.journalSaveNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.journalSavePermissionDenied;
      case 'not-found':
        return AppStrings.journalNotFound;
      default:
        return AppStrings.journalSaveError;
    }
  }

  /// Memetakan galat hapus Firestore menjadi pesan bahasa Indonesia yang
  /// ramah.
  static String mapFirestoreDeleteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.journalDeleteNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.journalDeletePermissionDenied;
      default:
        return AppStrings.journalDeleteError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const JournalFailure(AppStrings.journalSignInRequired);
    }
    return user;
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on JournalFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw JournalFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const JournalFailure(AppStrings.journalLoadError);
    }
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on JournalFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw JournalFailure(mapError(error));
    } on Exception {
      throw JournalFailure(fallback);
    }
  }
}

/// Akses [JournalRepository] bersama lewat Riverpod.
final Provider<JournalRepository> journalRepositoryProvider =
    Provider<JournalRepository>((Ref ref) => JournalRepository());
