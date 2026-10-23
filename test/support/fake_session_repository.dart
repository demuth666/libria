import 'dart:async';

import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/session/data/session_repository.dart';

/// Penyimpanan sesi palsu tanpa Firestore atau Auth.
///
/// Dipakai uji widget layar penyelesaian agar alur simpan dan pembersihan sesi
/// aktif dapat diselesaikan tanpa Firebase. Aturan halaman dan status otomatis
/// diuji terpisah di `session_repository_test.dart`.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({this.resultFactory});

  int saveCalls = 0;
  ActiveSession? lastSession;
  LibraryEntry? lastEntry;
  int? lastEndPage;

  Completer<void>? saveGate;
  Object? saveError;

  /// Seluruh sesi yang tersedia untuk stream riwayat.
  final List<ReadingSession> sessions = <ReadingSession>[];

  /// Menahan emisi stream riwayat sampai uji melepasnya.
  Completer<void>? readGate;

  /// Galat yang dikirim stream riwayat, misalnya kegagalan jaringan.
  Object? readError;

  int? lastBookLimit;
  String? lastBookId;
  int? lastAllLimit;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Pengganti hasil simpan; bila kosong, rencana dari [SessionRepository]
  /// dipakai agar data uji tetap konsisten.
  SessionSaveResult Function(
    ActiveSession session,
    LibraryEntry entry,
    int endPage,
  )?
  resultFactory;

  /// Menambahkan sesi dan memberi tahu stream yang sedang mendengarkan.
  void addSession(ReadingSession session) {
    sessions.add(session);
    _changes.add(null);
  }

  void dispose() {
    _changes.close();
  }

  @override
  Stream<List<ReadingSession>> watchSessionsForBook(
    String bookId, {
    int limit = 20,
  }) async* {
    lastBookId = bookId;
    lastBookLimit = limit;
    if (readGate != null) {
      await readGate!.future;
    }
    if (readError != null) {
      throw readError!;
    }
    yield _page(
      sessions.where((ReadingSession session) => session.bookId == bookId),
      limit,
    );
    await for (final _ in _changes.stream) {
      if (readError != null) {
        throw readError!;
      }
      yield _page(
        sessions.where((ReadingSession session) => session.bookId == bookId),
        limit,
      );
    }
  }

  @override
  Stream<List<ReadingSession>> watchAllSessions({int limit = 20}) async* {
    lastAllLimit = limit;
    if (readGate != null) {
      await readGate!.future;
    }
    if (readError != null) {
      throw readError!;
    }
    yield _page(sessions, limit);
    await for (final _ in _changes.stream) {
      if (readError != null) {
        throw readError!;
      }
      yield _page(sessions, limit);
    }
  }

  List<ReadingSession> _page(Iterable<ReadingSession> source, int limit) {
    final List<ReadingSession> ordered = source.toList(growable: false)
      ..sort((ReadingSession a, ReadingSession b) {
        final DateTime left =
            a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime right =
            b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return ordered.take(limit).toList(growable: false);
  }

  @override
  Future<SessionSaveResult> saveSession({
    required ActiveSession activeSession,
    required LibraryEntry entry,
    required int endPage,
  }) async {
    saveCalls++;
    lastSession = activeSession;
    lastEntry = entry;
    lastEndPage = endPage;

    if (saveGate != null) {
      await saveGate!.future;
    }
    if (saveError != null) {
      throw saveError!;
    }

    final SessionSaveResult Function(
      ActiveSession session,
      LibraryEntry entry,
      int endPage,
    )?
    factory = resultFactory;
    if (factory != null) {
      return factory(activeSession, entry, endPage);
    }

    final SessionSavePlan plan = SessionRepository.planSave(
      activeSession: activeSession,
      entry: entry,
      endPage: endPage,
    );
    return SessionSaveResult(
      session: plan.session,
      status: plan.status,
      reachedLastPage: plan.reachedLastPage,
    );
  }
}
