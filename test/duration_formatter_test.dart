import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/utils/duration_formatter.dart';

void main() {
  group('AppDurationFormatter.timer', () {
    test('memakai dua digit untuk jam, menit, dan detik', () {
      expect(
        AppDurationFormatter.timer(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '01:02:03',
      );
      expect(AppDurationFormatter.timer(Duration.zero), '00:00:00');
    });

    test('jam tidak dipotong untuk sesi sangat panjang', () {
      expect(
        AppDurationFormatter.timer(
          const Duration(hours: 100, minutes: 2, seconds: 3),
        ),
        '100:02:03',
      );
    });

    test('durasi negatif dianggap nol', () {
      expect(
        AppDurationFormatter.timer(const Duration(seconds: -5)),
        '00:00:00',
      );
    });
  });
}
