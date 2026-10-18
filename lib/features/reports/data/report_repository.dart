import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import 'report.dart';

/// Akses ke koleksi `reports` di Firestore (PRD bagian 8).
///
/// Widget tidak memanggil `FirebaseFirestore` secara langsung untuk data
/// laporan; semua akses lewat kelas ini (lihat [reportRepositoryProvider]).
class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(FirestorePaths.reports);

  /// Jumlah laporan berstatus terbuka, dipakai kartu dashboard admin (T-031).
  ///
  /// Memakai agregasi `count()` dengan filter `status == open` sehingga tidak
  /// membaca seluruh dokumen laporan.
  Future<int> countOpenReports() async {
    final AggregateQuerySnapshot snapshot = await _reports
        .where('status', isEqualTo: Report.statusOpen)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

/// Akses [ReportRepository] bersama lewat Riverpod.
final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>((Ref ref) => ReportRepository());
