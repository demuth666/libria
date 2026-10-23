import 'package:libria/features/home/data/home_repository.dart';

/// Repository ringkasan Beranda palsu tanpa Firestore atau Auth.
///
/// [watchTodaySummaryFactory] dipakai bila uji perlu mengatur loading, galat,
/// atau percobaan ulang. Bila tidak diisi, setiap pemanggilan mengemit
/// [summary] satu kali.
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({HomeTodaySummary? summary})
    : summary = summary ?? HomeTodaySummary.empty;

  HomeTodaySummary summary;
  int watchTodaySummaryCalls = 0;
  Stream<HomeTodaySummary> Function()? watchTodaySummaryFactory;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
