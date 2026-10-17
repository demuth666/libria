import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_router.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';

void main() {
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required String location,
    User? authUser,
    AppUser? appUser,
    Stream<User?>? authStateStream,
    Stream<AppUser?>? appUserStream,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (Ref ref) => authStateStream ?? Stream<User?>.value(authUser),
        ),
        currentUserProvider.overrideWith(
          (Ref ref) => appUserStream ?? Stream<AppUser?>.value(appUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    final GoRouter router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _RouterTestApp(),
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
    AppRoutes.homeCommunity,
    AppRoutes.homeStats,
    AppRoutes.homeSettings,
    AppRoutes.bookDetailPath('b1'),
    AppRoutes.sessionSetup,
    AppRoutes.sessionRun,
    AppRoutes.sessionFinish,
    AppRoutes.journal,
    AppRoutes.journalNew,
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
  const _RouterTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    // Shell navigasi bawah membaca `AppSemanticColors` dari tema, jadi uji ini
    // memakai `AppTheme.light` dan bukan `ThemeData()` bawaan.
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
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
