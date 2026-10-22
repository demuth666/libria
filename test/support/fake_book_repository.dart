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
  double ratingAverage = 0,
  int ratingCount = 0,
  DateTime? createdAt,
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
    ratingAverage: ratingAverage,
    ratingCount: ratingCount,
    createdBy: 'admin-1',
    createdAt: createdAt,
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

  /// Halaman hasil pencarian per kunci `scope:term`; setiap pencarian memakai
  /// halaman berikutnya.
  final Map<String, List<List<Book>>> searchPages =
      <String, List<List<Book>>>{};
  final Map<String, int> _searchPageCalls = <String, int>{};

  /// Jumlah kegagalan berikutnya per kunci `scope:term`.
  final Map<String, int> searchFailures = <String, int>{};

  /// Sumber yang diminta setiap pencarian, untuk menguji jalur offline.
  final List<BookSearchSource> searchSources = <BookSearchSource>[];

  int deleteCalls = 0;
  Completer<void>? deleteGate;
  Object? deleteError;

  int getByIdCalls = 0;
  int getByIdFailuresRemaining = 0;
  Completer<void>? getByIdGate;
  final List<BookSearchSource> getByIdSources = <BookSearchSource>[];

  final List<String> findByIsbnCalls = <String>[];
  Object? findByIsbnError;
  Completer<void>? findByIsbnGate;

  int createCalls = 0;
  int updateCalls = 0;
  int newBookIdCalls = 0;
  int assertIsbnCalls = 0;
  String newBookIdValue = 'new-book-1';
  Book? lastCreatedBook;
  Book? lastUpdatedBook;
  Completer<void>? createGate;
  Completer<void>? updateGate;
  Object? createError;
  Object? updateError;
  Object? assertIsbnError;

  @override
  String newBookId() {
    newBookIdCalls++;
    return newBookIdValue;
  }

  @override
  Future<Book?> getById(
    String id, {
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) async {
    getByIdCalls++;
    getByIdSources.add(source);
    if (getByIdGate != null) {
      await getByIdGate!.future;
    }
    if (getByIdFailuresRemaining > 0) {
      getByIdFailuresRemaining--;
      throw StateError('Gagal memuat buku.');
    }
    for (final Book book in allBooks) {
      if (book.id == id) {
        return book;
      }
    }
    return null;
  }

  @override
  Future<void> assertIsbnAvailable(String isbn, {String? exceptId}) async {
    assertIsbnCalls++;
    if (assertIsbnError != null) {
      throw assertIsbnError!;
    }
  }

  @override
  Future<Book?> findByIsbn(String isbn) async {
    findByIsbnCalls.add(isbn);
    if (findByIsbnGate != null) {
      await findByIsbnGate!.future;
    }
    if (findByIsbnError != null) {
      throw findByIsbnError!;
    }
    final String normalized = BookRepository.normalizeIsbn(isbn);
    for (final Book book in allBooks) {
      if (BookRepository.normalizeIsbn(book.isbn) == normalized) {
        return book;
      }
    }
    return null;
  }

  @override
  Future<String> createBook(Book book) async {
    createCalls++;
    lastCreatedBook = book;
    if (createGate != null) {
      await createGate!.future;
    }
    if (createError != null) {
      throw createError!;
    }
    allBooks.add(book);
    return book.id;
  }

  @override
  Future<void> updateBook(Book book) async {
    updateCalls++;
    lastUpdatedBook = book;
    if (updateGate != null) {
      await updateGate!.future;
    }
    if (updateError != null) {
      throw updateError!;
    }
    final int index = allBooks.indexWhere((Book item) => item.id == book.id);
    if (index >= 0) {
      allBooks[index] = book;
    }
  }

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
  Future<BookPage> search(
    String prefix, {
    required BookSearchScope scope,
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    switch (scope) {
      case BookSearchScope.title:
        return searchByTitlePrefix(
          prefix,
          limit: limit,
          cursor: cursor,
          source: source,
        );
      case BookSearchScope.author:
        return searchByAuthorPrefix(
          prefix,
          limit: limit,
          cursor: cursor,
          source: source,
        );
      case BookSearchScope.isbn:
        return searchByIsbnPrefix(
          prefix,
          limit: limit,
          cursor: cursor,
          source: source,
        );
    }
  }

  @override
  Future<BookPage> searchByTitlePrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    titleSearches.add(prefix);
    return _search(
      gateKey: 'title:${prefix.trim().toLowerCase()}',
      matches: (Book book) =>
          book.titleLower.startsWith(prefix.trim().toLowerCase()),
      source: source,
    );
  }

  @override
  Future<BookPage> searchByAuthorPrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    authorSearches.add(prefix);
    return _search(
      gateKey: 'author:${prefix.trim().toLowerCase()}',
      matches: (Book book) =>
          book.authorLower.startsWith(prefix.trim().toLowerCase()),
      source: source,
    );
  }

  @override
  Future<BookPage> searchByIsbnPrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    isbnSearches.add(prefix);
    final String normalized = BookRepository.normalizeIsbn(prefix);
    return _search(
      gateKey: 'isbn:$normalized',
      matches: (Book book) =>
          BookRepository.normalizeIsbn(book.isbn).startsWith(normalized),
      source: source,
    );
  }

  Future<BookPage> _search({
    required String gateKey,
    required bool Function(Book book) matches,
    required BookSearchSource source,
  }) async {
    searchSources.add(source);
    final Completer<void>? gate = searchGates[gateKey];
    if (gate != null) {
      await gate.future;
    }
    if (searchError != null) {
      throw searchError!;
    }
    final int failures = searchFailures[gateKey] ?? 0;
    if (failures > 0) {
      searchFailures[gateKey] = failures - 1;
      throw StateError('Gagal memuat hasil pencarian.');
    }

    final List<List<Book>>? configuredPages = searchPages[gateKey];
    if (configuredPages != null && configuredPages.isNotEmpty) {
      final int call = _searchPageCalls[gateKey] ?? 0;
      _searchPageCalls[gateKey] = call + 1;
      final int index = call < configuredPages.length
          ? call
          : configuredPages.length - 1;
      return BookPage(
        books: List<Book>.of(configuredPages[index]),
        hasMore: index < configuredPages.length - 1,
      );
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
