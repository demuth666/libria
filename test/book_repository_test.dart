import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';

Book sampleBook({
  String title = 'Bumi Manusia',
  String author = 'Pramoedya Ananta Toer',
}) {
  return Book(
    id: 'book-1',
    title: title,
    author: author,
    isbn: '978-979-973-123-4',
    publisher: 'Lentera Dipantara',
    year: 1980,
    totalPages: 535,
    category: 'Fiksi',
    synopsis: 'Kisah Minke dan perjalanan hidupnya.',
    coverUrl: 'https://contoh.com/bumi-manusia.jpg',
    ratingAverage: 4.7,
    ratingCount: 120,
    createdBy: 'admin-1',
  );
}

void main() {
  group('BookRepository.normalizeIsbn', () {
    test('membuang spasi dan tanda hubung', () {
      expect(
        BookRepository.normalizeIsbn('978-979-973-123-4'),
        '9789799731234',
      );
      expect(
        BookRepository.normalizeIsbn(' 978 979 973 1234 '),
        '9789799731234',
      );
      expect(
        BookRepository.normalizeIsbn('978 - 979 - 973 - 123 - 4'),
        '9789799731234',
      );
    });

    test('menyeragamkan huruf X pada ISBN-10 menjadi huruf besar', () {
      expect(BookRepository.normalizeIsbn('0-8044-2957-x'), '080442957X');
      expect(BookRepository.normalizeIsbn('080442957x'), '080442957X');
    });

    test('nilai yang sudah normal tidak berubah', () {
      expect(BookRepository.normalizeIsbn('9789799731234'), '9789799731234');
      expect(BookRepository.normalizeIsbn(''), '');
    });
  });

  group('BookRepository.buildCreateMap', () {
    test('menyimpan seluruh field, field turunan, dan timestamp server', () {
      final Map<String, dynamic> map = BookRepository.buildCreateMap(
        sampleBook(),
      );

      expect(map['title'], 'Bumi Manusia');
      expect(map['author'], 'Pramoedya Ananta Toer');
      expect(map['isbn'], '9789799731234');
      expect(map['publisher'], 'Lentera Dipantara');
      expect(map['year'], 1980);
      expect(map['totalPages'], 535);
      expect(map['category'], 'Fiksi');
      expect(map['synopsis'], 'Kisah Minke dan perjalanan hidupnya.');
      expect(map['coverUrl'], 'https://contoh.com/bumi-manusia.jpg');
      expect(map['ratingAverage'], 4.7);
      expect(map['ratingCount'], 120);
      expect(map['createdBy'], 'admin-1');
      expect(map['titleLower'], 'bumi manusia');
      expect(map['authorLower'], 'pramoedya ananta toer');
      expect(map['createdAt'], isA<FieldValue>());
      expect(map['updatedAt'], isA<FieldValue>());
      expect(map.containsKey('id'), isFalse);
    });

    test('field turunan di-trim agar cocok dengan input pencarian', () {
      final Map<String, dynamic> map = BookRepository.buildCreateMap(
        sampleBook(
          title: '  Bumi Manusia  ',
          author: '  Pramoedya Ananta Toer  ',
        ),
      );

      expect(map['titleLower'], 'bumi manusia');
      expect(map['authorLower'], 'pramoedya ananta toer');
    });
  });

  group('BookRepository.buildUpdateMap', () {
    test('memperbarui field isi tanpa menghapus rating atau pembuat', () {
      final Map<String, dynamic> map = BookRepository.buildUpdateMap(
        sampleBook(),
      );

      expect(map['title'], 'Bumi Manusia');
      expect(map['author'], 'Pramoedya Ananta Toer');
      expect(map['isbn'], '9789799731234');
      expect(map['publisher'], 'Lentera Dipantara');
      expect(map['year'], 1980);
      expect(map['totalPages'], 535);
      expect(map['category'], 'Fiksi');
      expect(map['synopsis'], 'Kisah Minke dan perjalanan hidupnya.');
      expect(map['coverUrl'], 'https://contoh.com/bumi-manusia.jpg');
      expect(map['titleLower'], 'bumi manusia');
      expect(map['authorLower'], 'pramoedya ananta toer');
      expect(map['updatedAt'], isA<FieldValue>());
      expect(map.containsKey('ratingAverage'), isFalse);
      expect(map.containsKey('ratingCount'), isFalse);
      expect(map.containsKey('createdBy'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('id'), isFalse);
    });
  });
}
