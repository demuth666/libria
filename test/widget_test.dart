import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/app.dart';
import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_colors.dart';

void main() {
  testWidgets('App shows the placeholder screen with the app name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LibriaApp());

    expect(find.text(AppStrings.appName), findsOneWidget);
  });

  testWidgets('MaterialApp memakai tema terang dan gelap dari token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LibriaApp());

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
}
