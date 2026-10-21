import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/utils/isbn.dart';

void main() {
  group('Isbn.normalize', () {
    test('membuang spasi dan tanda hubung', () {
      expect(Isbn.normalize('978-979-973-123-4'), '9789799731234');
      expect(Isbn.normalize(' 978 979 973 1234 '), '9789799731234');
      expect(Isbn.normalize('978 - 979 - 973 - 123 - 4'), '9789799731234');
    });

    test('menyeragamkan huruf x pada ISBN-10 menjadi huruf besar', () {
      expect(Isbn.normalize('0-8044-2957-x'), '080442957X');
      expect(Isbn.normalize('080442957x'), '080442957X');
      expect(Isbn.normalize('080442957X'), '080442957X');
    });

    test('nilai yang sudah normal tidak berubah', () {
      expect(Isbn.normalize('9789799731234'), '9789799731234');
    });

    test('string kosong tetap kosong', () {
      expect(Isbn.normalize(''), '');
      expect(Isbn.normalize('   '), '');
      expect(Isbn.normalize(' - '), '');
    });
  });
}
