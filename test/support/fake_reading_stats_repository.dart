import 'dart:async';

import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/stats/data/reading_stats_repository.dart';

/// Repository statistik palsu tanpa Firestore atau Auth.
///
/// Setiap stream mengirim data saat ini lalu menunggu [notify] agar uji dapat
/// memeriksa pembaruan sekaligus kegagalan setelah data tampil.
class FakeReadingStatsRepository implements ReadingStatsRepository {
  final List<ReadingSession> sessions = <ReadingSession>[];
  final List<LibraryEntry> finishedBooks = <LibraryEntry>[];

  Object? sessionError;
  Object? bookError;

  int? lastSessionLimit;
  int? lastBookLimit;

  final StreamController<void> _sessionChanges =
      StreamController<void>.broadcast();
  final StreamController<void> _bookChanges =
      StreamController<void>.broadcast();

  void notifySessions() {
    _sessionChanges.add(null);
  }

  void notifyBooks() {
    _bookChanges.add(null);
  }

  void dispose() {
    _sessionChanges.close();
    _bookChanges.close();
  }

  @override
  Stream<List<ReadingSession>> watchSessions({required int limit}) async* {
    lastSessionLimit = limit;
    if (sessionError != null) {
      throw sessionError!;
    }
    yield _sessionPage(limit);
    await for (final _ in _sessionChanges.stream) {
      if (sessionError != null) {
        throw sessionError!;
      }
      yield _sessionPage(limit);
    }
  }

  @override
  Stream<List<LibraryEntry>> watchFinishedBooks({required int limit}) async* {
    lastBookLimit = limit;
    if (bookError != null) {
      throw bookError!;
    }
    yield _bookPage(limit);
    await for (final _ in _bookChanges.stream) {
      if (bookError != null) {
        throw bookError!;
      }
      yield _bookPage(limit);
    }
  }

  List<ReadingSession> _sessionPage(int limit) {
    final List<ReadingSession> ordered = sessions.toList(growable: false)
      ..sort((ReadingSession a, ReadingSession b) {
        final DateTime left =
            a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime right =
            b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return ordered.take(limit).toList(growable: false);
  }

  List<LibraryEntry> _bookPage(int limit) {
    return finishedBooks.take(limit).toList(growable: false);
  }
}
