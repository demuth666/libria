import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/challenges/data/challenge.dart';
import 'package:libria/features/challenges/data/challenge_participant.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';
import 'package:libria/features/events/data/app_event.dart';
import 'package:libria/features/events/data/event_repository.dart';
import 'package:libria/features/home/data/home_repository.dart';
import 'package:libria/features/home/presentation/home_providers.dart';
import 'package:libria/features/home/presentation/home_screen.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';
import 'package:libria/features/notifications/data/app_notification.dart';
import 'package:libria/features/notifications/data/notification_repository.dart';
import 'package:libria/features/session/data/reading_session.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_challenge_repository.dart';
import 'support/fake_event_repository.dart';
import 'support/fake_home_repository.dart';
import 'support/fake_library_repository.dart';
import 'support/fake_notification_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

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
    FakeBookRepository? books,
    FakeEventRepository? events,
    FakeChallengeRepository? challenges,
    FakeNotificationRepository? notifications,
    Stream<bool>? connectivity,
    DateTime? now,
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

    final FakeEventRepository eventRepository = events ?? FakeEventRepository();
    final FakeChallengeRepository challengeRepository =
        challenges ?? FakeChallengeRepository();
    final FakeBookRepository bookRepository = books ?? FakeBookRepository();
    final DateTime reference = now ?? DateTime(2026, 10, 24, 9);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(user),
        ),
        libraryRepositoryProvider.overrideWith((Ref ref) => library),
        homeRepositoryProvider.overrideWith((Ref ref) => home),
        bookRepositoryProvider.overrideWith((Ref ref) => bookRepository),
        eventRepositoryProvider.overrideWith((Ref ref) => eventRepository),
        challengeRepositoryProvider.overrideWith(
          (Ref ref) => challengeRepository,
        ),
        notificationRepositoryProvider.overrideWithValue(
          notificationRepository,
        ),
        connectivityProvider.overrideWith(
          (Ref ref) => connectivity ?? Stream<bool>.value(true),
        ),
        homeClockProvider.overrideWithValue(() => reference),
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
          path: '/home/library/search',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('catalog-test'))),
        ),
        GoRoute(
          path: '/book/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(child: Text('book-${state.pathParameters['id']}')),
          ),
        ),
        GoRoute(
          path: '/session/setup',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('setup-test'))),
        ),
        GoRoute(
          path: '/notifications',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('notifications-test'))),
        ),
        GoRoute(
          path: '/events',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('events-test'))),
        ),
        GoRoute(
          path: '/events/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(child: Text('event-${state.pathParameters['id']}')),
          ),
        ),
        GoRoute(
          path: '/challenges',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('challenges-test'))),
        ),
        GoRoute(
          path: '/challenges/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: Text('challenge-${state.pathParameters['id']}'),
            ),
          ),
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
    expect(find.text(AppStrings.homeSalutationMorning), findsOneWidget);
    expect(find.text(AppStrings.homeReadingLabel), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Pramoedya Ananta Toer'), findsOneWidget);
    expect(find.text(AppStrings.pagesRead(75, 100)), findsOneWidget);
    expect(find.text(AppStrings.homeReadingPercent(75)), findsOneWidget);
    expect(
      find.text(AppStrings.homeDailyTargetProgress(30, 45)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.homeDailyTargetPages(75)), findsOneWidget);
    expect(find.text(AppStrings.homeActivityTitle), findsOneWidget);
    expect(find.text(AppStrings.homeChartTitle), findsOneWidget);
    expect(find.text(AppStrings.homeRecommendationsTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-daily-quote')),
      findsOneWidget,
    );
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
    expect(
      find.text(AppStrings.homeDailyTargetProgress(0, 45)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.homeDailyTargetPages(0)), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-chart-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-recommendations-empty')),
      findsOneWidget,
    );
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

  testWidgets('Menampilkan statistik pekan ini, grafik, dan rekomendasi', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime(2026, 10, 24, 9);
    final FakeHomeRepository home = FakeHomeRepository(
      recentSessions: <ReadingSession>[
        _session(1, DateTime(2026, 10, 24, 8), 45),
        _session(2, DateTime(2026, 10, 23, 20), 30),
        _session(3, DateTime(2026, 10, 22, 19), 15),
      ],
    );
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: 'Bumi Manusia',
          currentPage: 75,
          totalPages: 100,
        ),
        fakeLibraryEntry(
          2,
          status: LibraryEntry.statusFinished,
          finishedAt: DateTime(2026, 10, 23),
        ),
        fakeLibraryEntry(
          3,
          status: LibraryEntry.statusFinished,
          finishedAt: DateTime(2026, 10, 22),
        ),
        fakeLibraryEntry(
          4,
          status: LibraryEntry.statusFinished,
          finishedAt: DateTime(2026, 10, 15),
        ),
      ],
    );
    final FakeBookRepository books = FakeBookRepository(
      books: <Book>[fakeBook(1, title: 'Atomic Habits', author: 'James Clear')],
    );

    await pumpHome(
      tester,
      library: library,
      home: home,
      books: books,
      now: now,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-activity-finished')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('+1 dari pekan lalu'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-activity-sessions')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.homeActivityAverage(3 / 7)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-activity-minutes')),
        matching: find.text(AppStrings.homeActivityDuration(90)),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.homeActivityTarget(29)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-activity-streak')),
        matching: find.text(AppStrings.homeStreakValue(3)),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-activity-chart')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.homeChartHighest(45)), findsOneWidget);
    expect(find.text('Atomic Habits'), findsOneWidget);
    expect(find.text('Fiksi'), findsOneWidget);
    expect(find.text(AppStrings.homeBookPages(200)), findsOneWidget);
    expect(
      find.text(AppStrings.homeQuoteAttribution(AppStrings.homeQuoteSource)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kartu rekomendasi membuka detail buku', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository books = FakeBookRepository(
      books: <Book>[fakeBook(1, title: 'Atomic Habits')],
    );
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      books: books,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-book-book-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('home-book-book-1')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/book/book-1');
    expect(find.text('book-book-1'), findsOneWidget);
  });

  testWidgets('Lihat Semua rekomendasi membuka katalog', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      books: FakeBookRepository(books: <Book>[fakeBook(1)]),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-recommendations-see-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('home-recommendations-see-all')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/home/library/search');
    expect(find.text('catalog-test'), findsOneWidget);
  });

  testWidgets('Statistik aktivitas menampilkan galat dan bisa dimuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeHomeRepository home = FakeHomeRepository()
      ..watchRecentSessionsFactory = () => Stream<List<ReadingSession>>.error(
        const HomeFailure(AppStrings.homeActivityLoadError),
      );

    await pumpHome(tester, library: FakeLibraryRepository(), home: home);

    expect(find.text(AppStrings.homeActivityLoadError), findsOneWidget);

    home.watchRecentSessionsFactory = null;
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-activity-retry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('home-activity-retry')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.homeActivityLoadError), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('home-chart-empty')),
      findsOneWidget,
    );
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

  testWidgets('Menampilkan maksimal dua kegiatan terdekat di Beranda', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository events = FakeEventRepository(
      events: <AppEvent>[
        fakeEvent(1, startAt: DateTime(2030, 1, 1, 19)),
        fakeEvent(2, startAt: DateTime(2030, 1, 2, 19)),
        fakeEvent(3, startAt: DateTime(2030, 1, 3, 19)),
      ],
    );

    await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      events: events,
    );

    expect(find.text(AppStrings.homeEventsTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-event-event-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-event-event-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-event-event-3')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('home-events-empty')),
      findsNothing,
    );
    expect(events.requestedUpcomingLimits, <int>[homeUpcomingEventLimit]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kegiatan terdekat membuka detail kegiatan', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository events = FakeEventRepository(
      events: <AppEvent>[fakeEvent(1, startAt: DateTime(2030, 1, 1, 19))],
    );

    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      events: events,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-event-event-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('home-event-event-1')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/events/event-1');
    expect(find.text('event-event-1'), findsOneWidget);
  });

  testWidgets('Lihat Semua membuka daftar kegiatan', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-events-see-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('home-events-see-all')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/events');
    expect(find.text('events-test'), findsOneWidget);
  });

  testWidgets('Kegiatan terdekat menampilkan galat dan bisa dimuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository events = FakeEventRepository()
      ..watchUpcomingError = const EventFailure(AppStrings.homeEventsLoadError);

    await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      events: events,
    );

    expect(find.text(AppStrings.homeEventsLoadError), findsOneWidget);

    events.watchUpcomingError = null;
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-events-retry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('home-events-retry')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.homeEventsLoadError), findsNothing);
    expect(find.text(AppStrings.homeEventsEmpty), findsOneWidget);
  });

  testWidgets('Tantangan aktif tampil dengan progres pengguna', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Baca 10 Buku',
      type: Challenge.typeBooks,
      targetValue: 10,
      participantCount: 3,
    );
    final FakeChallengeRepository challenges =
        FakeChallengeRepository(
            challenges: <Challenge>[challenge],
            activeChallenges: <Challenge>[challenge],
          )
          ..participations[challenge.id] = const ChallengeParticipant(
            userId: 'u1',
            userName: 'Siti',
            progress: 4,
          );

    await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      challenges: challenges,
    );

    expect(find.text(AppStrings.homeChallengesTitle), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('home-challenge-${challenge.id}')),
      findsOneWidget,
    );
    expect(
      find.text(
        AppStrings.challengeProgressOfTarget(
          4,
          10,
          AppStrings.adminChallengeUnitBooks,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Lihat Semua membuka daftar tantangan', (
    WidgetTester tester,
  ) async {
    final _HomeHarness harness = await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-challenges-see-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('home-challenges-see-all')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/challenges');
    expect(find.text('challenges-test'), findsOneWidget);
  });

  testWidgets('Tantangan aktif menampilkan galat dan bisa dimuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository challenges = FakeChallengeRepository()
      ..watchActiveError = const ChallengeFailure(
        AppStrings.challengesLoadError,
      );

    await pumpHome(
      tester,
      library: FakeLibraryRepository(),
      home: FakeHomeRepository(),
      challenges: challenges,
    );

    expect(find.text(AppStrings.challengesLoadError), findsOneWidget);

    challenges.watchActiveError = null;
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-challenges-retry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('home-challenges-retry')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.challengesLoadError), findsNothing);
    expect(find.text(AppStrings.homeChallengesEmpty), findsOneWidget);
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
    expect(
      find.text(AppStrings.homeDailyTargetProgress(12, 45)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.homeDailyTargetPages(8)), findsOneWidget);
    expect(calls, greaterThanOrEqualTo(2));
  });

  final List<_LayoutCase> layouts = <_LayoutCase>[
    _LayoutCase(const Size(360, 800), AppTheme.light),
    _LayoutCase(const Size(800, 1280), AppTheme.dark),
    _LayoutCase(const Size(640, 360), AppTheme.dark),
    _LayoutCase(const Size(360, 800), AppTheme.light, textScale: 1.3),
    _LayoutCase(const Size(360, 800), AppTheme.dark, textScale: 1.5),
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

ReadingSession _session(int index, DateTime startedAt, int minutes) {
  return ReadingSession(
    id: 'session-$index',
    bookId: 'book-1',
    bookTitle: 'Bumi Manusia',
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(minutes: minutes)),
    durationSeconds: minutes * 60,
    targetSeconds: 30 * 60,
    startPage: 0,
    endPage: minutes,
    targetReached: true,
  );
}
