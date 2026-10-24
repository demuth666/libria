import 'dart:async';

import 'package:libria/features/reports/data/report.dart';
import 'package:libria/features/reports/data/report_repository.dart';

/// Membuat laporan contoh untuk uji moderasi admin.
Report fakeReport(
  int index, {
  String? targetType,
  String? postId,
  String? replyId,
  String? reason,
  String? targetPreview,
  String status = Report.statusOpen,
  DateTime? createdAt,
}) {
  return Report(
    id: 'report-$index',
    targetType: targetType ?? Report.targetPost,
    postId: postId ?? 'post-$index',
    replyId: replyId,
    targetAuthorId: 'user-$index',
    targetPreview: targetPreview ?? 'Isi konten laporan $index.',
    reason: reason ?? Report.reasonSpam,
    reporterId: 'reporter-$index',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, index),
  );
}

/// Repository laporan palsu tanpa Firestore atau Auth.
///
/// [pages] dipakai bila uji butuh lebih dari satu halaman; setiap pemanggilan
/// [fetchOpenReportsPage] mengambil halaman berikutnya. Bila [pages] kosong,
/// seluruh [reports] berstatus terbuka dikembalikan sebagai satu halaman.
class FakeReportRepository implements ReportRepository {
  FakeReportRepository({List<Report>? reports})
    : reports = reports ?? <Report>[];

  final List<Report> reports;
  List<List<Report>>? pages;

  int fetchPageCalls = 0;
  int fetchPageFailuresRemaining = 0;
  Object? fetchError;
  Completer<void>? fetchPageGate;
  final List<int> requestedLimits = <int>[];

  int deleteContentCalls = 0;
  Report? lastDeletedReport;
  Object? deleteError;
  Completer<void>? deleteGate;

  int dismissCalls = 0;
  Report? lastDismissedReport;
  Object? dismissError;
  Completer<void>? dismissGate;

  int createCalls = 0;
  String? lastTargetType;
  String? lastPostId;
  String? lastReplyId;
  String? lastTargetAuthorId;
  String? lastTargetContent;
  String? lastReason;

  Object? createError;
  Completer<void>? createGate;

  int _autoIncrement = 0;

  @override
  Future<String> createReport({
    required String targetType,
    required String postId,
    required String targetAuthorId,
    required String targetContent,
    required String reason,
    String? replyId,
  }) async {
    createCalls++;
    lastTargetType = targetType;
    lastPostId = postId;
    lastReplyId = replyId;
    lastTargetAuthorId = targetAuthorId;
    lastTargetContent = targetContent;
    lastReason = reason;

    if (createGate != null) {
      await createGate!.future;
    }
    if (createError != null) {
      throw createError!;
    }
    return 'report-${++_autoIncrement}';
  }

  @override
  Future<int> countOpenReports() async {
    return reports
        .where((Report report) => report.status == Report.statusOpen)
        .length;
  }

  @override
  Future<ReportPage> fetchOpenReportsPage({
    int limit = reportPageSize,
    ReportCursor? cursor,
  }) async {
    fetchPageCalls++;
    requestedLimits.add(limit);
    if (fetchPageGate != null) {
      await fetchPageGate!.future;
    }
    if (fetchPageFailuresRemaining > 0) {
      fetchPageFailuresRemaining--;
      throw StateError('Gagal memuat laporan.');
    }
    if (fetchError != null) {
      throw fetchError!;
    }

    final List<List<Report>>? configuredPages = pages;
    if (configuredPages != null && configuredPages.isNotEmpty) {
      int index = fetchPageCalls - 1;
      if (index >= configuredPages.length) {
        index = configuredPages.length - 1;
      }
      return ReportPage(
        reports: List<Report>.of(configuredPages[index]),
        hasMore: index < configuredPages.length - 1,
      );
    }

    final List<Report> openReports = reports
        .where((Report report) => report.status == Report.statusOpen)
        .toList(growable: false);
    return ReportPage(reports: openReports, hasMore: false);
  }

  @override
  Future<void> deleteReportedContent(Report report) async {
    deleteContentCalls++;
    lastDeletedReport = report;
    if (deleteGate != null) {
      await deleteGate!.future;
    }
    if (deleteError != null) {
      throw deleteError!;
    }
    _remove(report.id);
  }

  @override
  Future<void> dismissReport(Report report) async {
    dismissCalls++;
    lastDismissedReport = report;
    if (dismissGate != null) {
      await dismissGate!.future;
    }
    if (dismissError != null) {
      throw dismissError!;
    }
    _remove(report.id);
  }

  void _remove(String reportId) {
    reports.removeWhere((Report report) => report.id == reportId);
    final List<List<Report>>? configuredPages = pages;
    if (configuredPages != null) {
      for (final List<Report> page in configuredPages) {
        page.removeWhere((Report report) => report.id == reportId);
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
