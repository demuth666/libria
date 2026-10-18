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

  group('BookRepository.searchByIsbnPrefix', () {
    test('awalan kosong setelah normalisasi tidak membaca koleksi', () async {
      final BookRepository repository = BookRepository(
        firestore: _UnusedFirestore(),
      );

      final BookPage page = await repository.searchByIsbnPrefix(' - ');

      expect(page.books, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('awalan dinormalisasi sebelum membentuk rentang query', () async {
      final _CapturingFirestore firestore = _CapturingFirestore();
      final BookRepository repository = BookRepository(firestore: firestore);

      await repository.searchByIsbnPrefix(' 978-979 973-x ');

      expect(firestore.books.whereCalls, hasLength(2));
      final ({Object field, Map<Symbol, Object?> arguments}) first =
          firestore.books.whereCalls.first;
      expect(first.field, 'isbn');
      expect(first.arguments[#isGreaterThanOrEqualTo], '978979973X');
      expect(
        firestore.books.whereCalls.last.arguments[#isLessThan],
        '978979973X\uf8ff',
      );
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

/// Firestore palsu yang tidak boleh disentuh pada uji jalur normalisasi ISBN.
class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Firestore palsu yang merekam panggilan `where` untuk memeriksa nilai
/// rentang query tanpa koneksi Firestore.
class _CapturingFirestore implements FirebaseFirestore {
  final _CapturingCollection books = _CapturingCollection();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #collection) {
      return books;
    }
    return super.noSuchMethod(invocation);
  }
}

// `Query` milik Firestore bersifat sealed, sehingga fake tanpa emulator hanya
// bisa dibuat dengan mengimplementasikan antarmukanya. Hanya dipakai di uji.
// ignore: subtype_of_sealed_class
class _CapturingCollection
    implements CollectionReference<Map<String, dynamic>> {
  final List<({Object field, Map<Symbol, Object?> arguments})> whereCalls =
      <({Object field, Map<Symbol, Object?> arguments})>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #where:
        whereCalls.add((
          field: invocation.positionalArguments.first as Object,
          arguments: invocation.namedArguments,
        ));
        return this;
      case #orderBy:
      case #limit:
      case #startAfterDocument:
        return this;
      case #get:
        return Future<QuerySnapshot<Map<String, dynamic>>>.value(
          _EmptyQuerySnapshot(),
        );
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

class _EmptyQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
