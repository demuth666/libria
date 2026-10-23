import 'dart:async';

import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/active_session.dart';
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

  /// Pengganti hasil simpan; bila kosong, rencana dari [SessionRepository]
  /// dipakai agar data uji tetap konsisten.
  SessionSaveResult Function(
    ActiveSession session,
    LibraryEntry entry,
    int endPage,
  )?
  resultFactory;

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
