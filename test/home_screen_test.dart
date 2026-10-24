import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/home/data/home_repository.dart';
import 'package:libria/features/home/presentation/home_screen.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';
import 'package:libria/features/notifications/data/app_notification.dart';
import 'package:libria/features/notifications/data/notification_repository.dart';

import 'support/fake_home_repository.dart';
import 'support/fake_library_repository.dart';
import 'support/fake_notification_repository.dart';

void main() {
  const AppUser user = AppUser(
    uid: 'u1',
    displayName: 'Siti Nurhaliza Putri',
    email: 'siti@libria.id',
    role: AppUser.roleUser,
  );

  Future<_HomeHarness> pumpHome(
    WidgetTester tester, {
    required FakeLibraryRepository library,
    required FakeHomeRepository home,
    FakeNotificationRepository? notifications,
    Stream<bool>? connectivity,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeNotificationRepository notificationRepository =
        notifications ?? FakeNotificationRepository();
    addTearDown(notificationRepository.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(user),
        ),
        libraryRepositoryProvider.overrideWith((Ref ref) => library),
        homeRepositoryProvider.overrideWith((Ref ref) => home),
        notificationRepositoryProvider.overrideWithValue(
          notificationRepository,
        ),
        connectivityProvider.overrideWith(
          (Ref ref) => connectivity ?? Stream<bool>.value(true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: HomeScreen()),
        ),
        GoRoute(
          path: '/home/library',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('library-test'))),
        ),
        GoRoute(
          path: '/session/setup',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('setup-test'))),
        ),
        GoRoute(
          path: '/scan',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('scan-test'))),
        ),
        GoRoute(
          path: '/notifications',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('notifications-test'))),
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
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _HomeHarness(router: router);
  }

  FakeLibraryRepository libraryWithReading() {
    return FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: 'Bumi Manusia',
          author: 'Pramoedya Ananta Toer',
          currentPage: 75,
          totalPages: 100,
        ),
      ],
    );
  }

  testWidgets('Menampilkan sapaan, buku aktif, ringkasan, dan slot kosong', (
    WidgetTester tester,
  ) async {
    final FakeHomeRepository home = FakeHomeRepository(
      summary: const HomeTodaySummary(minutes: 30, pages: 75),
    );

    await pumpHome(tester, library: libraryWithReading(), home: home);

    expect(find.text(AppStrings.homeGreeting('Siti')), findsOneWidget);
    expect(find.text(AppStrings.homeReadingLabel), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Pramoedya Ananta Toer'), findsOneWidget);
    expect(find.text(AppStrings.pagesRead(75, 100)), findsOneWidget);
    expect(find.text(AppStrings.homeReadingPercent(75)), findsOneWidget);
    expect(find.text(AppStrings.homeMinutesValue(30)), findsOneWidget);
    expect(find.text(AppStrings.homePagesValue(75)), findsOneWidget);
    expect(find.text(AppStrings.homeTodayEmpty), findsNothing);
    expect(find.text(AppStrings.homeTodayTitle), findsOneWidget);
    expect(find.text(AppStrings.homeQuickActionsTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-challenges-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-events-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-notification-slot')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menampilkan keadaan kosong buku dan ringkasan hari ini', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
    );

    expect(find.text(AppStrings.homeReadingEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.homeChooseBook), findsOneWidget);
    expect(find.text(AppStrings.homeMinutesValue(0)), findsOneWidget);
    expect(find.text(AppStrings.homePagesValue(0)), findsOneWidget);
    expect(find.text(AppStrings.homeTodayEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lanjutkan Membaca membuka pengaturan sesi dengan buku aktif', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: libraryWithReading(),
      home: FakeHomeRepository(),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('home-continue-reading')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/session/setup');
    expect(
      harness.router.state.uri.queryParameters[AppRoutes
          .sessionSetupBookIdParam],
      'book-1',
    );
    expect(find.text('setup-test'), findsOneWidget);
  });

  testWidgets('Pilih Buku pada keadaan kosong membuka Koleksi', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
    );

    await tester.tap(find.text(AppStrings.homeChooseBook));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/home/library');
    expect(find.text('library-test'), findsOneWidget);
  });

  testWidgets('Aksi cepat Mulai Sesi membuka pengaturan sesi', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-action-session')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/session/setup');
    expect(find.text('setup-test'), findsOneWidget);
  });

  testWidgets('Aksi cepat Scan ISBN membuka pemindai', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-action-scan')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/scan');
    expect(find.text('scan-test'), findsOneWidget);
  });

  testWidgets('Slot notifikasi membuka daftar notifikasi', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('home-notification-slot')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/notifications');
    expect(find.text('notifications-test'), findsOneWidget);
  });

  testWidgets('Lencana notifikasi menampilkan jumlah belum dibaca', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository notifications = FakeNotificationRepository(
      notifications: <AppNotification>[
        fakeNotification(1),
        fakeNotification(2),
        fakeNotification(3, read: true),
      ],
    );

    await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      notifications: notifications,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-notification-slot')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menampilkan keadaan memuat untuk buku dan ringkasan', (
    WidgetTester tester,
  ) async {
    final StreamController<List<LibraryEntry>> libraryController =
        StreamController<List<LibraryEntry>>();
    final StreamController<HomeTodaySummary> todayController =
        StreamController<HomeTodaySummary>();
    addTearDown(libraryController.close);
    addTearDown(todayController.close);

    final FakeLibraryRepository library = FakeLibraryRepository()
      ..watchLibraryFactory = () => libraryController.stream;
    final FakeHomeRepository home = FakeHomeRepository()
      ..watchTodaySummaryFactory = () => todayController.stream;

    await pumpHome(tester, library: library, home: home, settle: false);

    expect(find.text(AppStrings.homeReadingLoading), findsOneWidget);
    expect(find.text(AppStrings.homeTodayLoading), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menampilkan galat buku aktif dan ringkasan hari ini', (
    WidgetTester tester,
  ) async {
    final FakeLibraryRepository library = FakeLibraryRepository()
      ..watchLibraryFactory = () => Stream<List<LibraryEntry>>.error(
        const LibraryFailure(AppStrings.homeReadingLoadError),
      );
    final FakeHomeRepository home = FakeHomeRepository()
      ..watchTodaySummaryFactory = () => Stream<HomeTodaySummary>.error(
        const HomeFailure(AppStrings.homeTodayLoadError),
      );

    await pumpHome(tester, library: library, home: home);

    expect(find.text(AppStrings.homeReadingLoadError), findsOneWidget);
    expect(find.text(AppStrings.homeTodayLoadError), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-reading-retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-today-retry')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Offline tanpa data menampilkan pesan ramah untuk kedua bagian', (
    WidgetTester tester,
  ) async {
    final StreamController<List<LibraryEntry>> libraryController =
        StreamController<List<LibraryEntry>>();
    final StreamController<HomeTodaySummary> todayController =
        StreamController<HomeTodaySummary>();
    addTearDown(libraryController.close);
    addTearDown(todayController.close);

    final FakeLibraryRepository library = FakeLibraryRepository()
      ..watchLibraryFactory = () => libraryController.stream;
    final FakeHomeRepository home = FakeHomeRepository()
      ..watchTodaySummaryFactory = () => todayController.stream;

    await pumpHome(
      tester,
      library: library,
      home: home,
      connectivity: Stream<bool>.value(false),
    );

    expect(find.text(AppStrings.homeReadingOffline), findsOneWidget);
    expect(find.text(AppStrings.homeTodayOffline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Coba Lagi memuat ulang ringkasan hari ini', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    final FakeHomeRepository home =
        FakeHomeRepository(
            summary: const HomeTodaySummary(minutes: 12, pages: 8),
          )
          ..watchTodaySummaryFactory = () {
            calls++;
            if (calls == 1) {
              return Stream<HomeTodaySummary>.error(
                const HomeFailure(AppStrings.homeTodayLoadError),
              );
            }
            return Stream<HomeTodaySummary>.value(
              const HomeTodaySummary(minutes: 12, pages: 8),
            );
          };

    await pumpHome(tester, library: libraryWithReading(), home: home);
    expect(find.text(AppStrings.homeTodayLoadError), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('home-today-retry')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.homeTodayLoadError), findsNothing);
    expect(find.text(AppStrings.homeMinutesValue(12)), findsOneWidget);
    expect(find.text(AppStrings.homePagesValue(8)), findsOneWidget);
    expect(calls, greaterThanOrEqualTo(2));
  });

  final List<_LayoutCase> layouts = <_LayoutCase>[
    _LayoutCase(const Size(360, 800), AppTheme.light),
    _LayoutCase(const Size(800, 1280), AppTheme.dark),
    _LayoutCase(const Size(640, 360), AppTheme.dark),
    _LayoutCase(const Size(360, 800), AppTheme.light, textScale: 1.3),
  ];

  for (final _LayoutCase layout in layouts) {
    testWidgets('Tata letak aman pada ${layout.size.width.toInt()}x'
        '${layout.size.height.toInt()} skala ${layout.textScale}', (
      WidgetTester tester,
    ) async {
      await pumpHome(
        tester,
        library: libraryWithReading(),
        home: FakeHomeRepository(
          summary: const HomeTodaySummary(minutes: 30, pages: 75),
        ),
        viewSize: layout.size,
        theme: layout.theme,
        textScale: layout.textScale,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _LayoutCase {
  const _LayoutCase(this.size, this.theme, {this.textScale = 1});

  final Size size;
  final ThemeData theme;
  final double textScale;
}

class _HomeHarness {
  const _HomeHarness({required this.router});

  final GoRouter router;
}
