import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/isbn.dart';
import 'isbn_log.dart';

/// Batas jumlah log ISBN per halaman pada daftar antrean admin.
const int isbnLogPageSize = 20;

/// Batas maksimum jumlah log ISBN per halaman yang diterima repository.
const int isbnLogMaxPageSize = 50;

/// Galat log ISBN dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class IsbnLogFailure implements Exception {
  const IsbnLogFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kursor halaman berikutnya pada [IsbnLogRepository.fetchUnhandledPage].
///
/// Isinya sengaja tidak dibuka: widget hanya menyimpan nilai ini dan
/// mengirimkannya kembali ke repository, tanpa mengakses Firestore langsung.
class IsbnLogCursor {
  const IsbnLogCursor._(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;
}

/// Satu halaman antrean log ISBN beserta kursor untuk melanjutkan.
class IsbnLogPage {
  const IsbnLogPage({
    required this.logs,
    required this.hasMore,
    this.nextCursor,
  });

  final List<IsbnLog> logs;

  /// `true` bila masih ada log setelah halaman ini.
  final bool hasMore;

  /// Kursor halaman berikutnya, bernilai `null` bila [hasMore] bernilai
  /// `false`.
  final IsbnLogCursor? nextCursor;
}

/// Akses ke koleksi `isbn_logs` di Firestore (PRD bagian 8).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk data log ISBN; semua akses lewat kelas ini (lihat
/// [isbnLogRepositoryProvider]).
class IsbnLogRepository {
  IsbnLogRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _isbnLogs =>
      _firestore.collection(FirestorePaths.isbnLogs);

  /// Jumlah log ISBN yang belum ditangani, dipakai kartu dashboard admin
  /// (T-031).
  ///
  /// Memakai agregasi `count()` dengan filter `handled == false` sehingga
  /// tidak membaca seluruh dokumen log.
  Future<int> countUnhandledIsbnLogs() async {
    final AggregateQuerySnapshot snapshot = await _isbnLogs
        .where('handled', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Antrean log ISBN yang belum ditangani, terbaru lebih dulu.
  ///
  /// Hanya dokumen dengan `handled == false` yang diambil, diurutkan
  /// `lastScannedAt` menurun. [limit] dibatasi antara 1 dan
  /// [isbnLogMaxPageSize]. Kirim [cursor] dari
  /// [IsbnLogPage.nextCursor] untuk melanjutkan, sehingga halaman berikutnya
  /// dimulai setelah item terakhir halaman sebelumnya tanpa mengulang atau
  /// melewati baris.
  Future<IsbnLogPage> fetchUnhandledPage({
    int limit = isbnLogPageSize,
    IsbnLogCursor? cursor,
  }) async {
    final int pageSize = _resolvePageSize(limit);
    Query<Map<String, dynamic>> query = _isbnLogs
        .where('handled', isEqualTo: false)
        .orderBy('lastScannedAt', descending: true)
        .limit(pageSize + 1);
    if (cursor != null) {
      query = query.startAfterDocument(cursor._snapshot);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return _toPage(snapshot.docs, pageSize);
    } on FirebaseException catch (error) {
      throw IsbnLogFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const IsbnLogFailure(AppStrings.isbnLogListError);
    }
  }

  /// Mencatat satu pemindaian ISBN yang tidak ditemukan di katalog (T-034).
  ///
  /// ISBN dinormalisasi dengan [Isbn.normalize] lalu dipakai sebagai ID
  /// dokumen, sehingga variasi spasi, tanda hubung, dan huruf `x` kecil
  /// menunjuk log yang sama. Transaksi membaca log lebih dulu: bila belum ada,
  /// dokumen dibuat dengan `scanCount = 1`; bila sudah ada, `scanCount`
  /// dinaikkan dengan [FieldValue.increment] sehingga dua pemindaian
  /// bersamaan tidak kehilangan hitungan. `handled` selalu diisi `false`
  /// sehingga log yang sebelumnya sudah ditandai admin muncul lagi sebagai
  /// belum ditangani.
  ///
  /// Melempar [IsbnLogFailure] berpesan bahasa Indonesia bila pengguna belum
  /// masuk atau penulisan gagal.
  Future<void> record(String isbn) async {
    final String normalized = _normalizeOrThrow(
      isbn,
      AppStrings.isbnLogUnreadableIsbn,
    );
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const IsbnLogFailure(AppStrings.isbnLogSignInRequired);
    }
    final String uid = user.uid;
    final DocumentReference<Map<String, dynamic>> log = _isbnLogs.doc(
      normalized,
    );

    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(log);
        final Map<String, dynamic> scanFields = <String, dynamic>{
          'lastScannedAt': FieldValue.serverTimestamp(),
          'lastScannedBy': uid,
          'handled': false,
        };
        if (snapshot.exists) {
          transaction.update(log, <String, dynamic>{
            ...scanFields,
            'scanCount': FieldValue.increment(1),
          });
        } else {
          transaction.set(log, <String, dynamic>{
            ...scanFields,
            'isbn': normalized,
            'scanCount': 1,
          });
        }
      });
    } on FirebaseException catch (error) {
      throw IsbnLogFailure(mapFirestoreError(error));
    } on Exception {
      throw const IsbnLogFailure(AppStrings.isbnLogSaveError);
    }
  }

  /// Menandai satu log ISBN sudah ditangani (FR-B5, T-035b).
  ///
  /// Hanya field `handled` yang ditulis menjadi `true`; data pemindaian lain
  /// tidak berubah. ISBN dinormalisasi lebih dulu agar variasi format tetap
  /// menunjuk dokumen `isbn_logs/{isbn}` yang sama. Pemindaian ulang nanti
  /// membuka kembali log ini karena [record] selalu menulis `handled = false`.
  ///
  /// Melempar [IsbnLogFailure] berpesan bahasa Indonesia bila ISBN kosong atau
  /// penulisan gagal.
  Future<void> markHandled(String isbn) async {
    final String normalized = _normalizeOrThrow(
      isbn,
      AppStrings.isbnLogHandleMissingIsbn,
    );

    try {
      await _isbnLogs.doc(normalized).update(<Object, Object?>{
        'handled': true,
      });
    } on FirebaseException catch (error) {
      throw IsbnLogFailure(mapFirestoreHandleError(error));
    } on Exception {
      throw const IsbnLogFailure(AppStrings.isbnLogHandleError);
    }
  }

  IsbnLogPage _toPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    final bool hasMore = docs.length > pageSize;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs = hasMore
        ? docs.sublist(0, pageSize)
        : docs;
    return IsbnLogPage(
      logs: pageDocs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                IsbnLog.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: hasMore ? IsbnLogCursor._(pageDocs.last) : null,
    );
  }

  static int _resolvePageSize(int limit) {
    if (limit < 1) {
      return 1;
    }
    if (limit > isbnLogMaxPageSize) {
      return isbnLogMaxPageSize;
    }
    return limit;
  }

  /// Menormalkan ISBN dan menolak nilai kosong dengan [message].
  static String _normalizeOrThrow(String isbn, String message) {
    final String normalized = Isbn.normalize(isbn);
    if (normalized.isEmpty) {
      throw IsbnLogFailure(message);
    }
    return normalized;
  }

  /// Memetakan galat baca Firestore menjadi pesan bahasa Indonesia yang ramah.
  ///
  /// Dipakai sebagai `static` agar pemetaan dapat diuji tanpa instance
  /// `FirebaseFirestore` yang hidup.
  static String mapFirestoreReadError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.isbnLogListNetworkError,
      permissionDenied: AppStrings.isbnLogListPermissionDenied,
      fallback: AppStrings.isbnLogListError,
    );
  }

  /// Memetakan galat Firestore menjadi pesan bahasa Indonesia yang ramah.
  ///
  /// Dipakai sebagai `static` agar pemetaan dapat diuji tanpa instance
  /// `FirebaseFirestore` yang hidup.
  static String mapFirestoreError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.isbnLogNetworkError,
      permissionDenied: AppStrings.isbnLogPermissionDenied,
      fallback: AppStrings.isbnLogSaveError,
    );
  }

  /// Memetakan galat penandaan log menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestoreHandleError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.isbnLogHandleNetworkError,
      permissionDenied: AppStrings.isbnLogHandlePermissionDenied,
      fallback: AppStrings.isbnLogHandleError,
    );
  }

  static String _mapFirestoreError(
    FirebaseException error, {
    required String network,
    required String permissionDenied,
    required String fallback,
  }) {
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
}

/// Akses [IsbnLogRepository] bersama lewat Riverpod.
final Provider<IsbnLogRepository> isbnLogRepositoryProvider =
    Provider<IsbnLogRepository>((Ref ref) => IsbnLogRepository());
