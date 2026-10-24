import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libria/core/theme/app_text_styles.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';

const List<AppBottomNavDestination> _destinations = <AppBottomNavDestination>[
  AppBottomNavDestination(icon: Icons.dashboard_outlined, label: 'Dasar'),
  AppBottomNavDestination(icon: Icons.menu_book_outlined, label: 'Buku'),
  AppBottomNavDestination(icon: Icons.qr_code_scanner, label: 'ISBN'),
  AppBottomNavDestination(icon: Icons.flag_outlined, label: 'Laporan'),
  AppBottomNavDestination(icon: Icons.event_outlined, label: 'Kegiatan'),
  AppBottomNavDestination(
    icon: Icons.emoji_events_outlined,
    label: 'Tantangan',
  ),
];

Future<void> _pumpNavBar(
  WidgetTester tester, {
  required double textScale,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (BuildContext context) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: AppBottomNavBar(
                destinations: _destinations,
                selectedIndex: 1,
                onDestinationSelected: (_) {},
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('label navbar mengikuti skala font sistem', (
    WidgetTester tester,
  ) async {
    const double textScale = 1.3;
    await _pumpNavBar(tester, textScale: textScale);

    final double expectedLabelHeight =
        TextScaler.linear(textScale).scale(AppTextStyles.navLabel.fontSize!) *
        AppTextStyles.navLabel.height!;

    for (final AppBottomNavDestination destination in _destinations) {
      final Finder labelFinder = find.text(destination.label);
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        labelFinder,
      );
      expect(
        paragraph.size.height,
        moreOrLessEquals(expectedLabelHeight, epsilon: 0.5),
        reason: 'Tinggi label ${destination.label} harus ikut skala font',
      );

      final Finder itemFinder = find.ancestor(
        of: labelFinder,
        matching: find.byType(AnimatedContainer),
      );
      expect(
        tester.getRect(labelFinder).bottom,
        lessThanOrEqualTo(tester.getRect(itemFinder).bottom),
        reason: 'Label ${destination.label} tidak boleh keluar dari item',
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('item dan bilah navbar tumbuh saat font sangat besar', (
    WidgetTester tester,
  ) async {
    await _pumpNavBar(tester, textScale: 2);

    final Finder itemFinder = find
        .ancestor(
          of: find.text('Buku'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    expect(
      tester.getSize(itemFinder).height,
      greaterThan(AppBottomNavBar.itemHeight),
    );
    expect(
      tester.getSize(find.byType(AppBottomNavBar)).height,
      greaterThan(AppBottomNavBar.height),
    );
    expect(tester.takeException(), isNull);
  });
}
