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
import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';

void main() {
  Future<_Harness> pumpDashboard(
    WidgetTester tester, {
    required _FakeAdminDashboardRepository dashboardRepository,
    _FakeAuthRepository? authRepository,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    bool settle = true,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final _FakeAuthRepository auth = authRepository ?? _FakeAuthRepository();
    addTearDown(auth.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((Ref ref) => auth),
        authStateProvider.overrideWith((Ref ref) => auth.authStateChanges),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(_adminUser),
        ),
        adminDashboardRepositoryProvider.overrideWith(
          (Ref ref) => dashboardRepository,
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _DashboardTestApp(theme: theme ?? AppTheme.light),
      ),
    );
    router.go(AppRoutes.admin);

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _Harness(router: router, auth: auth);
  }

  testWidgets('Dashboard menampilkan keadaan loading saat angka dimuat', (
    WidgetTester tester,
  ) async {
    final _FakeAdminDashboardRepository repository =
        _FakeAdminDashboardRepository()
          ..completer = Completer<AdminDashboardStats>();

    await pumpDashboard(tester, dashboardRepository: repository, settle: false);

    expect(find.text(AppStrings.adminDashboardLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.adminStatBooksLabel), findsNothing);

    repository.completer!.complete(repository.stats);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminStatBooksLabel), findsOneWidget);
  });

  testWidgets('Empat kartu menampilkan angka sukses termasuk nilai 0', (
    WidgetTester tester,
  ) async {
    final _FakeAdminDashboardRepository repository =
        _FakeAdminDashboardRepository()
          ..stats = const AdminDashboardStats(
            totalBooks: 0,
            openReports: 7,
            unhandledIsbnLogs: 0,
            totalUsers: 120,
          );

    await pumpDashboard(tester, dashboardRepository: repository);

    expect(find.text(AppStrings.adminStatBooksLabel), findsOneWidget);
    expect(find.text(AppStrings.adminStatOpenReportsLabel), findsOneWidget);
    expect(
      find.text(AppStrings.adminStatUnhandledIsbnLogsLabel),
      findsOneWidget,
    );
    expect(find.text(AppStrings.adminStatUsersLabel), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('7'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(AppStrings.adminDashboardLoadError), findsNothing);
  });

  testWidgets(
    'Galat menampilkan pesan ramah dan tombol Coba Lagi memuat ulang',
    (WidgetTester tester) async {
      final _FakeAdminDashboardRepository repository =
          _FakeAdminDashboardRepository()..failuresRemaining = 1;

      await pumpDashboard(tester, dashboardRepository: repository);

      expect(find.text(AppStrings.adminDashboardLoadError), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
      expect(find.text(AppStrings.adminStatBooksLabel), findsNothing);

      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 2);
      expect(find.text(AppStrings.adminDashboardLoadError), findsNothing);
      expect(find.text('12'), findsOneWidget);
      expect(find.text(AppStrings.adminStatBooksLabel), findsOneWidget);
    },
  );

  testWidgets('Setiap menu membuka rute admin yang sesuai', (
    WidgetTester tester,
  ) async {
    final _FakeAdminDashboardRepository repository =
        _FakeAdminDashboardRepository();
    final _Harness harness = await pumpDashboard(
      tester,
      dashboardRepository: repository,
    );

    final List<(String, String)> menuRoutes = <(String, String)>[
      (AppStrings.adminMenuBooks, AppStrings.adminBooksTitle),
      (AppStrings.adminMenuIsbnLogs, AppStrings.adminIsbnLogsTitle),
      (AppStrings.adminMenuReports, AppStrings.adminReportsTitle),
      (AppStrings.adminMenuEvents, AppStrings.adminEventsTitle),
      (AppStrings.adminMenuChallenges, AppStrings.adminChallengesTitle),
    ];

    for (final (String label, String title) in menuRoutes) {
      final Finder item = find.text(label);
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.routeNotBuiltYet(title)),
        findsOneWidget,
        reason: label,
      );

      harness.router.go(AppRoutes.admin);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Batal pada dialog keluar tidak mengubah apa pun', (
    WidgetTester tester,
  ) async {
    final _FakeAdminDashboardRepository repository =
        _FakeAdminDashboardRepository();
    final _Harness harness = await pumpDashboard(
      tester,
      dashboardRepository: repository,
    );

    await _openLogoutDialog(tester);

    expect(find.text(AppStrings.adminLogoutDialogTitle), findsOneWidget);
    expect(harness.auth.signOutCalls, 0);

    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminLogoutDialogTitle), findsNothing);
    expect(harness.auth.signOutCalls, 0);
    expect(harness.router.state.uri.path, AppRoutes.admin);
  });

  testWidgets('Konfirmasi keluar memanggil sign-out dan kembali ke login', (
    WidgetTester tester,
  ) async {
    final _FakeAdminDashboardRepository repository =
        _FakeAdminDashboardRepository();
    final _Harness harness = await pumpDashboard(
      tester,
      dashboardRepository: repository,
    );

    await _openLogoutDialog(tester);
    await tester.tap(_dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(harness.auth.signOutCalls, 1);
    expect(harness.router.state.uri.path, AppRoutes.login);
    expect(find.text(AppStrings.loginWelcomeTitle), findsOneWidget);
    expect(find.text(AppStrings.adminDashboardTitle), findsNothing);
  });

  testWidgets(
    'Kegagalan sign-out menampilkan pesan ramah dan tetap di dashboard',
    (WidgetTester tester) async {
      final _FakeAdminDashboardRepository repository =
          _FakeAdminDashboardRepository();
      final _FakeAuthRepository auth = _FakeAuthRepository()
        ..signOutFailure = const AuthFailure(AppStrings.adminLogoutError);
      final _Harness harness = await pumpDashboard(
        tester,
        dashboardRepository: repository,
        authRepository: auth,
      );

      await _openLogoutDialog(tester);
      await tester.tap(_dialogConfirmButton());
      await tester.pumpAndSettle();

      expect(harness.auth.signOutCalls, 1);
      expect(find.text(AppStrings.adminLogoutError), findsOneWidget);
      expect(harness.router.state.uri.path, AppRoutes.admin);
      expect(find.text(AppStrings.adminDashboardTitle), findsOneWidget);
    },
  );

  final List<Size> responsiveSizes = <Size>[
    const Size(360, 800),
    const Size(800, 1280),
    const Size(1280, 800),
  ];

  for (final Size size in responsiveSizes) {
    testWidgets(
      'Dashboard muat pada ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        final _FakeAdminDashboardRepository repository =
            _FakeAdminDashboardRepository();

        await pumpDashboard(
          tester,
          dashboardRepository: repository,
          viewSize: size,
          theme: size.width >= 600 ? AppTheme.dark : AppTheme.light,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.adminDashboardTitle), findsOneWidget);
        expect(find.text(AppStrings.adminStatBooksLabel), findsOneWidget);
        expect(
          find.text(AppStrings.adminStatUnhandledIsbnLogsLabel),
          findsOneWidget,
        );
        expect(find.text(AppStrings.adminMenuLogout), findsOneWidget);
      },
    );
  }
}

Future<void> _openLogoutDialog(WidgetTester tester) async {
  final Finder logout = find.text(AppStrings.adminMenuLogout);
  await tester.ensureVisible(logout);
  await tester.pumpAndSettle();
  await tester.tap(logout);
  await tester.pumpAndSettle();
}

Finder _dialogConfirmButton() {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(AppStrings.adminLogoutConfirm),
  );
}

const AppUser _adminUser = AppUser(
  uid: 'admin-1',
  displayName: 'Admin Libria',
  email: 'admin@libria.id',
  role: AppUser.roleAdmin,
);

class _Harness {
  const _Harness({required this.router, required this.auth});

  final GoRouter router;
  final _FakeAuthRepository auth;
}

class _DashboardTestApp extends ConsumerWidget {
  const _DashboardTestApp({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(theme: theme, routerConfig: router);
  }
}

class _FakeAdminDashboardRepository implements AdminDashboardRepository {
  AdminDashboardStats stats = const AdminDashboardStats(
    totalBooks: 12,
    openReports: 3,
    unhandledIsbnLogs: 5,
    totalUsers: 40,
  );

  Completer<AdminDashboardStats>? completer;
  int failuresRemaining = 0;
  int fetchCalls = 0;

  @override
  Future<AdminDashboardStats> fetchStats() async {
    fetchCalls++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const _DashboardTestFailure();
    }
    if (completer != null) {
      return completer!.future;
    }
    return stats;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  final StreamController<User?> _authState = StreamController<User?>();

  _FakeAuthRepository() {
    _authState.add(_FakeUser());
  }

  AuthFailure? signOutFailure;
  int signOutCalls = 0;

  @override
  User? currentUser = _FakeUser();

  @override
  Stream<User?> get authStateChanges => _authState.stream;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutFailure != null) {
      throw signOutFailure!;
    }
    currentUser = null;
    _authState.add(null);
  }

  Future<void> dispose() => _authState.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DashboardTestFailure implements Exception {
  const _DashboardTestFailure();
}
