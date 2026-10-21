import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/isbn.dart';

/// Galat log ISBN dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class IsbnLogFailure implements Exception {
  const IsbnLogFailure(this.message);

  final String message;

  @override
  String toString() => message;
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
    final String normalized = Isbn.normalize(isbn);
    if (normalized.isEmpty) {
      throw const IsbnLogFailure(AppStrings.isbnLogUnreadableIsbn);
    }
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

  /// Memetakan galat Firestore menjadi pesan bahasa Indonesia yang ramah.
  ///
  /// Dipakai sebagai `static` agar pemetaan dapat diuji tanpa instance
  /// `FirebaseFirestore` yang hidup.
  static String mapFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.isbnLogNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.isbnLogPermissionDenied;
      default:
        return AppStrings.isbnLogSaveError;
    }
  }
}

/// Akses [IsbnLogRepository] bersama lewat Riverpod.
final Provider<IsbnLogRepository> isbnLogRepositoryProvider =
    Provider<IsbnLogRepository>((Ref ref) => IsbnLogRepository());
