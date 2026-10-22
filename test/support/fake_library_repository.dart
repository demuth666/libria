import 'dart:async';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';

/// Membuat entri rak contoh untuk uji layar Koleksi dan Detail Buku.
LibraryEntry fakeLibraryEntry(
  int index, {
  String? title,
  String? author,
  String? status,
  int currentPage = 0,
  int totalPages = 100,
  DateTime? finishedAt,
  String? coverUrl,
}) {
  return LibraryEntry(
    bookId: 'book-$index',
    status: status ?? LibraryEntry.statusReading,
    currentPage: currentPage,
    bookTitle: title ?? 'Buku $index',
    bookAuthor: author ?? 'Penulis $index',
    bookCoverUrl: coverUrl,
    bookTotalPages: totalPages,
    addedAt: DateTime(2026, 1, index),
    finishedAt: finishedAt,
  );
}

/// Repository perpustakaan palsu tanpa Firestore atau Auth.
///
/// [watchLibraryFactory] dipakai bila uji perlu mengatur urutan stream untuk
/// percobaan ulang atau pemulihan koneksi. Bila tidak diisi, setiap pemanggilan
/// [watchLibrary] mengemit [entries] satu kali. [watchEntry] memakai stream
/// siaran per buku sehingga perubahan dari aksi tulis langsung terlihat oleh
/// layar Detail Buku dan Koleksi.
class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository({List<LibraryEntry>? entries})
    : entries = entries ?? <LibraryEntry>[] {
    _libraryController = StreamController<List<LibraryEntry>>.broadcast(
      onListen: () {
        _libraryController.add(_currentLibrary());
      },
    );
  }

  late final StreamController<List<LibraryEntry>> _libraryController;

  List<LibraryEntry> entries;
  int watchLibraryCalls = 0;
  Stream<List<LibraryEntry>> Function()? watchLibraryFactory;

  final List<String> watchedEntryIds = <String>[];
  final Map<String, StreamController<LibraryEntry?>> _entryControllers =
      <String, StreamController<LibraryEntry?>>{};

  int addBookCalls = 0;
  int updateStatusCalls = 0;
  int updateCurrentPageCalls = 0;
  final List<Book> addedBooks = <Book>[];
  final List<String> requestedStatuses = <String>[];
  final List<int> requestedPages = <int>[];

  Completer<void>? addBookGate;
  Completer<void>? updateStatusGate;
  Completer<void>? updateCurrentPageGate;
  Object? addBookError;
  Object? updateStatusError;
  Object? updateCurrentPageError;

  LibraryEntry? entryFor(String bookId) {
    for (final LibraryEntry entry in entries) {
      if (entry.bookId == bookId) {
        return entry;
      }
    }
    return null;
  }

  @override
  Stream<List<LibraryEntry>> watchLibrary() {
    watchLibraryCalls++;
    final Stream<List<LibraryEntry>> Function()? factory = watchLibraryFactory;
    if (factory != null) {
      return factory();
    }
    return _libraryController.stream;
  }

  List<LibraryEntry> _currentLibrary() {
    return List<LibraryEntry>.unmodifiable(entries);
  }

  void _emitLibrary() {
    if (_libraryController.hasListener) {
      _libraryController.add(_currentLibrary());
    }
  }

  @override
  Stream<LibraryEntry?> watchEntry(String bookId) {
    watchedEntryIds.add(bookId);
    return _controllerFor(bookId).stream;
  }

  StreamController<LibraryEntry?> _controllerFor(String bookId) {
    return _entryControllers.putIfAbsent(bookId, () {
      late final StreamController<LibraryEntry?> controller;
      controller = StreamController<LibraryEntry?>.broadcast(
        onListen: () {
          controller.add(entryFor(bookId));
        },
      );
      return controller;
    });
  }

  void _emit(String bookId) {
    final StreamController<LibraryEntry?>? controller =
        _entryControllers[bookId];
    if (controller != null && controller.hasListener) {
      controller.add(entryFor(bookId));
    }
  }

  @override
  Future<void> addBook(
    Book book, {
    String status = LibraryEntry.statusWant,
  }) async {
    addBookCalls++;
    addedBooks.add(book);
    requestedStatuses.add(status);
    if (addBookGate != null) {
      await addBookGate!.future;
    }
    if (addBookError != null) {
      throw addBookError!;
    }
    if (entryFor(book.id) != null) {
      return;
    }
    entries.add(
      LibraryEntry(
        bookId: book.id,
        status: status,
        bookTitle: book.title,
        bookAuthor: book.author,
        bookCoverUrl: book.coverUrl,
        bookTotalPages: book.totalPages,
        addedAt: DateTime(2026, 3, 1),
      ),
    );
    _emit(book.id);
    _emitLibrary();
  }

  @override
  Future<void> updateStatus(String bookId, String status) async {
    updateStatusCalls++;
    requestedStatuses.add(status);
    if (updateStatusGate != null) {
      await updateStatusGate!.future;
    }
    if (updateStatusError != null) {
      throw updateStatusError!;
    }
    final int index = _indexOf(bookId);
    if (index < 0) {
      throw const LibraryFailure(AppStrings.libraryEntryNotFound);
    }
    final LibraryEntry current = entries[index];
    entries[index] = _copyEntry(
      current,
      status: status,
      finishedAt: status == LibraryEntry.statusFinished
          ? DateTime(2026, 3, 12)
          : null,
      clearFinishedAt: status != LibraryEntry.statusFinished,
    );
    _emit(bookId);
    _emitLibrary();
  }

  @override
  Future<void> updateCurrentPage(String bookId, int currentPage) async {
    updateCurrentPageCalls++;
    requestedPages.add(currentPage);
    if (updateCurrentPageGate != null) {
      await updateCurrentPageGate!.future;
    }
    if (updateCurrentPageError != null) {
      throw updateCurrentPageError!;
    }
    final int index = _indexOf(bookId);
    if (index < 0) {
      throw const LibraryFailure(AppStrings.libraryEntryNotFound);
    }
    final LibraryEntry current = entries[index];
    final LibraryPageProgress progress = LibraryRepository.progressForPage(
      currentStatus: current.status,
      currentPage: currentPage,
      bookTotalPages: current.bookTotalPages,
    );
    entries[index] = _copyEntry(
      current,
      currentPage: currentPage,
      status: progress.status,
      finishedAt: progress.reachedLastPage
          ? DateTime(2026, 3, 12)
          : current.finishedAt,
    );
    _emit(bookId);
    _emitLibrary();
  }

  int _indexOf(String bookId) {
    return entries.indexWhere((LibraryEntry entry) => entry.bookId == bookId);
  }

  LibraryEntry _copyEntry(
    LibraryEntry entry, {
    String? status,
    int? currentPage,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
  }) {
    return LibraryEntry(
      bookId: entry.bookId,
      status: status ?? entry.status,
      currentPage: currentPage ?? entry.currentPage,
      bookTitle: entry.bookTitle,
      bookAuthor: entry.bookAuthor,
      bookCoverUrl: entry.bookCoverUrl,
      bookTotalPages: entry.bookTotalPages,
      addedAt: entry.addedAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? entry.finishedAt),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
