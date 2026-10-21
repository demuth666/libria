import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../books/data/book.dart';
import 'library_entry.dart';

/// Galat perpustakaan pribadi dengan pesan yang sudah ramah pengguna dalam
/// bahasa Indonesia, siap ditampilkan langsung ke layar.
class LibraryFailure implements Exception {
  const LibraryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hasil aturan status otomatis ketika halaman terakhir berubah (FR-L4).
class LibraryPageProgress {
  const LibraryPageProgress({
    required this.status,
    required this.reachedLastPage,
  });

  final String status;

  /// `true` bila halaman yang diubah mencapai halaman terakhir, sehingga
  /// status menjadi selesai dan `finishedAt` harus diisi server timestamp.
  final bool reachedLastPage;
}

/// Akses ke subkoleksi `users/{uid}/library` di Firestore (PRD bagian 8).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk data rak; semua akses lewat kelas ini (lihat
/// [libraryRepositoryProvider]).
class LibraryRepository {
  LibraryRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  static const Set<String> _statuses = <String>{
    LibraryEntry.statusWant,
    LibraryEntry.statusReading,
    LibraryEntry.statusFinished,
  };

  CollectionReference<Map<String, dynamic>> _libraryCollection(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.library);
  }

  /// Menentukan status setelah halaman terakhir diubah (FR-L4).
  ///
  /// Buku otomatis selesai hanya bila [currentPage] sama dengan
  /// [bookTotalPages] dan total halaman lebih dari 0. Halaman yang belum
  /// mencapai akhir tidak mengubah status, termasuk status Selesai yang
  /// dipilih manual. Fungsi ini murni agar aturan dapat diuji tanpa
  /// Firestore.
  static LibraryPageProgress progressForPage({
    required String currentStatus,
    required int currentPage,
    required int bookTotalPages,
  }) {
    final bool reachedLastPage =
        bookTotalPages > 0 && currentPage == bookTotalPages;
    return LibraryPageProgress(
      status: reachedLastPage ? LibraryEntry.statusFinished : currentStatus,
      reachedLastPage: reachedLastPage,
    );
  }

  /// Menambahkan [book] ke rak pengguna dengan [status] awal.
  ///
  /// Hanya salinan ringkas buku yang ditulis, sehingga koleksi `books` tidak
  /// dibaca ulang. Bila entri sudah ada, dokumen dibiarkan apa adanya agar
  /// halaman terakhir, tanggal, dan status yang sudah tercatat tidak hilang.
  /// `addedAt` memakai server timestamp dan `finishedAt` dimulai kosong.
  Future<void> addBook(
    Book book, {
    String status = LibraryEntry.statusWant,
  }) async {
    _validateStatus(status);
    final User user = _requireUser();
    final DocumentReference<Map<String, dynamic>> entry = _libraryCollection(
      user.uid,
    ).doc(book.id);

    await _guardWrite<void>(
      () => _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(entry);
        if (snapshot.exists) {
          return;
        }
        transaction.set(
          entry,
          LibraryEntry(
            bookId: book.id,
            status: status,
            bookTitle: book.title,
            bookAuthor: book.author,
            bookCoverUrl: book.coverUrl,
            bookTotalPages: book.totalPages,
          ).toMap(),
        );
      }),
      mapError: mapFirestoreAddError,
      fallback: AppStrings.libraryAddError,
    );
  }

  /// Mengubah status buku secara manual (FR-L3).
  ///
  /// Saat status menjadi [LibraryEntry.statusFinished], `finishedAt` diisi
  /// server timestamp. Saat berpindah ke [LibraryEntry.statusWant] atau
  /// [LibraryEntry.statusReading], `finishedAt` dikosongkan. `currentPage`,
  /// salinan buku, dan `addedAt` tidak berubah.
  Future<void> updateStatus(String bookId, String status) async {
    _validateStatus(status);
    final User user = _requireUser();
    await _guardWrite<void>(
      () => _libraryCollection(user.uid).doc(bookId).update(<String, dynamic>{
        'status': status,
        'finishedAt': status == LibraryEntry.statusFinished
            ? FieldValue.serverTimestamp()
            : null,
      }),
      mapError: mapFirestoreStatusError,
      fallback: AppStrings.libraryStatusError,
    );
  }

  /// Memperbarui halaman terakhir yang dibaca beserta status otomatisnya
  /// (FR-L4).
  ///
  /// Status dibaca di dalam transaksi agar keputusan selesai otomatis memakai
  /// nilai terbaru. `finishedAt` hanya ditulis saat halaman mencapai akhir;
  /// perubahan halaman lain membiarkan tanggal selesai yang sudah ada.
  Future<void> updateCurrentPage(String bookId, int currentPage) async {
    if (currentPage < 0) {
      throw const LibraryFailure(AppStrings.libraryInvalidPage);
    }
    final User user = _requireUser();
    final DocumentReference<Map<String, dynamic>> entry = _libraryCollection(
      user.uid,
    ).doc(bookId);

    await _guardWrite<void>(
      () => _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(entry);
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) {
          throw const LibraryFailure(AppStrings.libraryEntryNotFound);
        }
        final LibraryEntry current = LibraryEntry.fromMap(bookId, data);
        final LibraryPageProgress progress = progressForPage(
          currentStatus: current.status,
          currentPage: currentPage,
          bookTotalPages: current.bookTotalPages,
        );
        final Map<String, dynamic> fields = <String, dynamic>{
          'currentPage': currentPage,
          'status': progress.status,
        };
        if (progress.reachedLastPage) {
          fields['finishedAt'] = FieldValue.serverTimestamp();
        }
        transaction.update(entry, fields);
      }),
      mapError: mapFirestorePageError,
      fallback: AppStrings.libraryPageError,
    );
  }

  /// Menghapus satu buku dari rak pengguna.
  Future<void> removeBook(String bookId) async {
    final User user = _requireUser();
    await _guardWrite<void>(
      () => _libraryCollection(user.uid).doc(bookId).delete(),
      mapError: mapFirestoreDeleteError,
      fallback: AppStrings.libraryDeleteError,
    );
  }

  /// Stream seluruh rak, terbaru lebih dulu.
  ///
  /// Memakai snapshot default Firestore sehingga data dari cache tetap tampil
  /// saat offline (FR-L6), lalu diperbarui saat server tersedia.
  Stream<List<LibraryEntry>> watchLibrary() {
    return _guardRead(() {
      final User user = _requireUser();
      final Query<Map<String, dynamic>> query = _libraryCollection(user.uid)
          .orderBy('addedAt', descending: true);
      return query.snapshots().map(
        (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  LibraryEntry.fromMap(doc.id, doc.data()),
            )
            .toList(growable: false),
      );
    });
  }

  /// Stream satu entri rak, atau `null` bila entri belum ada.
  Stream<LibraryEntry?> watchEntry(String bookId) {
    return _guardRead(() {
      final User user = _requireUser();
      return _libraryCollection(user.uid)
          .doc(bookId)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
            final Map<String, dynamic>? data = snapshot.data();
            return data == null ? null : LibraryEntry.fromMap(bookId, data);
          });
    });
  }

  /// Memetakan galat baca Firestore menjadi pesan bahasa Indonesia yang ramah.
  ///
  /// Dipakai sebagai `static` agar pemetaan dapat diuji tanpa instance
  /// `FirebaseFirestore` yang hidup.
  static String mapFirestoreReadError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.libraryLoadNetworkError,
      permissionDenied: AppStrings.libraryLoadPermissionDenied,
      fallback: AppStrings.libraryLoadError,
    );
  }

  /// Memetakan galat tambah buku menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestoreAddError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.libraryAddNetworkError,
      permissionDenied: AppStrings.libraryAddPermissionDenied,
      fallback: AppStrings.libraryAddError,
    );
  }

  /// Memetakan galat ubah status menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestoreStatusError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.libraryStatusNetworkError,
      permissionDenied: AppStrings.libraryStatusPermissionDenied,
      fallback: AppStrings.libraryStatusError,
      notFound: AppStrings.libraryEntryNotFound,
    );
  }

  /// Memetakan galat ubah halaman menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestorePageError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.libraryPageNetworkError,
      permissionDenied: AppStrings.libraryPagePermissionDenied,
      fallback: AppStrings.libraryPageError,
      notFound: AppStrings.libraryEntryNotFound,
    );
  }

  /// Memetakan galat hapus buku menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestoreDeleteError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.libraryDeleteNetworkError,
      permissionDenied: AppStrings.libraryDeletePermissionDenied,
      fallback: AppStrings.libraryDeleteError,
    );
  }

  static String _mapFirestoreError(
    FirebaseException error, {
    required String network,
    required String permissionDenied,
    required String fallback,
    String? notFound,
  }) {
    if (notFound != null && error.code == 'not-found') {
      return notFound;
    }
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return network;
      case 'permission-denied':
      case 'unauthenticated':
        return permissionDenied;
      default:
        return fallback;
    }
  }

  static void _validateStatus(String status) {
    if (!_statuses.contains(status)) {
      throw const LibraryFailure(AppStrings.libraryInvalidStatus);
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const LibraryFailure(AppStrings.librarySignInRequired);
    }
    return user;
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on LibraryFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw LibraryFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const LibraryFailure(AppStrings.libraryLoadError);
    }
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on LibraryFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw LibraryFailure(mapError(error));
    } on Exception {
      throw LibraryFailure(fallback);
    }
  }
}

/// Akses [LibraryRepository] bersama lewat Riverpod.
final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>((Ref ref) => LibraryRepository());
