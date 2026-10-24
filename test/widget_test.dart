import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria/app.dart';
import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_colors.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/settings/data/settings_repository.dart';
import 'package:libria/features/settings/data/theme_preference.dart';
import 'package:libria/features/settings/presentation/settings_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('App menampilkan Splash lalu pindah ke Login tanpa pengguna', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump();

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.splashQuote), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginWelcomeTitle), findsOneWidget);
  });

  testWidgets('MaterialApp memakai tema terang dan gelap dari token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);

    expect(app.theme?.colorScheme.primary, AppColors.lightScheme.primary);
    expect(app.darkTheme?.colorScheme.surface, AppColors.darkScheme.surface);

    expect(app.theme?.textTheme.headlineMedium?.fontFamily, 'Merriweather');
    expect(app.theme?.textTheme.bodyMedium?.fontFamily, 'Plus Jakarta Sans');

    expect(app.theme?.extension<AppSemanticColors>(), isNotNull);
    expect(app.darkTheme?.extension<AppSemanticColors>(), isNotNull);
  });

  testWidgets('Pilihan tampilan tersimpan dipakai saat aplikasi dibuka', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsRepository.themePreferenceKey: 'dark',
    });

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('Perubahan tampilan langsung dipakai MaterialApp', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(true),
        ),
        authStateProvider.overrideWith((Ref ref) => Stream<User?>.value(null)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LibriaApp()),
    );
    await tester.pumpAndSettle();
    await container.read(themePreferenceProvider.future);

    await container
        .read(themePreferenceProvider.notifier)
        .select(ThemePreference.dark);
    await tester.pump();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}

/// [LibriaApp] siap uji dengan status koneksi tetap online supaya uji tidak
/// memanggil plugin `connectivity_plus` pada perangkat uji, dan status auth
/// tetap tanpa pengguna supaya Splash tidak memanggil Firebase.
Widget _testApp() {
  return ProviderScope(
    overrides: [
      connectivityProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
      authStateProvider.overrideWith((Ref ref) => Stream<User?>.value(null)),
    ],
    child: const LibriaApp(),
  );
}
