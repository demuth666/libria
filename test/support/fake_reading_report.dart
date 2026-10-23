import 'dart:async';

import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/reports/data/reading_report.dart';
import 'package:libria/features/reports/data/reading_report_printer.dart';
import 'package:libria/features/reports/data/reading_report_repository.dart';
import 'package:libria/features/session/data/reading_session.dart';

/// Repository laporan palsu tanpa Firestore atau Auth.
///
/// Laporan dihitung dari [sessions] dan [entries] dengan aturan
/// [ReadingReport.fromSessions], sehingga perubahan rentang tanggal pada uji
/// ikut menyaring data seperti implementasi asli.
class FakeReadingReportRepository implements ReadingReportRepository {
  FakeReadingReportRepository({
    List<ReadingSession>? sessions,
    List<LibraryEntry>? entries,
  }) : sessions = sessions ?? <ReadingSession>[],
       entries = entries ?? <LibraryEntry>[];

  final List<ReadingSession> sessions;
  final List<LibraryEntry> entries;

  Object? error;
  Completer<void>? loadGate;
  int loadCalls = 0;
  String? lastUserName;
  DateTime? lastStartDate;
  DateTime? lastEndDate;

  @override
  Future<ReadingReport> loadReport({
    required String userName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    loadCalls++;
    lastUserName = userName;
    lastStartDate = startDate;
    lastEndDate = endDate;
    if (loadGate != null) {
      await loadGate!.future;
    }
    if (error != null) {
      throw error!;
    }
    return ReadingReport.fromSessions(
      userName: userName,
      startDate: startDate,
      endDate: endDate,
      sessions: sessions,
      libraryEntries: entries,
    );
  }
}

/// Pembuka dialog cetak palsu yang mencatat laporan terakhir.
class FakeReadingReportPrinter implements ReadingReportPrinter {
  int printCalls = 0;
  ReadingReport? lastReport;
  Object? error;
  bool result = true;

  @override
  Future<bool> printReport(ReadingReport report) async {
    printCalls++;
    lastReport = report;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}
