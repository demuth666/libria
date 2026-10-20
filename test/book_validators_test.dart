import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/books/data/book_validators.dart';

void main() {
  group('BookValidators.isValidIsbn', () {
    test('menerima ISBN-10 dan ISBN-13 setelah dinormalisasi', () {
      expect(BookValidators.isValidIsbn('0-8044-2957-x'), isTrue);
      expect(BookValidators.isValidIsbn('080442957X'), isTrue);
      expect(BookValidators.isValidIsbn('978-979-973-123-4'), isTrue);
      expect(BookValidators.isValidIsbn(' 978 979 973 1234 '), isTrue);
    });

    test('menolak panjang dan karakter yang tidak sesuai', () {
      expect(BookValidators.isValidIsbn(''), isFalse);
      expect(BookValidators.isValidIsbn('12345'), isFalse);
      expect(BookValidators.isValidIsbn('123456789'), isFalse);
      expect(BookValidators.isValidIsbn('12345678901'), isFalse);
      expect(BookValidators.isValidIsbn('978-979-973-123-X'), isFalse);
      expect(BookValidators.isValidIsbn('08044295AX'), isFalse);
    });
  });

  group('BookValidators.isValidYear', () {
    test('menerima tahun kosong atau angka', () {
      expect(BookValidators.isValidYear(''), isTrue);
      expect(BookValidators.isValidYear(' 1980 '), isTrue);
    });

    test('menolak tahun bukan angka', () {
      expect(BookValidators.isValidYear('dua ribu'), isFalse);
      expect(BookValidators.isValidYear('1980 M'), isFalse);
      expect(BookValidators.isValidYear('-1980'), isFalse);
      expect(BookValidators.isValidYear('99999999999999999999999'), isFalse);
    });
  });

  group('BookValidators.isPositiveInteger', () {
    test('menerima bilangan bulat lebih dari 0', () {
      expect(BookValidators.isPositiveInteger('1'), isTrue);
      expect(BookValidators.isPositiveInteger(' 535 '), isTrue);
    });

    test('menolak nol, negatif, pecahan, dan bukan angka', () {
      expect(BookValidators.isPositiveInteger(''), isFalse);
      expect(BookValidators.isPositiveInteger('0'), isFalse);
      expect(BookValidators.isPositiveInteger('-3'), isFalse);
      expect(BookValidators.isPositiveInteger('12.5'), isFalse);
      expect(BookValidators.isPositiveInteger('banyak'), isFalse);
    });
  });
}
