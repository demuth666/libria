import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/active_session_repository.dart';

/// Penyimpanan sesi aktif palsu tanpa plugin `shared_preferences`.
///
/// Dipakai uji widget layar sesi agar alur mulai sesi dapat diselesaikan tanpa
/// menunggu kanal platform. Aturan serialisasi dan pemulihan sesungguhnya diuji
/// terpisah di `active_session_repository_test.dart`.
class FakeActiveSessionRepository implements ActiveSessionRepository {
  FakeActiveSessionRepository({this.session});

  ActiveSession? session;

  int loadCalls = 0;
  int saveCalls = 0;
  int clearCalls = 0;

  Object? loadError;
  Object? saveError;
  Object? clearError;

  @override
  Future<ActiveSession?> load() async {
    loadCalls++;
    if (loadError != null) {
      throw loadError!;
    }
    return session;
  }

  @override
  Future<void> save(ActiveSession value) async {
    saveCalls++;
    if (saveError != null) {
      throw saveError!;
    }
    session = value;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    if (clearError != null) {
      throw clearError!;
    }
    session = null;
  }
}
