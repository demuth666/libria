import 'dart:async';

import 'package:libria/features/reports/data/report_repository.dart';

/// Repository laporan palsu tanpa Firestore atau Auth.
class FakeReportRepository implements ReportRepository {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
