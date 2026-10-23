import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/stats/data/reading_stats_repository.dart';
import 'package:libria/features/stats/presentation/reading_stats_providers.dart';
import 'package:libria/features/stats/presentation/reading_stats_screen.dart';

import 'support/fake_reading_stats_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  final DateTime today = DateTime(2026, 10, 23, 12);

  Future<({ProviderContainer container, GoRouter router})> pumpStats(
    WidgetTester tester, {
    required FakeReadingStatsRepository repository,
    ThemeData? theme,
    Size viewSize = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [readingStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.homeStats,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.homeStats,
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: ReadingStatsScreen(today: today)),
        ),
        GoRoute(
          path: AppRoutes.homeStatsHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('history-test'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, router: router);
  }

  String metricValue(WidgetTester tester, String key) {
    final Text text = tester.widget<Text>(find.byKey(ValueKey<String>(key)));
    return text.data ?? '';
  }

  testWidgets('Menampilkan ringkasan dan grafik sesuai data sesi', (
    WidgetTester tester,
  ) async {
    final FakeReadingStatsRepository repository = _populatedRepository();

    await pumpStats(tester, repository: repository);

    expect(find.text(AppStrings.statsTitle), findsOneWidget);
    expect(find.text(AppStrings.statsSummaryTitle), findsOneWidget);
    expect(metricValue(tester, 'stats-total-minutes'), '60');
    expect(metricValue(tester, 'stats-total-pages'), '40');
    expect(metricValue(tester, 'stats-finished-books'), '1');
    expect(metricValue(tester, 'stats-streak'), '3');

    final BarChart chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(7));
    expect(chart.data.barGroups.last.barRods.single.toY, 30);
    expect(chart.data.barGroups[5].barRods.single.toY, 20);
    expect(chart.data.barGroups[4].barRods.single.toY, 10);
    expect(find.text(AppStrings.statsSessionHistoryAction), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('stats-empty')), findsNothing);
  });

  testWidgets('Pilihan 30 hari memuat grafik 30 batang', (
    WidgetTester tester,
  ) async {
    final FakeReadingStatsRepository repository = _populatedRepository();

    await pumpStats(tester, repository: repository);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('stats-range-30')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('stats-range-30')));
    await tester.pumpAndSettle();

    final BarChart chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(30));
    expect(chart.data.barGroups.last.barRods.single.toY, 30);
  });

  testWidgets('Keadaan kosong tampil bila belum ada sesi', (
    WidgetTester tester,
  ) async {
    await pumpStats(tester, repository: FakeReadingStatsRepository());

    expect(find.byKey(const ValueKey<String>('stats-empty')), findsOneWidget);
    expect(find.text(AppStrings.statsChartEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.statsChartEmptyMessage), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(metricValue(tester, 'stats-total-minutes'), '0');
    expect(metricValue(tester, 'stats-total-pages'), '0');
    expect(metricValue(tester, 'stats-finished-books'), '0');
    expect(metricValue(tester, 'stats-streak'), '0');
  });

  testWidgets('Galat pemuatan memakai pesan ramah dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakeReadingStatsRepository repository = FakeReadingStatsRepository()
      ..sessionError = const ReadingStatsFailure(AppStrings.statsNetworkError);

    await pumpStats(tester, repository: repository);

    expect(find.text(AppStrings.statsNetworkError), findsOneWidget);
    expect(find.textContaining('stack'), findsNothing);

    repository.sessionError = null;
    repository.sessions.add(
      _session(
        id: 'loaded',
        startedAt: DateTime(2026, 10, 23, 9),
        durationSeconds: 15 * 60,
        startPage: 0,
        endPage: 12,
      ),
    );
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(metricValue(tester, 'stats-total-minutes'), '15');
    expect(metricValue(tester, 'stats-total-pages'), '12');
    expect(find.text(AppStrings.statsNetworkError), findsNothing);
  });

  testWidgets('Pemberitahuan stale tampil saat pembaruan data gagal', (
    WidgetTester tester,
  ) async {
    final FakeReadingStatsRepository repository = _populatedRepository();
    final ({ProviderContainer container, GoRouter router}) harness =
        await pumpStats(tester, repository: repository);

    repository.sessionError = const ReadingStatsFailure(
      AppStrings.statsNetworkError,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      repository.notifySessions();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(
      harness.container.read(readingStatsProvider).requireValue.streamError,
      AppStrings.statsNetworkError,
    );
    expect(find.text(AppStrings.statsStaleNotice), findsOneWidget);
    expect(metricValue(tester, 'stats-total-minutes'), '60');
    expect(
      find.byKey(const ValueKey<String>('stats-stale-retry')),
      findsOneWidget,
    );
  });

  testWidgets('Tautan riwayat sesi membuka rute riwayat', (
    WidgetTester tester,
  ) async {
    final FakeReadingStatsRepository repository = _populatedRepository();
    final ({ProviderContainer container, GoRouter router}) harness =
        await pumpStats(tester, repository: repository);

    final Finder historyButton = find.byKey(
      const ValueKey<String>('stats-session-history'),
    );
    await tester.ensureVisible(historyButton);
    await tester.pumpAndSettle();
    await tester.tap(historyButton);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeStatsHistory);
    expect(find.text('history-test'), findsOneWidget);
  });

  for (final MapEntry<String, ThemeData> theme in <String, ThemeData>{
    'terang': AppTheme.light,
    'gelap': AppTheme.dark,
  }.entries) {
    for (final MapEntry<String, Size> size in <String, Size>{
      'ponsel': const Size(360, 800),
      'tablet': const Size(800, 1280),
    }.entries) {
      testWidgets(
        'Statistik tampil tanpa overflow pada tema ${theme.key} ukuran '
        '${size.key}',
        (WidgetTester tester) async {
          await pumpStats(
            tester,
            repository: _populatedRepository(),
            theme: theme.value,
            viewSize: size.value,
          );

          expect(metricValue(tester, 'stats-total-minutes'), '60');
          expect(find.byType(BarChart), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Statistik tetap terbaca pada skala teks 1,5x', (
    WidgetTester tester,
  ) async {
    await pumpStats(
      tester,
      repository: _populatedRepository(),
      viewSize: const Size(360, 800),
      textScale: 1.5,
    );

    expect(metricValue(tester, 'stats-total-minutes'), '60');
    expect(tester.takeException(), isNull);
  });
}

FakeReadingStatsRepository _populatedRepository() {
  final FakeReadingStatsRepository repository = FakeReadingStatsRepository();

  repository.sessions.addAll(<ReadingSession>[
    _session(
      id: 'today',
      startedAt: DateTime(2026, 10, 23, 9),
      durationSeconds: 30 * 60,
      startPage: 10,
      endPage: 30,
    ),
    _session(
      id: 'yesterday',
      startedAt: DateTime(2026, 10, 22, 20),
      durationSeconds: 20 * 60,
      startPage: 0,
      endPage: 15,
    ),
    _session(
      id: 'two-days-ago',
      startedAt: DateTime(2026, 10, 21, 19),
      durationSeconds: 10 * 60,
      startPage: 5,
      endPage: 10,
    ),
  ]);
  repository.finishedBooks.add(
    const LibraryEntry(
      bookId: 'book-1',
      status: LibraryEntry.statusFinished,
      bookTitle: 'Bumi Manusia',
      bookAuthor: 'Pramoedya Ananta Toer',
      bookTotalPages: 535,
    ),
  );
  return repository;
}

ReadingSession _session({
  required String id,
  required DateTime startedAt,
  int durationSeconds = 20 * 60,
  int startPage = 0,
  int endPage = 10,
}) {
  return ReadingSession(
    id: id,
    bookId: 'book-1',
    bookTitle: 'Bumi Manusia',
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    targetSeconds: 30 * 60,
    startPage: startPage,
    endPage: endPage,
  );
}
