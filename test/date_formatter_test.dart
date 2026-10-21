import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/utils/date_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  test('memformat tanggal dan waktu dengan locale id_ID', () {
    expect(
      AppDateFormatter.dateTime(DateTime(2026, 10, 21, 14, 5)),
      '21 Oktober 2026, 14.05',
    );
  });

  test('memakai dua digit untuk jam dan menit', () {
    expect(
      AppDateFormatter.dateTime(DateTime(2026, 1, 2, 3, 4)),
      '2 Januari 2026, 03.04',
    );
  });
}
