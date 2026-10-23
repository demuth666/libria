import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_report.dart';
import '../data/reading_report_repository.dart';

/// Permintaan laporan membaca pada satu rentang tanggal.
///
/// Nilai dipakai sebagai kunci keluarga [readingReportProvider]. Seluruh
/// tanggal sudah dinormalkan ke tengah malam oleh layar agar memilih tanggal
/// yang sama tidak memicu permintaan baru.
class ReadingReportRequest {
  const ReadingReportRequest({
    required this.userName,
    required this.startDate,
    required this.endDate,
  });

  final String userName;
  final DateTime startDate;
  final DateTime endDate;

  @override
  bool operator ==(Object other) {
    return other is ReadingReportRequest &&
        other.userName == userName &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(userName, startDate, endDate);
}

/// Laporan membaca untuk rentang tanggal yang dipilih (FR-P1 dan FR-P2).
///
/// Provider dibuang saat layar berhenti mendengarkan sehingga membuka layar
/// kembali selalu membaca data terbaru dari cache atau server.
final readingReportProvider = FutureProvider.autoDispose
    .family<ReadingReport, ReadingReportRequest>((
      Ref ref,
      ReadingReportRequest request,
    ) {
      return ref
          .watch(readingReportRepositoryProvider)
          .loadReport(
            userName: request.userName,
            startDate: request.startDate,
            endDate: request.endDate,
          );
    });
