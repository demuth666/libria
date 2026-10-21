import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/admin/presentation/admin_books_providers.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';

import 'support/fake_book_repository.dart';

void main() {
  ProviderContainer createContainer(FakeBookRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [bookRepositoryProvider.overrideWith((Ref ref) => repository)],
    );
    addTearDown(container.dispose);
    // Provider autoDispose dibuang tanpa pendengar; uji ini perlu
    // mempertahankan state di antara beberapa pembacaan.
    container.listen<AsyncValue<AdminBooksState>>(
      adminBooksProvider,
      (
        AsyncValue<AdminBooksState>? previous,
        AsyncValue<AdminBooksState> next,
      ) {},
    );
    return container;
  }

  test('memuat halaman pertama lalu menambahkan halaman berikutnya', () async {
    final List<Book> firstPage = List<Book>.generate(
      20,
      (int index) => fakeBook(index),
    );
    final List<Book> secondPage = <Book>[
      // Sengaja mengulang buku terakhir halaman pertama untuk memastikan
      // penggabungan tidak menghasilkan duplikat.
      firstPage.last,
      ...List<Book>.generate(4, (int index) => fakeBook(index + 20)),
    ];
    final FakeBookRepository repository = FakeBookRepository()
      ..pages = <List<Book>>[firstPage, secondPage];
    final ProviderContainer container = createContainer(repository);
    final AdminBooksController controller = container.read(
      adminBooksProvider.notifier,
    );

    await controller.ensureLoaded();

    AdminBooksState state = container.read(adminBooksProvider).requireValue;
    expect(state.books, hasLength(20));
    expect(state.hasMore, isTrue);

    await controller.loadMore();

    state = container.read(adminBooksProvider).requireValue;
    expect(state.books, hasLength(24));
    expect(state.books.map((Book book) => book.id).toSet(), hasLength(24));
    expect(state.hasMore, isFalse);
    expect(repository.fetchPageCalls, 2);
  });

  test(
    'query baru mereset paginasi dan mengabaikan hasil query lama',
    () async {
      final Book oldBook = fakeBook(1, title: 'Lama', author: 'Penulis Lama');
      final Book newBook = fakeBook(2, title: 'Baru', author: 'Penulis Baru');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[oldBook, newBook],
      );
      final Completer<void> oldSearchGate = Completer<void>();
      repository.searchGates['title:lama'] = oldSearchGate;
      final ProviderContainer container = createContainer(repository);
      final AdminBooksController controller = container.read(
        adminBooksProvider.notifier,
      );
      await controller.ensureLoaded();

      final Future<void> oldSearch = controller.search(
        term: 'lama',
        scope: BookSearchScope.title,
      );
      await controller.search(term: 'baru', scope: BookSearchScope.title);

      expect(container.read(adminBooksProvider).requireValue.books, <Book>[
        newBook,
      ]);

      oldSearchGate.complete();
      await oldSearch;

      final AdminBooksState state = container
          .read(adminBooksProvider)
          .requireValue;
      expect(state.term, 'baru');
      expect(state.books, <Book>[newBook]);
    },
  );

  test('pencarian memakai repository sesuai cakupan yang dipilih', () async {
    final Book book = fakeBook(
      1,
      title: 'Bumi Manusia',
      author: 'Pramoedya Ananta Toer',
      isbn: '978-979-973-123-4',
    );
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final ProviderContainer container = createContainer(repository);
    final AdminBooksController controller = container.read(
      adminBooksProvider.notifier,
    );
    await controller.ensureLoaded();

    await controller.search(term: 'bumi', scope: BookSearchScope.title);
    expect(repository.titleSearches, <String>['bumi']);

    await controller.search(term: 'pram', scope: BookSearchScope.author);
    expect(repository.authorSearches, <String>['pram']);

    await controller.search(term: '978-979', scope: BookSearchScope.isbn);
    expect(repository.isbnSearches, <String>['978-979']);
    expect(container.read(adminBooksProvider).requireValue.books, <Book>[book]);

    await controller.search(term: '', scope: BookSearchScope.isbn);
    expect(container.read(adminBooksProvider).requireValue.books, <Book>[book]);
  });

  test(
    'hapus membuang baris, mencegah ketukan ganda, dan gagal dengan aman',
    () async {
      final Book first = fakeBook(1, title: 'Buku Pertama');
      final Book second = fakeBook(2, title: 'Buku Kedua');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[first, second],
      );
      final ProviderContainer container = createContainer(repository);
      final AdminBooksController controller = container.read(
        adminBooksProvider.notifier,
      );
      await controller.ensureLoaded();

      final Completer<void> deleteGate = Completer<void>();
      repository.deleteGate = deleteGate;
      final Future<void> firstDelete = controller.deleteBook(first);
      await controller.deleteBook(first);

      expect(repository.deleteCalls, 1);
      expect(
        container.read(adminBooksProvider).requireValue.deletingBookIds,
        contains(first.id),
      );

      deleteGate.complete();
      await firstDelete;

      AdminBooksState state = container.read(adminBooksProvider).requireValue;
      expect(state.books, <Book>[second]);
      expect(state.deletingBookIds, isEmpty);

      repository.deleteError = StateError('gagal menghapus');
      await expectLater(
        controller.deleteBook(second),
        throwsA(isA<StateError>()),
      );

      state = container.read(adminBooksProvider).requireValue;
      expect(state.books, <Book>[second]);
      expect(state.deletingBookIds, isEmpty);
    },
  );

  test('menghapus seluruh isi halaman memuat halaman berikutnya', () async {
    final Book first = fakeBook(1, title: 'Buku Pertama');
    final Book second = fakeBook(2, title: 'Buku Kedua');
    final FakeBookRepository repository = FakeBookRepository()
      ..pages = <List<Book>>[
        <Book>[first],
        <Book>[second],
      ];
    final ProviderContainer container = createContainer(repository);
    final AdminBooksController controller = container.read(
      adminBooksProvider.notifier,
    );
    await controller.ensureLoaded();

    expect(container.read(adminBooksProvider).requireValue.books, <Book>[
      first,
    ]);

    await controller.deleteBook(first);

    final AdminBooksState state = container
        .read(adminBooksProvider)
        .requireValue;
    expect(state.books, <Book>[second]);
    expect(state.hasMore, isFalse);
    expect(repository.fetchPageCalls, 2);
  });
}
