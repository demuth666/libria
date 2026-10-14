import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_router.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer();
    router = container.read(routerProvider);
  });

  tearDown(() => container.dispose());

  Future<void> pumpAt(WidgetTester tester, String location) async {
    // Shell navigasi bawah membaca `AppSemanticColors` dari tema, jadi uji
    // ini perlu memakai `AppTheme.light` dan bukan `ThemeData()` bawaan.
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    router.go(location);
    await tester.pumpAndSettle();
  }

  final List<String> allRoutes = <String>[
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
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
    AppRoutes.admin,
    AppRoutes.adminBooks,
    AppRoutes.adminBookNew,
    AppRoutes.adminBookEditPath('b1'),
    AppRoutes.adminIsbnLogs,
    AppRoutes.adminReports,
    AppRoutes.adminEvents,
    AppRoutes.adminChallenges,
  ];

  for (final String location in allRoutes) {
    testWidgets('Rute $location bisa dibuka dari kode tanpa galat', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, location);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Navigasi bawah berpindah tab di dalam shell user', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, AppRoutes.home);
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
    await pumpAt(tester, AppRoutes.home);

    await tester.tap(find.byTooltip(AppStrings.sessionNavLabel));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionSetupTitle), findsOneWidget);
  });
}
