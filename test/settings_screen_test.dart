import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_info.dart';
import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/settings/data/settings_repository.dart';
import 'package:libria/features/settings/data/theme_preference.dart';
import 'package:libria/features/settings/presentation/settings_providers.dart';
import 'package:libria/features/settings/presentation/settings_screen.dart';

const AppUser _user = AppUser(
  uid: 'u1',
  displayName: 'Pembaca Libria',
  email: 'pembaca@libria.id',
  role: AppUser.roleUser,
);

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  Future<_Harness> pumpSettings(
    WidgetTester tester, {
    AppUser? user = _user,
    Stream<AppUser?> Function()? userStream,
    ThemePreference initialTheme = ThemePreference.system,
    _FakeSettingsRepository? settingsRepository,
    _FakeAuthRepository? authRepository,
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

    final _FakeSettingsRepository settings =
        settingsRepository ??
        _FakeSettingsRepository(initialTheme: initialTheme);
    final _FakeAuthRepository auth = authRepository ?? _FakeAuthRepository();
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.homeSettings,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.homeSettings,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.journal,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('journal-marker')),
        ),
        GoRoute(
          path: AppRoutes.report,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('report-marker')),
        ),
      ],
    );
    addTearDown(router.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWith((Ref ref) => settings),
        authRepositoryProvider.overrideWith((Ref ref) => auth),
        currentUserProvider.overrideWith(
          (Ref ref) => (userStream ?? () => Stream<AppUser?>.value(user))(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
          builder: (BuildContext context, Widget? child) {
            final MediaQueryData media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(textScale)),
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
    }

    return _Harness(
      router: router,
      container: container,
      settings: settings,
      auth: auth,
    );
  }

  testWidgets('Menampilkan profil, pilihan tampilan, pintasan, versi, Keluar', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text(_user.displayName), findsOneWidget);
    expect(find.text(_user.email), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
    expect(find.text(AppStrings.settingsDisplaySectionTitle), findsOneWidget);
    expect(find.text(AppStrings.settingsThemeSystem), findsOneWidget);
    expect(find.text(AppStrings.settingsThemeLight), findsOneWidget);
    expect(find.text(AppStrings.settingsThemeDark), findsOneWidget);
    expect(find.text(AppStrings.settingsJournalTitle), findsOneWidget);
    expect(find.text(AppStrings.settingsReportTitle), findsOneWidget);
    expect(find.text(AppStrings.settingsAboutTitle), findsOneWidget);
    expect(
      find.text(AppStrings.settingsAboutVersion(AppInfo.version)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-logout')),
      findsOneWidget,
    );

    final RadioGroup<ThemePreference> group = tester
        .widget<RadioGroup<ThemePreference>>(
          find.byType(RadioGroup<ThemePreference>),
        );
    expect(group.groupValue, ThemePreference.system);
  });

  testWidgets('Pilihan tampilan tersimpan ditampilkan sebagai pilihan aktif', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester, initialTheme: ThemePreference.dark);

    final RadioGroup<ThemePreference> group = tester
        .widget<RadioGroup<ThemePreference>>(
          find.byType(RadioGroup<ThemePreference>),
        );
    expect(group.groupValue, ThemePreference.dark);
  });

  testWidgets('Memilih tema langsung berlaku dan disimpan', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSettings(tester);

    await tester.tap(find.text(AppStrings.settingsThemeDark));
    await tester.pumpAndSettle();

    expect(
      harness.container.read(themePreferenceProvider).value,
      ThemePreference.dark,
    );
    expect(harness.settings.saved, <ThemePreference>[ThemePreference.dark]);

    await tester.tap(find.text(AppStrings.settingsThemeLight));
    await tester.pumpAndSettle();

    expect(
      harness.container.read(themePreferenceProvider).value,
      ThemePreference.light,
    );
    expect(harness.settings.saved, <ThemePreference>[
      ThemePreference.dark,
      ThemePreference.light,
    ]);
  });

  testWidgets('Kegagalan menyimpan tema menampilkan pesan dan mengembalikan', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository settings = _FakeSettingsRepository(
      failSave: true,
    );
    final _Harness harness = await pumpSettings(
      tester,
      settingsRepository: settings,
    );

    await tester.tap(find.text(AppStrings.settingsThemeDark));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsThemeSaveError), findsOneWidget);
    expect(
      harness.container.read(themePreferenceProvider).value,
      ThemePreference.system,
    );
    final RadioGroup<ThemePreference> group = tester
        .widget<RadioGroup<ThemePreference>>(
          find.byType(RadioGroup<ThemePreference>),
        );
    expect(group.groupValue, ThemePreference.system);
  });

  testWidgets('Profil menampilkan keadaan memuat lalu data', (
    WidgetTester tester,
  ) async {
    final StreamController<AppUser?> controller = StreamController<AppUser?>();
    addTearDown(controller.close);

    await pumpSettings(
      tester,
      userStream: () => controller.stream,
      settle: false,
    );

    expect(find.text(AppStrings.settingsProfileLoading), findsOneWidget);
    expect(find.text(_user.displayName), findsNothing);

    controller.add(_user);
    await tester.pumpAndSettle();

    expect(find.text(_user.displayName), findsOneWidget);
    expect(find.text(AppStrings.settingsProfileLoading), findsNothing);
  });

  testWidgets('Galat profil menampilkan pesan ramah dan tombol Coba Lagi', (
    WidgetTester tester,
  ) async {
    await pumpSettings(
      tester,
      userStream: () => Stream<AppUser?>.error(Exception('uji')),
    );

    expect(find.text(AppStrings.settingsProfileLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.settingsProfileEmptyTitle), findsNothing);
  });

  testWidgets('Profil kosong menampilkan keadaan kosong', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester, user: null);

    expect(find.text(AppStrings.settingsProfileEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.settingsProfileEmptyMessage), findsOneWidget);
  });

  testWidgets('Pintasan Jurnal membuka layar jurnal', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSettings(tester);

    await tester.tap(find.text(AppStrings.settingsJournalTitle));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.journal);
    expect(find.text('journal-marker'), findsOneWidget);
  });

  testWidgets('Pintasan Laporan membuka layar laporan', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSettings(tester);

    await tapVisible(tester, find.text(AppStrings.settingsReportTitle));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.report);
    expect(find.text('report-marker'), findsOneWidget);
  });

  testWidgets('Keluar menampilkan konfirmasi dan bisa dibatalkan', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSettings(tester);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('settings-logout')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsLogoutDialogTitle), findsOneWidget);
    expect(find.text(AppStrings.settingsLogoutDialogMessage), findsOneWidget);

    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsLogoutDialogTitle), findsNothing);
    expect(harness.auth.signOutCalls, 0);
  });

  testWidgets('Keluar yang dikonfirmasi memanggil repository auth', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSettings(tester);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('settings-logout')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.settingsLogoutConfirm));
    await tester.pumpAndSettle();

    expect(harness.auth.signOutCalls, 1);
    expect(find.text(AppStrings.settingsLogoutError), findsNothing);
  });

  testWidgets('Kegagalan Keluar menampilkan pesan dan tombol aktif lagi', (
    WidgetTester tester,
  ) async {
    final _FakeAuthRepository auth = _FakeAuthRepository()
      ..signOutFailure = const AuthFailure('Gagal keluar dari akun uji.');
    final _Harness harness = await pumpSettings(tester, authRepository: auth);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('settings-logout')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.settingsLogoutConfirm));
    await tester.pumpAndSettle();

    expect(harness.auth.signOutCalls, 1);
    expect(find.text('Gagal keluar dari akun uji.'), findsOneWidget);

    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('settings-logout')),
    );
    expect(button.onPressed, isNotNull);
  });

  for (final _LayoutCase layout in <_LayoutCase>[
    _LayoutCase(const Size(360, 800), AppTheme.light),
    _LayoutCase(const Size(360, 800), AppTheme.light, textScale: 1.5),
    _LayoutCase(const Size(800, 1280), AppTheme.dark),
    _LayoutCase(const Size(1280, 800), AppTheme.dark, textScale: 1.5),
  ]) {
    testWidgets(
      'Tata letak ${layout.size.width.toInt()}x${layout.size.height.toInt()} '
      'skala ${layout.textScale} tanpa galat',
      (WidgetTester tester) async {
        await pumpSettings(
          tester,
          viewSize: layout.size,
          theme: layout.theme,
          textScale: layout.textScale,
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey<String>('settings-logout')),
          findsOneWidget,
        );
        expect(find.text(AppStrings.settingsThemeSystem), findsOneWidget);
      },
    );
  }
}

class _Harness {
  const _Harness({
    required this.router,
    required this.container,
    required this.settings,
    required this.auth,
  });

  final GoRouter router;
  final ProviderContainer container;
  final _FakeSettingsRepository settings;
  final _FakeAuthRepository auth;
}

class _LayoutCase {
  const _LayoutCase(this.size, this.theme, {this.textScale = 1});

  final Size size;
  final ThemeData theme;
  final double textScale;
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    this.initialTheme = ThemePreference.system,
    this.failSave = false,
  });

  final ThemePreference initialTheme;
  final bool failSave;
  final List<ThemePreference> saved = <ThemePreference>[];

  @override
  Future<ThemePreference> loadThemePreference() async => initialTheme;

  @override
  Future<void> saveThemePreference(ThemePreference preference) async {
    if (failSave) {
      throw const SettingsFailure(AppStrings.settingsThemeSaveError);
    }
    saved.add(preference);
  }
}

class _FakeAuthRepository implements AuthRepository {
  AuthFailure? signOutFailure;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final AuthFailure? failure = signOutFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
