import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/active_session_repository.dart';
import 'package:libria/features/session/data/session_alarm_service.dart';
import 'package:libria/features/session/data/session_background_service.dart';
import 'package:libria/features/session/data/session_timer_engine.dart';
import 'package:libria/features/session/presentation/active_session_providers.dart';
import 'package:libria/features/session/presentation/session_run_screen.dart';

import 'support/fake_active_session_repository.dart';
import 'support/fake_session_alarm_service.dart';
import 'support/fake_session_background_service.dart';

void main() {
  Future<_RunHarness> pumpRun(
    WidgetTester tester, {
    ActiveSession? session,
    FakeActiveSessionRepository? repository,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeActiveSessionRepository sessions =
        repository ?? FakeActiveSessionRepository(session: session);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        activeSessionRepositoryProvider.overrideWithValue(sessions),
        sessionBackgroundServiceProvider.overrideWithValue(
          FakeSessionBackgroundService(),
        ),
        sessionAlarmServiceProvider.overrideWithValue(
          FakeSessionAlarmService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.sessionRun,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.sessionRun,
          builder: (BuildContext context, GoRouterState state) =>
              const SessionRunScreen(),
        ),
        GoRoute(
          path: AppRoutes.sessionFinish,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('session-finish-test'))),
        ),
        GoRoute(
          path: AppRoutes.sessionSetup,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('session-setup-test'))),
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

    return _RunHarness(
      container: container,
      router: router,
      sessions: sessions,
    );
  }

  testWidgets('Header hanya judul buku dan angka timer mengikuti cap waktu', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-1',
      bookTitle: 'Bumi Manusia',
      target: const Duration(minutes: 30),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 5, seconds: 12));

    final _RunHarness harness = await pumpRun(tester, session: session);

    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('00:05:12'), findsOneWidget);
    expect(find.text(AppStrings.sessionRunTarget('00:30:00')), findsOneWidget);
    expect(
      find.text(AppStrings.sessionRunRemaining('00:24:48')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.sessionRunStatusRunning), findsOneWidget);
    expect(find.text(AppStrings.sessionRunBackgroundHint), findsOneWidget);
    expect(find.textContaining('Bab'), findsNothing);

    final LinearProgressIndicator progress = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(progress.value, closeTo(312 / 1800, 0.0001));

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:06:12'), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.sessionRun);
  });

  testWidgets('Jeda membekukan waktu dan Lanjut melanjutkan dari mesin timer', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-2',
      bookTitle: 'Laskar Pelangi',
      target: const Duration(minutes: 30),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 5));

    final _RunHarness harness = await pumpRun(tester, session: session);
    expect(find.text('00:05:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('session-run-pause')));
    await tester.pump();
    await tester.pump();

    expect(
      harness.container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.paused,
    );
    expect(
      find.byKey(const ValueKey<String>('session-run-resume')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.sessionRunPausedMessage), findsOneWidget);

    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:05:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('session-run-resume')));
    await tester.pump();
    await tester.pump();

    expect(
      harness.container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.running,
    );

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:06:00'), findsOneWidget);
  });

  testWidgets('Selesai menghentikan timer lalu membuka penyelesaian sesi', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-3',
      bookTitle: 'Sapiens',
      target: const Duration(minutes: 20),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 3));

    final _RunHarness harness = await pumpRun(tester, session: session);

    await tester.tap(find.byKey(const ValueKey<String>('session-run-finish')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.sessionFinish);
    expect(find.text('session-finish-test'), findsOneWidget);
    expect(harness.sessions.saveCalls, greaterThan(0));
    expect(
      harness.container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.finished,
    );
  });

  testWidgets('Target tercapai menampilkan 100 persen dan tombol Selesai', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-4',
      bookTitle: 'Pulang',
      target: const Duration(minutes: 20),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 25));

    final _RunHarness harness = await pumpRun(tester, session: session);

    expect(find.text(AppStrings.sessionRunStatusTargetReached), findsOneWidget);
    expect(find.text('00:20:00'), findsOneWidget);
    expect(find.text(AppStrings.sessionRunProgress(100)), findsOneWidget);
    expect(
      find.text(AppStrings.sessionRunTargetReachedMessage),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('session-run-pause')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('session-run-finish')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('session-run-finish')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.sessionFinish);
    expect(
      harness.container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.finished,
    );
    expect(
      harness.container.read(activeSessionProvider).requireValue!.timer.elapsed,
      const Duration(minutes: 20),
    );
  });

  testWidgets('Sesi yang sudah selesai bisa dilanjutkan ke penyelesaian', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession running = ActiveSession.start(
      bookId: 'book-5',
      bookTitle: 'Ronggeng Dukuh Paruk',
      target: const Duration(minutes: 15),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 4));
    final ActiveSession session = running.copyWithTimer(running.timer.finish());

    final _RunHarness harness = await pumpRun(tester, session: session);

    expect(find.text(AppStrings.sessionRunStatusFinished), findsOneWidget);
    expect(find.text(AppStrings.sessionRunFinishedMessage), findsOneWidget);
    expect(find.text(AppStrings.sessionRunContinue), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('session-run-finish')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.sessionFinish);
  });

  testWidgets('Tidak ada sesi aktif menampilkan ajakan mengatur sesi', (
    WidgetTester tester,
  ) async {
    final _RunHarness harness = await pumpRun(tester);

    expect(find.text(AppStrings.sessionRunNoSessionTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionRunNoSessionMessage), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('session-run-open-setup')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.sessionSetup);
    expect(find.text('session-setup-test'), findsOneWidget);
  });

  testWidgets('Memuat sesi menampilkan loading sampai penyimpanan selesai', (
    WidgetTester tester,
  ) async {
    final _PendingActiveSessionRepository repository =
        _PendingActiveSessionRepository();

    await pumpRun(tester, repository: repository);

    expect(find.text(AppStrings.sessionRunLoading), findsOneWidget);

    repository.completer.complete(null);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text(AppStrings.sessionRunNoSessionTitle), findsOneWidget);
  });

  testWidgets('Galat muat sesi bisa dicoba lagi', (WidgetTester tester) async {
    final FakeActiveSessionRepository repository = FakeActiveSessionRepository()
      ..loadError = const ActiveSessionFailure(
        AppStrings.sessionActiveLoadError,
      );

    await pumpRun(tester, repository: repository);

    expect(find.text(AppStrings.sessionActiveLoadError), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text(AppStrings.sessionRunNoSessionTitle), findsOneWidget);
  });

  testWidgets('Galat menyimpan aksi tampil sebagai pesan ramah', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-6',
      bookTitle: 'Bumi Manusia',
      target: const Duration(minutes: 30),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 2));
    final FakeActiveSessionRepository repository =
        FakeActiveSessionRepository(session: session)
          ..saveError = const ActiveSessionFailure(
            AppStrings.sessionActiveSaveError,
          );

    await pumpRun(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('session-run-pause')));
    await tester.pump();
    await tester.pump();

    expect(find.text(AppStrings.sessionActiveSaveError), findsOneWidget);
    expect(find.text(AppStrings.sessionRunPause), findsNothing);
    expect(find.text(AppStrings.sessionRunResume), findsOneWidget);
  });

  testWidgets('Layar timer rapi di mode gelap pada ponsel', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-7',
      bookTitle: 'Judul Buku yang Panjang untuk Menguji Tata Letak Header',
      target: const Duration(hours: 2),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 12));

    await pumpRun(
      tester,
      session: session,
      viewSize: const Size(360, 800),
      theme: AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SessionRunScreen), findsOneWidget);
    expect(find.text(AppStrings.sessionRunPause), findsOneWidget);
    expect(find.text(AppStrings.sessionRunFinish), findsOneWidget);
  });

  testWidgets('Layar timer rapi di mode gelap pada tablet', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-8',
      bookTitle: 'Bumi Manusia',
      target: const Duration(minutes: 45),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 5));

    await pumpRun(
      tester,
      session: session,
      viewSize: const Size(800, 1280),
      theme: AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SessionRunScreen), findsOneWidget);
    expect(find.text('00:05:00'), findsOneWidget);
  });
}

class _RunHarness {
  const _RunHarness({
    required this.container,
    required this.router,
    required this.sessions,
  });

  final ProviderContainer container;
  final GoRouter router;
  final FakeActiveSessionRepository sessions;
}

class _PendingActiveSessionRepository extends FakeActiveSessionRepository {
  final Completer<ActiveSession?> completer = Completer<ActiveSession?>();

  @override
  Future<ActiveSession?> load() {
    loadCalls++;
    return completer.future;
  }
}
