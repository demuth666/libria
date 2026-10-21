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

  group('BookRepository.search', () {
    test('memilih field sesuai cakupan pencarian', () async {
      final _CapturingFirestore titleFirestore = _CapturingFirestore();
      await BookRepository(firestore: titleFirestore)
          .search('  Bumi  ', scope: BookSearchScope.title);
      expect(titleFirestore.books.whereCalls.first.field, 'titleLower');
      expect(
        titleFirestore
            .books
            .whereCalls
            .first
            .arguments[#isGreaterThanOrEqualTo],
        'bumi',
      );

      final _CapturingFirestore authorFirestore = _CapturingFirestore();
      await BookRepository(firestore: authorFirestore)
          .search('Pram', scope: BookSearchScope.author);
      expect(authorFirestore.books.whereCalls.first.field, 'authorLower');
      expect(
        authorFirestore
            .books
            .whereCalls
            .first
            .arguments[#isGreaterThanOrEqualTo],
        'pram',
      );

      final _CapturingFirestore isbnFirestore = _CapturingFirestore();
      await BookRepository(firestore: isbnFirestore)
          .search(' 978-979 ', scope: BookSearchScope.isbn);
      expect(isbnFirestore.books.whereCalls.first.field, 'isbn');
      expect(
        isbnFirestore.books.whereCalls.first.arguments[#isGreaterThanOrEqualTo],
        '978979',
      );
    });

    test(
      'sumber cache-only memakai Source.cache tanpa mengubah default',
      () async {
        final _CapturingFirestore firestore = _CapturingFirestore();
        final BookRepository repository = BookRepository(firestore: firestore);

        await repository.search('bumi', scope: BookSearchScope.title);
        expect(firestore.books.getCalls.single, <Object?>[null]);

        await repository.search(
          'bumi',
          scope: BookSearchScope.title,
          source: BookSearchSource.cacheOnly,
        );
        final Object? options = firestore.books.getCalls.last.single;
        expect(options, isA<GetOptions>());
        expect((options! as GetOptions).source, Source.cache);
      },
    );
  });

  test('appendUniqueBooks membuang duplikat dan mempertahankan urutan', () {
    final Book first = sampleBook();
    final Book second = Book(
      id: 'book-2',
      title: 'Laskar Pelangi',
      author: 'Andrea Hirata',
      isbn: '9789793062792',
      publisher: 'Bentang Pustaka',
      year: 2005,
      totalPages: 529,
      category: 'Fiksi',
      synopsis: 'Kisah sepuluh anak Belitung.',
      createdBy: 'admin-1',
    );
    final Book third = Book(
      id: 'book-3',
      title: 'Sapiens',
      author: 'Yuval Noah Harari',
      isbn: '9786024246945',
      publisher: 'Kepustakaan Populer Gramedia',
      year: 2017,
      totalPages: 528,
      category: 'Sejarah',
      synopsis: 'Sejarah singkat umat manusia.',
      createdBy: 'admin-1',
    );

    final List<Book> merged = appendUniqueBooks(
      <Book>[first, second],
      <Book>[second, third, first],
    );

    expect(merged, <Book>[first, second, third]);
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
  final List<List<Object?>> getCalls = <List<Object?>>[];

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
        getCalls.add(invocation.positionalArguments);
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
