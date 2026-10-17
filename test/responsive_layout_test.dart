import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/responsive/breakpoints.dart';
import 'package:libria/core/responsive/content_width.dart';
import 'package:libria/core/router/placeholder_screen.dart';
import 'package:libria/core/theme/app_theme.dart';

void main() {
  Future<ScreenSize> resolveScreenSize(
    WidgetTester tester,
    double width,
  ) async {
    late ScreenSize result;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (BuildContext context) {
              result = Breakpoints.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets('Breakpoints memetakan lebar ke kategori Material 3', (
    WidgetTester tester,
  ) async {
    expect(await resolveScreenSize(tester, 599), ScreenSize.compact);
    expect(await resolveScreenSize(tester, 600), ScreenSize.medium);
    expect(await resolveScreenSize(tester, 839), ScreenSize.medium);
    expect(await resolveScreenSize(tester, 840), ScreenSize.expanded);
  });

  testWidgets('ContentWidth membatasi dan memusatkan isi di layar lebar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final Key contentKey = UniqueKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentWidth(
            child: SizedBox(
              key: contentKey,
              width: double.infinity,
              height: 24,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(contentKey)).width, 640);
    expect(tester.getCenter(find.byKey(contentKey)).dx, 640);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();

    expect(tester.getSize(find.byKey(contentKey)).width, 360);
  });

  final List<Size> responsiveSizes = <Size>[
    const Size(360, 800),
    const Size(800, 1280),
    const Size(1280, 800),
  ];

  for (final Size size in responsiveSizes) {
    testWidgets(
      'Layar placeholder muat pada ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: size.width >= 600 ? AppTheme.dark : AppTheme.light,
            home: const RoutePlaceholderScreen(
              title: AppStrings.bookDetailTitle,
              detail: 'b1',
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppStrings.routeNotBuiltYet(AppStrings.bookDetailTitle)),
          findsOneWidget,
        );
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      },
    );
  }
}
