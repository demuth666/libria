import 'package:flutter_test/flutter_test.dart';

import 'package:libria/app.dart';
import 'package:libria/core/constants/app_strings.dart';

void main() {
  testWidgets('App shows the placeholder screen with the app name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LibriaApp());

    expect(find.text(AppStrings.appName), findsOneWidget);
  });
}
