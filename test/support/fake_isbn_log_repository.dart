import 'dart:async';

import 'package:libria/features/isbn_logs/data/isbn_log.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';

/// Membuat log ISBN contoh untuk uji antrean admin.
IsbnLog fakeIsbnLog(
  int index, {
  String? isbn,
  int scanCount = 1,
  DateTime? lastScannedAt,
  bool handled = false,
}) {
  return IsbnLog(
    isbn: isbn ?? '97800000${index.toString().padLeft(5, '0')}',
    scanCount: scanCount,
    lastScannedAt: lastScannedAt ?? DateTime(2026, 1, index),
    lastScannedBy: 'user-1',
    handled: handled,
  );
}

/// Repository log ISBN palsu tanpa Firestore.
///
/// [pages] dipakai bila uji butuh lebih dari satu halaman; setiap pemanggilan
/// [fetchUnhandledPage] mengambil halaman berikutnya. Bila [pages] kosong,
/// seluruh [allLogs] dikembalikan sebagai satu halaman.
class FakeIsbnLogRepository implements IsbnLogRepository {
  FakeIsbnLogRepository({List<IsbnLog>? logs}) : allLogs = logs ?? <IsbnLog>[];

  final List<IsbnLog> allLogs;
  List<List<IsbnLog>>? pages;

  int fetchPageCalls = 0;
  int fetchPageFailuresRemaining = 0;
  Object? fetchError;
  Completer<void>? fetchPageGate;
  final List<int> requestedLimits = <int>[];

  @override
  Future<IsbnLogPage> fetchUnhandledPage({
    int limit = isbnLogPageSize,
    IsbnLogCursor? cursor,
  }) async {
    fetchPageCalls++;
    requestedLimits.add(limit);
    if (fetchPageGate != null) {
      await fetchPageGate!.future;
    }
    if (fetchPageFailuresRemaining > 0) {
      fetchPageFailuresRemaining--;
      throw StateError('Gagal memuat log ISBN.');
    }
    if (fetchError != null) {
      throw fetchError!;
    }

    final List<List<IsbnLog>>? configuredPages = pages;
    if (configuredPages != null && configuredPages.isNotEmpty) {
      int index = fetchPageCalls - 1;
      if (index >= configuredPages.length) {
        index = configuredPages.length - 1;
      }
      return IsbnLogPage(
        logs: List<IsbnLog>.of(configuredPages[index]),
        hasMore: index < configuredPages.length - 1,
      );
    }

    return IsbnLogPage(logs: List<IsbnLog>.of(allLogs), hasMore: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
