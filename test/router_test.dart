import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_router.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';
import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/community/data/post_like_repository.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/home/data/home_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';
import 'package:libria/features/journal/data/journal_repository.dart';
import 'package:libria/features/library/data/library_repository.dart';
import 'package:libria/features/reports/data/reading_report_repository.dart';
import 'package:libria/features/reports/data/report_repository.dart';
import 'package:libria/features/reviews/data/review_repository.dart';
import 'package:libria/features/session/data/active_session_repository.dart';
import 'package:libria/features/session/data/session_alarm_service.dart';
import 'package:libria/features/session/data/session_background_service.dart';
import 'package:libria/features/session/data/session_repository.dart';
import 'package:libria/features/stats/data/reading_stats_repository.dart';

import 'support/fake_active_session_repository.dart';
import 'support/fake_book_repository.dart';
import 'support/fake_home_repository.dart';
import 'support/fake_isbn_log_repository.dart';
import 'support/fake_journal_repository.dart';
import 'support/fake_library_repository.dart';
import 'support/fake_post_repository.dart';
import 'support/fake_reading_report.dart';
import 'support/fake_reading_stats_repository.dart';
import 'support/fake_report_repository.dart';
import 'support/fake_review_repository.dart';
import 'support/fake_session_alarm_service.dart';
import 'support/fake_session_background_service.dart';
import 'support/fake_session_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required String location,
    User? authUser,
    AppUser? appUser,
    Stream<User?>? authStateStream,
    Stream<AppUser?>? appUserStream,
    Size? viewSize,
    ThemeData? theme,
  }) async {
    if (viewSize != null) {
      tester.view.physicalSize = viewSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    final ProviderContainer container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (Ref ref) => authStateStream ?? Stream<User?>.value(authUser),
        ),
        currentUserProvider.overrideWith(
          (Ref ref) => appUserStream ?? Stream<AppUser?>.value(appUser),
        ),
        // Dashboard admin memakai agregasi Firestore; uji rute ini tidak
        // memakai Firebase sehingga angkanya diganti nilai nol.
        adminDashboardRepositoryProvider.overrideWith(
          (Ref ref) => _FakeAdminDashboardRepository(),
        ),
        bookRepositoryProvider.overrideWith((Ref ref) => FakeBookRepository()),
        // Antrean log ISBN juga membaca Firestore; ganti dengan repository
        // palsu agar uji rute tidak membutuhkan Firebase.
        isbnLogRepositoryProvider.overrideWith(
          (Ref ref) => FakeIsbnLogRepository(),
        ),
        // Layar moderasi laporan membaca koleksi laporan; ganti dengan
        // repository palsu agar uji rute tidak membutuhkan Firebase.
        reportRepositoryProvider.overrideWith(
          (Ref ref) => FakeReportRepository(),
        ),
        // Layar Koleksi membaca rak dan status koneksi; ganti keduanya agar uji
        // rute tidak membutuhkan Firebase maupun plugin konektivitas.
        libraryRepositoryProvider.overrideWith(
          (Ref ref) => FakeLibraryRepository(),
        ),
        // Ringkasan Beranda membaca subkoleksi sesi; ganti dengan repository
        // palsu agar uji rute tidak membutuhkan Firebase.
        homeRepositoryProvider.overrideWith((Ref ref) => FakeHomeRepository()),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(true),
        ),
        // Layar timer sesi membaca penyimpanan lokal dan layanan latar
        // belakang; ganti dengan versi palsu agar uji rute tidak menyentuh
        // plugin `shared_preferences`, `flutter_foreground_task`, atau
        // notifikasi lokal.
        activeSessionRepositoryProvider.overrideWithValue(
          FakeActiveSessionRepository(),
        ),
        sessionBackgroundServiceProvider.overrideWithValue(
          FakeSessionBackgroundService(),
        ),
        sessionAlarmServiceProvider.overrideWithValue(
          FakeSessionAlarmService(),
        ),
        // Layar penyelesaian sesi menulis sesi dan progres buku; ganti dengan
        // repository palsu agar uji rute tidak menyentuh Firestore.
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        // Layar Statistik membaca sesi dan buku selesai; ganti dengan
        // repository palsu agar uji rute tidak menyentuh Firestore.
        readingStatsRepositoryProvider.overrideWithValue(
          FakeReadingStatsRepository(),
        ),
        // Layar Laporan membaca sesi dan entri rak; ganti dengan repository
        // palsu agar uji rute tidak menyentuh Firestore.
        readingReportRepositoryProvider.overrideWithValue(
          FakeReadingReportRepository(),
        ),
        // Layar Jurnal membaca dan menulis subkoleksi jurnal; ganti dengan
        // repository palsu agar uji rute tidak menyentuh Firestore.
        journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
        // Detail Buku membaca ulasan dan agregat rating; ganti dengan
        // repository palsu agar uji rute tidak menyentuh Firestore.
        reviewRepositoryProvider.overrideWithValue(FakeReviewRepository()),
        // Feed Komunitas membaca koleksi postingan dan status like; ganti
        // keduanya dengan repository palsu agar uji rute tidak menyentuh
        // Firestore.
        postRepositoryProvider.overrideWithValue(FakePostRepository()),
        postLikeRepositoryProvider.overrideWithValue(FakePostLikeRepository()),
      ],
    );
    addTearDown(container.dispose);
    final GoRouter router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _RouterTestApp(theme: theme),
      ),
    );
    router.go(location);
    await tester.pumpAndSettle();
    return router;
  }

  final List<String> publicRoutes = <String>[
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  ];

  final List<String> userRoutes = <String>[
    AppRoutes.home,
    AppRoutes.homeLibrary,
    AppRoutes.homeLibrarySearch,
    AppRoutes.homeCommunity,
    AppRoutes.homeStats,
    AppRoutes.homeStatsHistory,
    AppRoutes.homeSettings,
    AppRoutes.bookDetailPath('b1'),
    AppRoutes.isbnScan,
    AppRoutes.sessionSetup,
    AppRoutes.sessionRun,
    AppRoutes.sessionFinish,
    AppRoutes.journal,
    AppRoutes.journalNew,
    AppRoutes.postNew,
    AppRoutes.report,
    AppRoutes.notifications,
    AppRoutes.events,
    AppRoutes.eventDetailPath('e1'),
    AppRoutes.challenges,
    AppRoutes.challengeDetailPath('c1'),
    AppRoutes.postDetailPath('p1'),
  ];

  final List<String> adminRoutes = <String>[
    AppRoutes.admin,
    AppRoutes.adminBooks,
    AppRoutes.adminBookNew,
    AppRoutes.adminBookEditPath('b1'),
    AppRoutes.adminIsbnLogs,
    AppRoutes.adminReports,
    AppRoutes.adminEvents,
    AppRoutes.adminChallenges,
  ];

  for (final String location in publicRoutes) {
    testWidgets('Rute publik $location bisa dibuka tanpa login', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, location: location);

      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, location);
    });
  }

  for (final String location in userRoutes) {
    testWidgets('Rute user $location bisa dibuka tanpa galat', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(
        tester,
        location: location,
        authUser: _FakeUser(),
        appUser: _appUser(AppUser.roleUser),
      );

      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, location);
    });
  }

  for (final String location in adminRoutes) {
    testWidgets('Rute admin $location bisa dibuka tanpa galat', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(
        tester,
        location: location,
        authUser: _FakeUser(),
        appUser: _appUser(AppUser.roleAdmin),
      );

      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, location);
    });
  }

  testWidgets('Rute pencarian katalog tampil di dalam shell user', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.homeLibrarySearch,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );

    expect(router.state.uri.path, AppRoutes.homeLibrarySearch);
    expect(find.text(AppStrings.catalogSearchTitle), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchInitialTitle), findsOneWidget);
    final AppBottomNavBar navBar = tester.widget<AppBottomNavBar>(
      find.byType(AppBottomNavBar),
    );
    expect(navBar.selectedIndex, 1);
  });

  testWidgets('Tamu yang membuka pencarian katalog dikembalikan ke login', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.homeLibrarySearch,
    );

    expect(router.state.uri.path, AppRoutes.login);
    expect(find.text(AppStrings.loginWelcomeTitle), findsOneWidget);
  });

  testWidgets('Admin yang membuka pencarian katalog diarahkan ke dashboard', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.homeLibrarySearch,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleAdmin),
    );

    expect(router.state.uri.path, AppRoutes.admin);
    expect(find.text(AppStrings.adminDashboardTitle), findsOneWidget);
  });

  testWidgets('Rute admin log ISBN menampilkan antrean, bukan placeholder', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.adminIsbnLogs,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleAdmin),
    );

    expect(router.state.uri.path, AppRoutes.adminIsbnLogs);
    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsOneWidget);
    expect(
      find.text(AppStrings.routeNotBuiltYet(AppStrings.adminIsbnLogsTitle)),
      findsNothing,
    );
  });

  testWidgets('Rute Komunitas menampilkan feed, bukan placeholder', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.homeCommunity,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );

    expect(router.state.uri.path, AppRoutes.homeCommunity);
    expect(find.text(AppStrings.communityEmptyTitle), findsOneWidget);
    expect(
      find.text(AppStrings.routeNotBuiltYet(AppStrings.communityTitle)),
      findsNothing,
    );
    final AppBottomNavBar navBar = tester.widget<AppBottomNavBar>(
      find.byType(AppBottomNavBar),
    );
    expect(navBar.selectedIndex, 2);
  });

  testWidgets('Rute buat postingan menampilkan formulir, bukan placeholder', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.postNew,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );

    expect(router.state.uri.path, AppRoutes.postNew);
    expect(find.text(AppStrings.communityPostNewTitle), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('post-submit')), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsNothing);
  });

  testWidgets('Splash berpindah ke login tanpa pengguna', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester, location: AppRoutes.splash);

    expect(router.state.uri.path, AppRoutes.login);
    expect(find.text(AppStrings.loginWelcomeTitle), findsOneWidget);
  });

  testWidgets('Tamu yang membuka rute user dikembalikan ke login', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester, location: AppRoutes.home);

    expect(router.state.uri.path, AppRoutes.login);
    expect(find.text(AppStrings.loginWelcomeTitle), findsOneWidget);
  });

  testWidgets('Pengguna role user yang membuka admin ditolak ke home', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.adminBooks,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );

    expect(router.state.uri.path, AppRoutes.home);
    expect(find.text(AppStrings.homeTitle), findsWidgets);
  });

  testWidgets('Admin yang membuka rute user diarahkan ke dashboard admin', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.home,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleAdmin),
    );

    expect(router.state.uri.path, AppRoutes.admin);
    expect(find.text(AppStrings.adminDashboardTitle), findsOneWidget);
  });

  testWidgets('Pengguna yang sudah login tidak bisa membuka layar login', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.login,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );

    expect(router.state.uri.path, AppRoutes.home);
  });

  testWidgets('Perubahan role langsung memindahkan pengguna ke area baru', (
    WidgetTester tester,
  ) async {
    final StreamController<AppUser?> roleController =
        StreamController<AppUser?>();
    addTearDown(roleController.close);
    roleController.add(_appUser(AppUser.roleUser));

    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.home,
      authUser: _FakeUser(),
      appUserStream: roleController.stream,
    );
    expect(router.state.uri.path, AppRoutes.home);

    roleController.add(_appUser(AppUser.roleAdmin));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.admin);
    expect(find.text(AppStrings.adminDashboardTitle), findsOneWidget);
  });

  testWidgets('Keluar dari akun langsung mengembalikan pengguna ke login', (
    WidgetTester tester,
  ) async {
    final StreamController<User?> authController = StreamController<User?>();
    addTearDown(authController.close);
    authController.add(_FakeUser());

    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.home,
      authStateStream: authController.stream,
      appUser: _appUser(AppUser.roleUser),
    );
    expect(router.state.uri.path, AppRoutes.home);

    authController.add(null);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.login);
  });

  testWidgets('Navigasi bawah berpindah tab di dalam shell user', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );
    expect(find.text(AppStrings.homeTitle), findsWidgets);

    await tester.tap(find.byTooltip(AppStrings.libraryTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.libraryTitle), findsWidgets);

    await tester.tap(find.byTooltip(AppStrings.communityTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.communityTitle), findsWidgets);

    await tester.tap(find.byTooltip(AppStrings.profileTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.profileTitle), findsWidgets);
  });

  testWidgets('Tombol Sesi Baca membuka alur sesi dan bukan tab shell', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );

    await tester.tap(find.byTooltip(AppStrings.sessionNavLabel));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionSetupTitle), findsOneWidget);
  });

  testWidgets('Statistik membuka riwayat sesi dan bisa kembali', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      location: AppRoutes.homeStats,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('stats-session-history')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('stats-session-history')),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.homeStatsHistory);
    expect(find.text(AppStrings.sessionHistoryTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryEmptyTitle), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('session-history-back')),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.homeStats);
  });

  testWidgets('Shell memakai bottom bar pada layar compact', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
      viewSize: const Size(360, 800),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.getSize(find.byType(BackdropFilter)).width, 360);
    expect(find.byTooltip(AppStrings.homeTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.libraryTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.communityTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.profileTitle), findsOneWidget);

    for (final String label in <String>[
      AppStrings.libraryTitle,
      AppStrings.communityTitle,
      AppStrings.profileTitle,
      AppStrings.homeTitle,
    ]) {
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Shell tetap memakai bottom bar di tablet portrait', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
      viewSize: const Size(800, 1280),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(find.byType(BackdropFilter)).width, 800);
    expect(tester.getCenter(find.byType(BackdropFilter)).dx, closeTo(400, 1));
    expect(find.byTooltip(AppStrings.libraryTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.sessionNavLabel), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.libraryTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.libraryTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shell tetap memakai bottom bar di tablet landscape', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      authUser: _FakeUser(),
      appUser: _appUser(AppUser.roleUser),
      viewSize: const Size(1280, 800),
      theme: AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(find.byType(BackdropFilter)).width, 1280);
    expect(tester.getCenter(find.byType(BackdropFilter)).dx, closeTo(640, 1));
    expect(find.byTooltip(AppStrings.libraryTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.sessionNavLabel), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.profileTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.profileTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

AppUser _appUser(String role) {
  return AppUser(
    uid: 'u1',
    displayName: 'Pembaca',
    email: 'pembaca@libria.id',
    role: role,
  );
}

/// Membaca [routerProvider] lewat `ref.watch` seperti `LibriaApp` supaya
/// provider tetap aktif selama uji dan `refreshListenable` bekerja.
class _RouterTestApp extends ConsumerWidget {
  const _RouterTestApp({this.theme});

  final ThemeData? theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    // Shell navigasi membaca `AppSemanticColors` dari tema, jadi uji ini
    // memakai tema aplikasi dan bukan `ThemeData()` bawaan.
    return MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: router,
    );
  }
}

/// Pengguna Firebase Auth palsu; router hanya membaca [User.emailVerified]
/// karena data role berasal dari `currentUserProvider` yang di-override.
class _FakeUser implements User {
  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Dashboard admin palsu tanpa akses Firestore untuk uji navigasi router.
class _FakeAdminDashboardRepository implements AdminDashboardRepository {
  @override
  Future<AdminDashboardStats> fetchStats() async {
    return const AdminDashboardStats(
      totalBooks: 0,
      openReports: 0,
      unhandledIsbnLogs: 0,
      totalUsers: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
