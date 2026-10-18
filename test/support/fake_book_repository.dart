import 'dart:async';

import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';

/// Membuat buku contoh untuk uji daftar katalog admin.
Book fakeBook(
  int index, {
  String? title,
  String? author,
  String? isbn,
  String? coverUrl,
}) {
  return Book(
    id: 'book-$index',
    title: title ?? 'Buku $index',
    author: author ?? 'Penulis $index',
    isbn: isbn ?? '978000000$index',
    publisher: 'Penerbit Libria',
    year: 2026,
    totalPages: 200,
    category: 'Fiksi',
    synopsis: 'Sinopsis buku $index.',
    coverUrl: coverUrl,
    createdBy: 'admin-1',
  );
}

/// Repository buku palsu tanpa Firestore.
///
/// [pages] dipakai bila uji butuh lebih dari satu halaman; setiap pemanggilan
/// [fetchPage] mengambil halaman berikutnya. Bila [pages] kosong, seluruh
/// [allBooks] dikembalikan sebagai satu halaman.
class FakeBookRepository implements BookRepository {
  FakeBookRepository({List<Book>? books}) : allBooks = books ?? <Book>[];

  final List<Book> allBooks;
  List<List<Book>>? pages;

  int fetchPageCalls = 0;
  int fetchPageFailuresRemaining = 0;
  Completer<void>? fetchPageGate;

  final List<String> titleSearches = <String>[];
  final List<String> authorSearches = <String>[];
  final List<String> isbnSearches = <String>[];
  final Map<String, Completer<void>> searchGates = <String, Completer<void>>{};
  Object? searchError;

  int deleteCalls = 0;
  Completer<void>? deleteGate;
  Object? deleteError;

  @override
  Future<BookPage> fetchPage({
    int limit = bookPageSize,
    BookCursor? cursor,
  }) async {
    fetchPageCalls++;
    if (fetchPageGate != null) {
      await fetchPageGate!.future;
    }
    if (fetchPageFailuresRemaining > 0) {
      fetchPageFailuresRemaining--;
      throw StateError('Gagal memuat halaman buku.');
    }

    final List<List<Book>>? configuredPages = pages;
    if (configuredPages != null && configuredPages.isNotEmpty) {
      int index = fetchPageCalls - 1;
      if (index >= configuredPages.length) {
        index = configuredPages.length - 1;
      }
      return BookPage(
        books: List<Book>.of(configuredPages[index]),
        hasMore: index < configuredPages.length - 1,
      );
    }

    return BookPage(books: List<Book>.of(allBooks), hasMore: false);
  }

  @override
  Future<BookPage> searchByTitlePrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
  }) {
    titleSearches.add(prefix);
    return _search(
      gateKey: 'title:$prefix',
      matches: (Book book) =>
          book.titleLower.startsWith(prefix.trim().toLowerCase()),
    );
  }

  @override
  Future<BookPage> searchByAuthorPrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
  }) {
    authorSearches.add(prefix);
    return _search(
      gateKey: 'author:$prefix',
      matches: (Book book) =>
          book.authorLower.startsWith(prefix.trim().toLowerCase()),
    );
  }

  @override
  Future<BookPage> searchByIsbnPrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
  }) {
    isbnSearches.add(prefix);
    final String normalized = BookRepository.normalizeIsbn(prefix);
    return _search(
      gateKey: 'isbn:$normalized',
      matches: (Book book) =>
          BookRepository.normalizeIsbn(book.isbn).startsWith(normalized),
    );
  }

  Future<BookPage> _search({
    required String gateKey,
    required bool Function(Book book) matches,
  }) async {
    final Completer<void>? gate = searchGates[gateKey];
    if (gate != null) {
      await gate.future;
    }
    if (searchError != null) {
      throw searchError!;
    }
    final List<Book> results = allBooks.where(matches).toList(growable: false);
    return BookPage(books: results, hasMore: false);
  }

  @override
  Future<void> deleteBook(String id) async {
    deleteCalls++;
    if (deleteGate != null) {
      await deleteGate!.future;
    }
    if (deleteError != null) {
      throw deleteError!;
    }
    allBooks.removeWhere((Book book) => book.id == id);
    final List<List<Book>>? configuredPages = pages;
    if (configuredPages != null) {
      for (final List<Book> page in configuredPages) {
        page.removeWhere((Book book) => book.id == id);
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
