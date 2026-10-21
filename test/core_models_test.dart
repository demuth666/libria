import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/isbn_logs/data/isbn_log.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/reading_session.dart';

void main() {
  group('Book', () {
    test('fromMap membaca seluruh field', () {
      final Timestamp createdAt = Timestamp.fromDate(
        DateTime(2025, 1, 2, 3, 4),
      );
      final Book book = Book.fromMap('book-1', <String, dynamic>{
        'title': 'Bumi Manusia',
        'author': 'Pramoedya Ananta Toer',
        'isbn': '9789799731234',
        'publisher': 'Lentera Dipantara',
        'year': 1980,
        'totalPages': 535,
        'category': 'Fiksi',
        'synopsis': 'Kisah Minke dan perjalanan hidupnya.',
        'coverUrl': 'https://contoh.com/bumi-manusia.jpg',
        'ratingAverage': 4.7,
        'ratingCount': 120,
        'createdBy': 'admin-1',
        'createdAt': createdAt,
        'updatedAt': createdAt,
      });

      expect(book.id, 'book-1');
      expect(book.title, 'Bumi Manusia');
      expect(book.author, 'Pramoedya Ananta Toer');
      expect(book.isbn, '9789799731234');
      expect(book.publisher, 'Lentera Dipantara');
      expect(book.year, 1980);
      expect(book.totalPages, 535);
      expect(book.category, 'Fiksi');
      expect(book.synopsis, 'Kisah Minke dan perjalanan hidupnya.');
      expect(book.coverUrl, 'https://contoh.com/bumi-manusia.jpg');
      expect(book.ratingAverage, 4.7);
      expect(book.ratingCount, 120);
      expect(book.createdBy, 'admin-1');
      expect(book.createdAt, createdAt.toDate());
      expect(book.updatedAt, createdAt.toDate());
      expect(book.titleLower, 'bumi manusia');
      expect(book.authorLower, 'pramoedya ananta toer');
    });

    test('fromMap memakai nilai awal untuk field yang tidak ada', () {
      final Book book = Book.fromMap('book-2', <String, dynamic>{});

      expect(book.title, '');
      expect(book.author, '');
      expect(book.isbn, '');
      expect(book.publisher, '');
      expect(book.year, 0);
      expect(book.totalPages, 0);
      expect(book.category, '');
      expect(book.synopsis, '');
      expect(book.coverUrl, isNull);
      expect(book.ratingAverage, 0);
      expect(book.ratingCount, 0);
      expect(book.createdBy, '');
      expect(book.createdAt, isNull);
      expect(book.updatedAt, isNull);
    });

    test('toMap menulis field turunan dan server timestamp', () {
      const Book book = Book(
        id: 'book-3',
        title: 'Bumi Manusia',
        author: 'Pramoedya Ananta Toer',
        isbn: '9789799731234',
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

      final Map<String, dynamic> map = book.toMap();

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
  });

  group('IsbnLog', () {
    test('menormalkan ISBN dari dokumen menjadi ID yang sama', () {
      final IsbnLog log = IsbnLog.fromMap(' 0-8044-2957-x ', <String, dynamic>{
        'scanCount': 2,
      });

      expect(log.isbn, '080442957X');
      expect(log.scanCount, 2);
      expect(log.toMap()['isbn'], '080442957X');
    });
  });

  group('LibraryEntry', () {
    test('fromMap membaca seluruh field', () {
      final Timestamp addedAt = Timestamp.fromDate(DateTime(2025, 2, 3));
      final Timestamp finishedAt = Timestamp.fromDate(DateTime(2025, 2, 10));
      final LibraryEntry entry = LibraryEntry.fromMap('book-1', {
        'status': LibraryEntry.statusFinished,
        'currentPage': 535,
        'addedAt': addedAt,
        'finishedAt': finishedAt,
        'bookTitle': 'Bumi Manusia',
        'bookAuthor': 'Pramoedya Ananta Toer',
        'bookCoverUrl': 'https://contoh.com/bumi-manusia.jpg',
        'bookTotalPages': 535,
      });

      expect(entry.bookId, 'book-1');
      expect(entry.status, LibraryEntry.statusFinished);
      expect(entry.currentPage, 535);
      expect(entry.addedAt, addedAt.toDate());
      expect(entry.finishedAt, finishedAt.toDate());
      expect(entry.bookTitle, 'Bumi Manusia');
      expect(entry.bookAuthor, 'Pramoedya Ananta Toer');
      expect(entry.bookCoverUrl, 'https://contoh.com/bumi-manusia.jpg');
      expect(entry.bookTotalPages, 535);
    });

    test('fromMap memakai status want dan halaman 0 bila tidak ada', () {
      final LibraryEntry entry = LibraryEntry.fromMap('book-2', {
        'bookTitle': 'Laskar Pelangi',
        'bookAuthor': 'Andrea Hirata',
        'bookTotalPages': 529,
      });

      expect(entry.status, LibraryEntry.statusWant);
      expect(entry.currentPage, 0);
      expect(entry.addedAt, isNull);
      expect(entry.finishedAt, isNull);
      expect(entry.bookCoverUrl, isNull);
    });

    test('toMap menulis tanggal dan tidak menyertakan bookId', () {
      final DateTime addedAt = DateTime(2025, 2, 3, 10, 30);
      final LibraryEntry entry = LibraryEntry(
        bookId: 'book-3',
        status: LibraryEntry.statusReading,
        currentPage: 42,
        bookTitle: 'Laskar Pelangi',
        bookAuthor: 'Andrea Hirata',
        bookTotalPages: 529,
        addedAt: addedAt,
      );

      final Map<String, dynamic> map = entry.toMap();

      expect(map['status'], LibraryEntry.statusReading);
      expect(map['currentPage'], 42);
      expect(map['bookTitle'], 'Laskar Pelangi');
      expect(map['bookAuthor'], 'Andrea Hirata');
      expect(map['bookCoverUrl'], isNull);
      expect(map['bookTotalPages'], 529);
      expect(map['addedAt'], isA<Timestamp>());
      expect((map['addedAt'] as Timestamp).toDate(), addedAt);
      expect(map['finishedAt'], isNull);
      expect(map.containsKey('bookId'), isFalse);
    });

    test('toMap mengisi addedAt dengan server timestamp bila kosong', () {
      const LibraryEntry entry = LibraryEntry(
        bookId: 'book-4',
        status: LibraryEntry.statusWant,
        bookTitle: 'Pulang',
        bookAuthor: 'Leila S. Chudori',
        bookTotalPages: 400,
      );

      expect(entry.toMap()['addedAt'], isA<FieldValue>());
    });
  });

  group('ReadingSession', () {
    test('fromMap membaca seluruh field', () {
      final Timestamp startedAt = Timestamp.fromDate(DateTime(2025, 3, 1, 8));
      final Timestamp endedAt = Timestamp.fromDate(DateTime(2025, 3, 1, 8, 30));
      final ReadingSession session = ReadingSession.fromMap(
        'session-1',
        <String, dynamic>{
          'bookId': 'book-1',
          'bookTitle': 'Bumi Manusia',
          'startedAt': startedAt,
          'endedAt': endedAt,
          'durationSeconds': 1800,
          'targetSeconds': 1800,
          'startPage': 10,
          'endPage': 40,
          'targetReached': true,
        },
      );

      expect(session.id, 'session-1');
      expect(session.bookId, 'book-1');
      expect(session.bookTitle, 'Bumi Manusia');
      expect(session.startedAt, startedAt.toDate());
      expect(session.endedAt, endedAt.toDate());
      expect(session.durationSeconds, 1800);
      expect(session.targetSeconds, 1800);
      expect(session.startPage, 10);
      expect(session.endPage, 40);
      expect(session.targetReached, isTrue);
    });

    test('fromMap memakai nilai awal untuk field yang tidak ada', () {
      final ReadingSession session = ReadingSession.fromMap(
        'session-2',
        <String, dynamic>{},
      );

      expect(session.bookId, '');
      expect(session.bookTitle, '');
      expect(session.startedAt, isNull);
      expect(session.endedAt, isNull);
      expect(session.durationSeconds, 0);
      expect(session.targetSeconds, 0);
      expect(session.startPage, 0);
      expect(session.endPage, 0);
      expect(session.targetReached, isFalse);
    });

    test('toMap menulis tanggal sebagai Timestamp', () {
      final DateTime startedAt = DateTime(2025, 3, 2, 7, 15);
      final DateTime endedAt = DateTime(2025, 3, 2, 7, 45);
      final ReadingSession session = ReadingSession(
        id: 'session-3',
        bookId: 'book-2',
        bookTitle: 'Laskar Pelangi',
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: 1800,
        targetSeconds: 1800,
        startPage: 5,
        endPage: 30,
        targetReached: true,
      );

      final Map<String, dynamic> map = session.toMap();

      expect(map['bookId'], 'book-2');
      expect(map['bookTitle'], 'Laskar Pelangi');
      expect(map['startedAt'], isA<Timestamp>());
      expect((map['startedAt'] as Timestamp).toDate(), startedAt);
      expect(map['endedAt'], isA<Timestamp>());
      expect((map['endedAt'] as Timestamp).toDate(), endedAt);
      expect(map['durationSeconds'], 1800);
      expect(map['targetSeconds'], 1800);
      expect(map['startPage'], 5);
      expect(map['endPage'], 30);
      expect(map['targetReached'], isTrue);
      expect(map.containsKey('id'), isFalse);
    });
  });
}
