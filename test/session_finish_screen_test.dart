import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/active_session_repository.dart';
import 'package:libria/features/session/data/session_alarm_service.dart';
import 'package:libria/features/session/data/session_background_service.dart';
import 'package:libria/features/session/data/session_repository.dart';
import 'package:libria/features/session/presentation/session_finish_screen.dart';

import 'support/fake_active_session_repository.dart';
import 'support/fake_library_repository.dart';
import 'support/fake_session_alarm_service.dart';
import 'support/fake_session_background_service.dart';
import 'support/fake_session_repository.dart';

void main() {
  Future<_FinishHarness> pumpFinish(
    WidgetTester tester, {
    required ActiveSession? session,
    LibraryEntry? entry,
    FakeSessionRepository? repository,
    FakeActiveSessionRepository? activeRepository,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeActiveSessionRepository activeSessions =
        activeRepository ?? FakeActiveSessionRepository(session: session);
    final FakeSessionRepository sessionRepository =
        repository ?? FakeSessionRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        activeSessionRepositoryProvider.overrideWithValue(activeSessions),
        sessionBackgroundServiceProvider.overrideWithValue(
          FakeSessionBackgroundService(),
        ),
        sessionAlarmServiceProvider.overrideWithValue(
          FakeSessionAlarmService(),
        ),
        libraryRepositoryProvider.overrideWithValue(
          FakeLibraryRepository(
            entries: entry == null ? <LibraryEntry>[] : <LibraryEntry>[entry],
          ),
        ),
        sessionRepositoryProvider.overrideWithValue(sessionRepository),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.sessionFinish,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.sessionFinish,
          builder: (BuildContext context, GoRouterState state) =>
              const SessionFinishScreen(),
        ),
        GoRoute(
          path: AppRoutes.sessionRun,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('session-run-test'))),
        ),
        GoRoute(
          path: AppRoutes.sessionSetup,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('session-setup-test'))),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-test'))),
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
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    return _FinishHarness(
      container: container,
      router: router,
      activeSessions: activeSessions,
      sessionRepository: sessionRepository,
    );
  }

  testWidgets('Ringkasan sesi menampilkan durasi, target, dan halaman awal', (
    WidgetTester tester,
  ) async {
    await pumpFinish(
      tester,
      session: _finishedSession(readMinutes: 20, targetMinutes: 30),
      entry: _entry(),
    );

    expect(find.text(AppStrings.sessionFinishTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishSummaryTitle), findsOneWidget);
    expect(find.text('00:20:00'), findsOneWidget);
    expect(find.text('00:30:00'), findsOneWidget);
    expect(
      find.text(AppStrings.sessionFinishStartPage(40, 100)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.sessionFinishPageLabel), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishTargetReached), findsNothing);
  });

  testWidgets('Halaman terakhir sama dengan total menandai buku selesai', (
    WidgetTester tester,
  ) async {
    final _FinishHarness harness = await pumpFinish(
      tester,
      session: _finishedSession(readMinutes: 30, targetMinutes: 30),
      entry: _entry(),
    );

    expect(find.text(AppStrings.sessionFinishTargetReached), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('session-finish-page')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey<String>('session-finish-save')));
    await tester.pumpAndSettle();

    expect(harness.sessionRepository.saveCalls, 1);
    expect(harness.sessionRepository.lastEndPage, 100);
    expect(harness.sessionRepository.lastEntry?.currentPage, 40);
    expect(harness.activeSessions.clearCalls, 1);
    expect(find.text(AppStrings.sessionFinishSuccessTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishSuccessFinished), findsOneWidget);
    expect(
      find.text(AppStrings.sessionFinishPagesValue(40, 100)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('session-finish-home')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.home);
    expect(find.text('home-test'), findsOneWidget);
  });

  testWidgets('Halaman sebelum halaman awal ditolak', (
    WidgetTester tester,
  ) async {
    final _FinishHarness harness = await pumpFinish(
      tester,
      session: _finishedSession(),
      entry: _entry(),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('session-finish-page')),
      '20',
    );
    await tester.tap(find.byKey(const ValueKey<String>('session-finish-save')));
    await tester.pump();

    expect(
      find.text(AppStrings.sessionFinishPageBeforeStart(40)),
      findsOneWidget,
    );
    expect(harness.sessionRepository.saveCalls, 0);
    expect(harness.activeSessions.clearCalls, 0);
  });

  testWidgets('Halaman melebihi total ditolak', (WidgetTester tester) async {
    final _FinishHarness harness = await pumpFinish(
      tester,
      session: _finishedSession(),
      entry: _entry(),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('session-finish-page')),
      '101',
    );
    await tester.tap(find.byKey(const ValueKey<String>('session-finish-save')));
    await tester.pump();

    expect(find.text(AppStrings.sessionFinishPageExceeds(100)), findsOneWidget);
    expect(harness.sessionRepository.saveCalls, 0);
  });

  testWidgets('Isian kosong dan bukan angka ditolak', (
    WidgetTester tester,
  ) async {
    final _FinishHarness harness = await pumpFinish(
      tester,
      session: _finishedSession(),
      entry: _entry(),
    );

    await tester.tap(find.byKey(const ValueKey<String>('session-finish-save')));
    await tester.pump();
    expect(find.text(AppStrings.sessionFinishPageRequired), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('session-finish-page')),
      'abc',
    );
    await tester.tap(find.byKey(const ValueKey<String>('session-finish-save')));
    await tester.pump();

    expect(find.text(AppStrings.sessionFinishPageInvalid), findsOneWidget);
    expect(harness.sessionRepository.saveCalls, 0);
  });

  testWidgets('Sesi yang masih berjalan diminta kembali ke timer', (
    WidgetTester tester,
  ) async {
    final _FinishHarness harness = await pumpFinish(
      tester,
      session: _runningSession(),
      entry: _entry(),
    );

    expect(find.text(AppStrings.sessionFinishRunningTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishRunningMessage), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('session-finish-open-run')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.sessionRun);
    expect(find.text('session-run-test'), findsOneWidget);
  });

  testWidgets('Tidak ada sesi aktif menampilkan ajakan mengatur sesi', (
    WidgetTester tester,
  ) async {
    final _FinishHarness harness = await pumpFinish(tester, session: null);

    expect(find.text(AppStrings.sessionFinishNoSessionTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishNoSessionMessage), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('session-finish-open-setup')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.sessionSetup);
    expect(find.text('session-setup-test'), findsOneWidget);
  });

  testWidgets('Buku yang tidak ada di koleksi menampilkan pesan', (
    WidgetTester tester,
  ) async {
    final _FinishHarness harness = await pumpFinish(
      tester,
      session: _finishedSession(),
      entry: null,
    );

    expect(find.text(AppStrings.sessionFinishBookMissingTitle), findsOneWidget);
    expect(
      find.text(AppStrings.sessionFinishBookMissingMessage),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('session-finish-home')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.home);
  });

  testWidgets('Galat menyimpan sesi tampil tanpa menghapus sesi aktif', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository repository = FakeSessionRepository()
      ..saveError = const SessionFailure(AppStrings.sessionFinishSaveError);
    final _FinishHarness harness = await pumpFinish(
      tester,
      session: _finishedSession(),
      entry: _entry(),
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('session-finish-page')),
      '60',
    );
    await tester.tap(find.byKey(const ValueKey<String>('session-finish-save')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionFinishSaveError), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishSuccessTitle), findsNothing);
    expect(harness.activeSessions.clearCalls, 0);
  });

  testWidgets('Kegagalan membersihkan sesi lokal tampil sebagai peringatan', (
    WidgetTester tester,
  ) async {
    final FakeActiveSessionRepository activeRepository =
        FakeActiveSessionRepository(session: _finishedSession())
          ..clearError = const ActiveSessionFailure(
            AppStrings.sessionActiveSaveError,
          );
    await pumpFinish(
      tester,
      session: null,
      activeRepository: activeRepository,
      entry: _entry(),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('session-finish-page')),
      '60',
    );
    await tester.tap(find.byKey(const ValueKey<String>('session-finish-save')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionFinishSuccessTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishClearWarning), findsOneWidget);
  });

  testWidgets('Layar penyelesaian rapi di mode gelap pada ponsel', (
    WidgetTester tester,
  ) async {
    await pumpFinish(
      tester,
      session: _finishedSession(readMinutes: 42, targetMinutes: 30),
      entry: _entry(
        currentPage: 160,
        totalPages: 320,
        title: 'Judul Buku yang Panjang untuk Menguji Tata Letak',
      ),
      viewSize: const Size(360, 800),
      theme: AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SessionFinishScreen), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishSave), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishTargetReached), findsOneWidget);
  });

  testWidgets('Layar penyelesaian rapi di mode gelap pada tablet', (
    WidgetTester tester,
  ) async {
    await pumpFinish(
      tester,
      session: _finishedSession(),
      entry: _entry(),
      viewSize: const Size(800, 1280),
      theme: AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SessionFinishScreen), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishSave), findsOneWidget);
  });
}

class _FinishHarness {
  const _FinishHarness({
    required this.container,
    required this.router,
    required this.activeSessions,
    required this.sessionRepository,
  });

  final ProviderContainer container;
  final GoRouter router;
  final FakeActiveSessionRepository activeSessions;
  final FakeSessionRepository sessionRepository;
}

LibraryEntry _entry({
  String title = 'Bumi Manusia',
  int currentPage = 40,
  int totalPages = 100,
}) {
  return LibraryEntry(
    bookId: 'book-1',
    status: LibraryEntry.statusReading,
    currentPage: currentPage,
    bookTitle: title,
    bookAuthor: 'Pramoedya Ananta Toer',
    bookCoverUrl: 'https://example.com/cover.jpg',
    bookTotalPages: totalPages,
    addedAt: DateTime(2026, 1, 1),
  );
}

ActiveSession _runningSession() {
  return ActiveSession.start(
    bookId: 'book-1',
    bookTitle: 'Bumi Manusia',
    target: const Duration(minutes: 30),
    clock: () => _now,
  );
}

ActiveSession _finishedSession({int readMinutes = 20, int targetMinutes = 30}) {
  DateTime now = DateTime(2026, 10, 23, 9);
  final ActiveSession running = ActiveSession.start(
    bookId: 'book-1',
    bookTitle: 'Bumi Manusia',
    target: Duration(minutes: targetMinutes),
    clock: () => now,
  );
  now = now.add(Duration(minutes: readMinutes));
  return running.copyWithTimer(running.timer.finish());
}

final DateTime _now = DateTime(2026, 10, 23, 9);
