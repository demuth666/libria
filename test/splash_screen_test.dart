import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/auth/presentation/splash_screen.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (BuildContext context, GoRouterState state) =>
              const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('login-screen')),
        ),
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('home-screen')),
        ),
        GoRoute(
          path: '/admin',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('admin-screen')),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<void> pumpSplash(
    WidgetTester tester, {
    required Stream<User?> authState,
    Stream<AppUser?>? currentUser,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((Ref ref) => authState),
          if (currentUser != null)
            currentUserProvider.overrideWith((Ref ref) => currentUser),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  testWidgets('Splash menampilkan branding selama status auth dimuat', (
    WidgetTester tester,
  ) async {
    final StreamController<User?> authController = StreamController<User?>();
    addTearDown(authController.close);

    await pumpSplash(tester, authState: authController.stream);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.splashQuote), findsOneWidget);
    expect(find.text(AppStrings.splashTagline), findsOneWidget);
    expect(
      find.text(AppStrings.splashStatusPreparing.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text('login-screen'), findsNothing);
  });

  testWidgets('Splash membuka login setelah auth selesai tanpa pengguna', (
    WidgetTester tester,
  ) async {
    await pumpSplash(tester, authState: Stream<User?>.value(null));
    await tester.pumpAndSettle();

    expect(find.text('login-screen'), findsOneWidget);
  });

  testWidgets('Splash membuka home untuk pengguna dengan role user', (
    WidgetTester tester,
  ) async {
    await pumpSplash(
      tester,
      authState: Stream<User?>.value(_FakeUser()),
      currentUser: Stream<AppUser?>.value(_appUser(AppUser.roleUser)),
    );
    await tester.pumpAndSettle();

    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('Splash membuka admin untuk pengguna dengan role admin', (
    WidgetTester tester,
  ) async {
    await pumpSplash(
      tester,
      authState: Stream<User?>.value(_FakeUser()),
      currentUser: Stream<AppUser?>.value(_appUser(AppUser.roleAdmin)),
    );
    await tester.pumpAndSettle();

    expect(find.text('admin-screen'), findsOneWidget);
  });

  testWidgets('Splash menampilkan pesan galat dan tombol coba lagi', (
    WidgetTester tester,
  ) async {
    await pumpSplash(
      tester,
      authState: Stream<User?>.error(Exception('auth gagal')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.splashError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });
}

AppUser _appUser(String role) {
  return AppUser(uid: 'u1', displayName: 'Pembaca', email: 'a@b.c', role: role);
}

/// Pengguna Firebase Auth palsu; layar Splash hanya memerlukan objek non-null
/// karena role dibaca dari `currentUserProvider`.
class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
