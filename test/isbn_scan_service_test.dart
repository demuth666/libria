import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';
import 'package:libria/features/scanner/data/isbn_scan_service.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_isbn_log_repository.dart';

void main() {
  const String isbn = '9789799731234';

  late FakeBookRepository books;
  late FakeIsbnLogRepository logs;
  late IsbnScanService service;

  setUp(() {
    books = FakeBookRepository();
    logs = FakeIsbnLogRepository();
    service = IsbnScanService(bookRepository: books, isbnLogRepository: logs);
  });

  test('ISBN terdaftar mengembalikan buku tanpa mencatat log', () async {
    final Book book = fakeBook(1, isbn: isbn);
    books.allBooks.add(book);

    final IsbnScanResult result = await service.scan('978-979-973-123-4');

    expect(result.status, IsbnScanStatus.found);
    expect(result.isFound, isTrue);
    expect(result.book, same(book));
    expect(result.isbn, isbn);
    expect(books.findByIsbnCalls, <String>[isbn]);
    expect(logs.recordCalls, 0);
  });

  test('ISBN tak terdaftar mencatat log dan mengembalikan pesan', () async {
    final IsbnScanResult result = await service.scan('978-979-973-123-4');

    expect(result.status, IsbnScanStatus.notFound);
    expect(result.isNotFound, isTrue);
    expect(result.isbn, isbn);
    expect(result.message, AppStrings.isbnScanNotFoundMessage(isbn));
    expect(result.logError, isNull);
    expect(logs.recordCalls, 1);
    expect(logs.recordedIsbns, <String>[isbn]);
  });

  test('barcode bukan ISBN tidak mencari katalog atau mencatat log', () async {
    final IsbnScanResult result = await service.scan('12345');

    expect(result.status, IsbnScanStatus.invalid);
    expect(result.message, AppStrings.isbnScanInvalidMessage);
    expect(books.findByIsbnCalls, isEmpty);
    expect(logs.recordCalls, 0);
  });

  test(
    'kegagalan mencatat log tetap menampilkan ISBN tidak ditemukan',
    () async {
      logs.recordError = const IsbnLogFailure('Log ISBN gagal disimpan.');

      final IsbnScanResult result = await service.scan(isbn);

      expect(result.status, IsbnScanStatus.notFound);
      expect(result.message, AppStrings.isbnScanNotFoundMessage(isbn));
      expect(result.logError, 'Log ISBN gagal disimpan.');
    },
  );

  test('kegagalan koneksi saat mencari menjadi pesan ramah', () async {
    books.findByIsbnError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    final IsbnScanResult result = await service.scan(isbn);

    expect(result.status, IsbnScanStatus.failure);
    expect(result.message, AppStrings.isbnScanLookupNetworkError);
  });

  test('kegagalan izin Firestore memakai pesan izin', () async {
    books.findByIsbnError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    final IsbnScanResult result = await service.scan(isbn);

    expect(result.status, IsbnScanStatus.failure);
    expect(result.message, AppStrings.isbnScanLookupPermissionDenied);
  });

  test('BookFailure diteruskan dengan pesannya', () async {
    books.findByIsbnError = const BookFailure('Katalog sedang bermasalah.');

    final IsbnScanResult result = await service.scan(isbn);

    expect(result.status, IsbnScanStatus.failure);
    expect(result.message, 'Katalog sedang bermasalah.');
  });

  test('galat tak dikenal saat mencari memakai pesan umum', () async {
    books.findByIsbnError = StateError('galat tak terduga');

    final IsbnScanResult result = await service.scan(isbn);

    expect(result.status, IsbnScanStatus.failure);
    expect(result.message, AppStrings.isbnScanLookupError);
  });
}
