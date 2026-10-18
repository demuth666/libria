import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';

/// Akses ke koleksi `isbn_logs` di Firestore (PRD bagian 8).
///
/// Widget tidak memanggil `FirebaseFirestore` secara langsung untuk data log
/// ISBN; semua akses lewat kelas ini (lihat [isbnLogRepositoryProvider]).
class IsbnLogRepository {
  IsbnLogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
}

/// Akses [IsbnLogRepository] bersama lewat Riverpod.
final Provider<IsbnLogRepository> isbnLogRepositoryProvider =
    Provider<IsbnLogRepository>((Ref ref) => IsbnLogRepository());
