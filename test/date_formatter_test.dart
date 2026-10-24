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

  group('AppDateFormatter.relativeTime', () {
    final DateTime now = DateTime(2026, 10, 24, 12);

    test('waktu dalam satu menit memakai "Baru saja"', () {
      expect(
        AppDateFormatter.relativeTime(
          now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        'Baru saja',
      );
    });

    test('waktu beberapa menit dan jam memakai satuan yang sesuai', () {
      expect(
        AppDateFormatter.relativeTime(
          now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        '5 menit lalu',
      );
      expect(
        AppDateFormatter.relativeTime(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        '2 jam lalu',
      );
    });

    test('hari sebelumnya dan beberapa hari memakai label hari', () {
      expect(
        AppDateFormatter.relativeTime(DateTime(2026, 10, 23, 20), now: now),
        'Kemarin',
      );
      expect(
        AppDateFormatter.relativeTime(DateTime(2026, 10, 21, 8), now: now),
        '3 hari lalu',
      );
    });

    test('tanggal lama memakai tanggal singkat atau lengkap', () {
      expect(
        AppDateFormatter.relativeTime(DateTime(2026, 10, 1, 8), now: now),
        '1 Okt',
      );
      expect(
        AppDateFormatter.relativeTime(DateTime(2025, 10, 1, 8), now: now),
        '1 Oktober 2025',
      );
    });
  });
}
