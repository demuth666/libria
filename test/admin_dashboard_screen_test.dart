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
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';
import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_isbn_log_repository.dart';

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
        bookRepositoryProvider.overrideWith((Ref ref) => FakeBookRepository()),
        isbnLogRepositoryProvider.overrideWith(
          (Ref ref) => FakeIsbnLogRepository(),
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

  testWidgets('Bottom navigation membuka tiap layar admin dan tetap tampil', (
    WidgetTester tester,
  ) async {
    final _FakeAdminDashboardRepository repository =
        _FakeAdminDashboardRepository();
    final _Harness harness = await pumpDashboard(
      tester,
      dashboardRepository: repository,
    );

    final AppBottomNavBar navigationBar = tester.widget<AppBottomNavBar>(
      find.byType(AppBottomNavBar),
    );
    expect(navigationBar.destinations.length, 6);
    expect(find.byTooltip(AppStrings.adminLogoutLabel), findsOneWidget);

    final List<(String, String, String)> destinations =
        <(String, String, String)>[
          (
            AppStrings.adminNavBooks,
            AppStrings.adminBooksTitle,
            AppRoutes.adminBooks,
          ),
          (
            AppStrings.adminNavIsbnLogs,
            AppStrings.adminIsbnLogsTitle,
            AppRoutes.adminIsbnLogs,
          ),
          (
            AppStrings.adminNavReports,
            AppStrings.adminReportsTitle,
            AppRoutes.adminReports,
          ),
          (
            AppStrings.adminNavEvents,
            AppStrings.adminEventsTitle,
            AppRoutes.adminEvents,
          ),
          (
            AppStrings.adminNavChallenges,
            AppStrings.adminChallengesTitle,
            AppRoutes.adminChallenges,
          ),
        ];

    for (final (String label, String title, String path) in destinations) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, path, reason: label);
      final String expectedBody = switch (path) {
        AppRoutes.adminBooks => AppStrings.adminBooksSearchLabel,
        AppRoutes.adminIsbnLogs => AppStrings.adminIsbnLogsEmptyTitle,
        _ => AppStrings.routeNotBuiltYet(title),
      };
      expect(find.text(expectedBody), findsOneWidget, reason: label);
      expect(find.byType(AppBottomNavBar), findsOneWidget);
      expect(find.byTooltip(AppStrings.adminLogoutLabel), findsOneWidget);

      await tester.tap(find.text(AppStrings.adminNavDashboard));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, AppRoutes.admin);
    }
  });

  testWidgets('Ikon bilah navigasi admin sejajar dan semua label tampil', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      dashboardRepository: _FakeAdminDashboardRepository(),
    );

    final Finder icons = find.descendant(
      of: find.byType(AppBottomNavBar),
      matching: find.byType(Icon),
    );
    expect(icons, findsNWidgets(6));

    final double firstIconCenterY = tester.getCenter(icons.at(0)).dy;
    for (int index = 1; index < 6; index++) {
      expect(
        tester.getCenter(icons.at(index)).dy,
        closeTo(firstIconCenterY, 0.01),
      );
    }

    final List<Text> labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AppBottomNavBar),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(labels, hasLength(6));
    expect(
      labels.map((Text label) => label.style?.fontSize).toSet(),
      hasLength(1),
    );

    for (final String label in <String>[
      AppStrings.adminNavDashboard,
      AppStrings.adminNavBooks,
      AppStrings.adminNavIsbnLogs,
      AppStrings.adminNavReports,
      AppStrings.adminNavEvents,
      AppStrings.adminNavChallenges,
    ]) {
      expect(find.text(label), findsOneWidget);
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
        expect(find.byType(AppBottomNavBar), findsOneWidget);
        expect(find.byTooltip(AppStrings.adminLogoutLabel), findsOneWidget);
      },
    );
  }
}

Future<void> _openLogoutDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip(AppStrings.adminLogoutLabel));
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
