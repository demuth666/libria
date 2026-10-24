import 'package:libria/features/home/data/home_repository.dart';
import 'package:libria/features/session/data/reading_session.dart';

/// Repository ringkasan Beranda palsu tanpa Firestore atau Auth.
///
/// [watchTodaySummaryFactory] dan [watchRecentSessionsFactory] dipakai bila uji
/// perlu mengatur loading, galat, atau percobaan ulang. Bila tidak diisi,
/// setiap pemanggilan mengemit data satu kali.
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({
    HomeTodaySummary? summary,
    List<ReadingSession>? recentSessions,
  }) : summary = summary ?? HomeTodaySummary.empty,
       recentSessions = recentSessions ?? <ReadingSession>[];

  HomeTodaySummary summary;
  List<ReadingSession> recentSessions;
  int watchTodaySummaryCalls = 0;
  int watchRecentSessionsCalls = 0;
  Stream<HomeTodaySummary> Function()? watchTodaySummaryFactory;
  Stream<List<ReadingSession>> Function()? watchRecentSessionsFactory;

  @override
  Stream<HomeTodaySummary> watchTodaySummary({DateTime? now}) {
    watchTodaySummaryCalls++;
    final Stream<HomeTodaySummary> Function()? factory =
        watchTodaySummaryFactory;
    if (factory != null) {
      return factory();
    }
    return Stream<HomeTodaySummary>.value(summary);
  }

  @override
  Stream<List<ReadingSession>> watchRecentSessions({
    DateTime? now,
    int days = 14,
    int limit = 500,
  }) {
    watchRecentSessionsCalls++;
    final Stream<List<ReadingSession>> Function()? factory =
        watchRecentSessionsFactory;
    if (factory != null) {
      return factory();
    }
    return Stream<List<ReadingSession>>.value(recentSessions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
