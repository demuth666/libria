import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/books/presentation/catalog_search_providers.dart';

import 'support/fake_book_repository.dart';

void main() {
  Future<ProviderContainer> createContainer(
    FakeBookRepository repository, {
    bool online = true,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith((Ref ref) => repository),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(online),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Provider autoDispose dibuang tanpa pendengar; uji ini perlu
    // mempertahankan state di antara beberapa pembacaan.
    container.listen<AsyncValue<CatalogSearchState>>(
      catalogSearchProvider,
      (
        AsyncValue<CatalogSearchState>? previous,
        AsyncValue<CatalogSearchState> next,
      ) {},
    );
    // Pastikan controller sudah menerima status konektivitas sebelum query.
    await container.read(connectivityProvider.future);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  CatalogSearchController controllerOf(ProviderContainer container) {
    return container.read(catalogSearchProvider.notifier);
  }

  CatalogSearchState stateOf(ProviderContainer container) {
    return container.read(catalogSearchProvider).requireValue;
  }

  test('keadaan awal menampilkan petunjuk tanpa menjalankan query', () async {
    final FakeBookRepository repository = FakeBookRepository();
    final ProviderContainer container = await createContainer(repository);

    final CatalogSearchState state = stateOf(container);
    expect(state.term, isEmpty);
    expect(state.books, isEmpty);
    expect(state.isSearchActive, isFalse);
    expect(repository.titleSearches, isEmpty);
    expect(repository.authorSearches, isEmpty);
    expect(repository.isbnSearches, isEmpty);
  });

  test('kata kunci kosong atau hanya spasi tidak menjalankan query', () async {
    final FakeBookRepository repository = FakeBookRepository();
    final ProviderContainer container = await createContainer(repository);
    final CatalogSearchController controller = controllerOf(container);

    await controller.search(term: '   ', scope: BookSearchScope.isbn);

    final CatalogSearchState state = stateOf(container);
    expect(state.term, isEmpty);
    expect(state.books, isEmpty);
    expect(repository.isbnSearches, isEmpty);
  });

  test(
    'halaman pertama memakai cakupan yang dipilih dan kata kunci di-trim',
    () async {
      final Book book = fakeBook(1, title: 'Bumi Manusia');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[book],
      );
      final ProviderContainer container = await createContainer(repository);
      final CatalogSearchController controller = controllerOf(container);

      await controller.search(term: '  bumi  ', scope: BookSearchScope.title);

      final CatalogSearchState state = stateOf(container);
      expect(state.term, 'bumi');
      expect(state.books, <Book>[book]);
      expect(state.hasMore, isFalse);
      expect(repository.titleSearches, <String>['bumi']);
    },
  );

  test(
    'cakupan judul, penulis, dan ISBN memakai pencarian repository yang benar',
    () async {
      final Book titleBook = fakeBook(1, title: 'Bumi Manusia');
      final Book authorBook = fakeBook(
        2,
        title: 'Laskar Pelangi',
        author: 'Andrea Hirata',
      );
      final Book isbnBook = fakeBook(
        3,
        title: 'Sapiens',
        author: 'Yuval Noah Harari',
        isbn: '978-979-973-123-4',
      );
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[titleBook, authorBook, isbnBook],
      );
      final ProviderContainer container = await createContainer(repository);
      final CatalogSearchController controller = controllerOf(container);

      await controller.search(term: 'bumi', scope: BookSearchScope.title);
      expect(repository.titleSearches, <String>['bumi']);
      expect(stateOf(container).books, <Book>[titleBook]);

      await controller.search(term: 'andrea', scope: BookSearchScope.author);
      expect(repository.authorSearches, <String>['andrea']);
      expect(stateOf(container).books, <Book>[authorBook]);

      await controller.search(term: '978-979', scope: BookSearchScope.isbn);
      expect(repository.isbnSearches, <String>['978-979']);
      expect(stateOf(container).books, <Book>[isbnBook]);
    },
  );

  test(
    'paginasi menambahkan halaman berikutnya tanpa duplikat dan menjaga urutan',
    () async {
      final List<Book> firstPage = List<Book>.generate(
        20,
        (int index) => fakeBook(index, title: 'Bumi $index'),
      );
      final List<Book> secondPage = <Book>[
        firstPage.last,
        ...List<Book>.generate(
          4,
          (int index) => fakeBook(index + 20, title: 'Bumi ${index + 20}'),
        ),
      ];
      final FakeBookRepository repository = FakeBookRepository()
        ..searchPages['title:bumi'] = <List<Book>>[firstPage, secondPage];
      final ProviderContainer container = await createContainer(repository);
      final CatalogSearchController controller = controllerOf(container);

      await controller.search(term: 'bumi', scope: BookSearchScope.title);

      CatalogSearchState state = stateOf(container);
      expect(state.books, firstPage);
      expect(state.hasMore, isTrue);
      expect(state.canLoadMore, isTrue);

      await controller.loadMore();

      state = stateOf(container);
      expect(state.books, hasLength(24));
      expect(state.books.map((Book book) => book.id).toSet(), hasLength(24));
      expect(state.books.map((Book book) => book.id).toList(), <String>[
        ...firstPage.map((Book book) => book.id),
        ...List<String>.generate(4, (int index) => fakeBook(index + 20).id),
      ]);
      expect(state.hasMore, isFalse);
    },
  );

  test(
    'kegagalan muat lebih banyak mempertahankan hasil dan bisa dicoba lagi',
    () async {
      final List<Book> firstPage = List<Book>.generate(
        20,
        (int index) => fakeBook(index, title: 'Bumi $index'),
      );
      final List<Book> secondPage = <Book>[
        ...List<Book>.generate(
          3,
          (int index) => fakeBook(index + 20, title: 'Bumi ${index + 20}'),
        ),
      ];
      final FakeBookRepository repository = FakeBookRepository()
        ..searchPages['title:bumi'] = <List<Book>>[firstPage, secondPage];
      final ProviderContainer container = await createContainer(repository);
      final CatalogSearchController controller = controllerOf(container);

      await controller.search(term: 'bumi', scope: BookSearchScope.title);
      repository.searchFailures['title:bumi'] = 1;

      await controller.loadMore();

      CatalogSearchState state = stateOf(container);
      expect(state.books, firstPage);
      expect(state.hasMore, isTrue);
      expect(state.loadMoreFailed, isTrue);
      expect(state.isLoadingMore, isFalse);

      await controller.loadMore();

      state = stateOf(container);
      expect(state.books, hasLength(23));
      expect(state.loadMoreFailed, isFalse);
      expect(state.hasMore, isFalse);
    },
  );

  test('mengganti cakupan mempertahankan kata kunci, mereset paginasi, dan menjalankan query baru', () async {
    final List<Book> titlePage = List<Book>.generate(
      20,
      (int index) => fakeBook(index, title: 'Bumi $index'),
    );
    final Book authorBook = fakeBook(
      30,
      title: 'Laskar Pelangi',
      author: 'Bumi Sakti',
    );
    final FakeBookRepository repository =
        FakeBookRepository(books: <Book>[authorBook])
          ..searchPages['title:bumi'] = <List<Book>>[
            titlePage,
            <Book>[fakeBook(99, title: 'Bumi Lain')],
          ];
    final ProviderContainer container = await createContainer(repository);
    final CatalogSearchController controller = controllerOf(container);

    await controller.search(term: 'bumi', scope: BookSearchScope.title);
    expect(stateOf(container).hasMore, isTrue);

    await controller.search(term: 'bumi', scope: BookSearchScope.author);

    final CatalogSearchState state = stateOf(container);
    expect(state.term, 'bumi');
    expect(state.books, <Book>[authorBook]);
    expect(state.hasMore, isFalse);

    await controller.loadMore();
    expect(stateOf(container).books, <Book>[authorBook]);
    expect(repository.authorSearches, <String>['bumi']);
  });

  test(
    'respons query lama yang terlambat tidak menimpa hasil terbaru',
    () async {
      final Book oldBook = fakeBook(1, title: 'Lama');
      final Book newBook = fakeBook(2, title: 'Baru');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[oldBook, newBook],
      );
      final Completer<void> oldGate = Completer<void>();
      repository.searchGates['title:lama'] = oldGate;
      final ProviderContainer container = await createContainer(repository);
      final CatalogSearchController controller = controllerOf(container);

      final Future<void> oldSearch = controller.search(
        term: 'lama',
        scope: BookSearchScope.title,
      );
      await controller.search(term: 'baru', scope: BookSearchScope.title);

      expect(stateOf(container).books, <Book>[newBook]);

      oldGate.complete();
      await oldSearch;

      final CatalogSearchState state = stateOf(container);
      expect(state.term, 'baru');
      expect(state.books, <Book>[newBook]);
    },
  );

  test(
    'respons muat lebih banyak lama tidak menambah hasil query baru',
    () async {
      final Book oldBook = fakeBook(1, title: 'Bumi Manusia');
      final Book newBook = fakeBook(2, title: 'Baru');
      final Book oldSecondPage = fakeBook(3, title: 'Bumi Lain');
      final FakeBookRepository repository =
          FakeBookRepository(books: <Book>[oldBook, newBook])
            ..searchPages['title:bumi'] = <List<Book>>[
              <Book>[oldBook],
              <Book>[oldSecondPage],
            ];
      final ProviderContainer container = await createContainer(repository);
      final CatalogSearchController controller = controllerOf(container);

      await controller.search(term: 'bumi', scope: BookSearchScope.title);
      expect(stateOf(container).hasMore, isTrue);

      final Completer<void> gate = Completer<void>();
      repository.searchGates['title:bumi'] = gate;
      final Future<void> oldLoadMore = controller.loadMore();

      await controller.search(term: 'baru', scope: BookSearchScope.title);
      expect(stateOf(container).books, <Book>[newBook]);

      gate.complete();
      await oldLoadMore;

      final CatalogSearchState state = stateOf(container);
      expect(state.term, 'baru');
      expect(state.books, <Book>[newBook]);
    },
  );

  test('menghapus pencarian membatalkan respons yang masih berjalan', () async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final Completer<void> gate = Completer<void>();
    repository.searchGates['title:bumi'] = gate;
    final ProviderContainer container = await createContainer(repository);
    final CatalogSearchController controller = controllerOf(container);

    final Future<void> pending = controller.search(
      term: 'bumi',
      scope: BookSearchScope.title,
    );
    controller.clear();
    gate.complete();
    await pending;

    final CatalogSearchState state = stateOf(container);
    expect(state.term, isEmpty);
    expect(state.books, isEmpty);
  });

  test('hasil kosong tetap menyimpan kata kunci aktif', () async {
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[fakeBook(1, title: 'Bumi Manusia')],
    );
    final ProviderContainer container = await createContainer(repository);
    final CatalogSearchController controller = controllerOf(container);

    await controller.search(term: 'tidak ada', scope: BookSearchScope.title);

    final CatalogSearchState state = stateOf(container);
    expect(state.isSearchActive, isTrue);
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test(
    'galat halaman pertama memakai pesan ramah dan Coba Lagi memuat ulang',
    () async {
      final Book book = fakeBook(1, title: 'Bumi Manusia');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[book],
      )..searchError = StateError('detail internal tidak boleh tampil');
      final ProviderContainer container = await createContainer(repository);
      final CatalogSearchController controller = controllerOf(container);

      await controller.search(term: 'bumi', scope: BookSearchScope.title);

      final Object? error = container.read(catalogSearchProvider).error;
      expect(error, isA<CatalogSearchFailure>());
      final CatalogSearchFailure failure = error! as CatalogSearchFailure;
      expect(failure.message, AppStrings.catalogSearchError);
      expect(failure.isOffline, isFalse);

      repository.searchError = null;
      await controller.retry();

      expect(stateOf(container).books, <Book>[book]);
      expect(container.read(catalogSearchProvider).hasError, isFalse);
    },
  );

  test('offline memakai cache dan hasil yang tersimpan tetap tampil', () async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final ProviderContainer container = await createContainer(
      repository,
      online: false,
    );
    final CatalogSearchController controller = controllerOf(container);

    await controller.search(term: 'bumi', scope: BookSearchScope.title);

    expect(stateOf(container).books, <Book>[book]);
    expect(repository.searchSources.last, BookSearchSource.cacheOnly);
  });

  test('offline tanpa cache menampilkan pesan offline yang ramah', () async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository();
    final ProviderContainer container = await createContainer(
      repository,
      online: false,
    );
    final CatalogSearchController controller = controllerOf(container);

    await controller.search(term: 'bumi', scope: BookSearchScope.title);

    final Object? error = container.read(catalogSearchProvider).error;
    expect(error, isA<CatalogSearchFailure>());
    final CatalogSearchFailure failure = error! as CatalogSearchFailure;
    expect(failure.isOffline, isTrue);
    expect(failure.message, AppStrings.catalogSearchOfflineMessage);

    // Cache terisi setelah percobaan pertama; Coba Lagi memuat hasilnya.
    repository.allBooks.add(book);
    await controller.retry();
    expect(stateOf(container).books, <Book>[book]);
  });

  test(
    'muat lebih banyak offline dengan cache kosong mempertahankan hasil',
    () async {
      final List<Book> firstPage = List<Book>.generate(
        20,
        (int index) => fakeBook(index, title: 'Bumi $index'),
      );
      final FakeBookRepository repository = FakeBookRepository()
        ..searchPages['title:bumi'] = <List<Book>>[firstPage, <Book>[]];
      final ProviderContainer container = await createContainer(
        repository,
        online: false,
      );
      final CatalogSearchController controller = controllerOf(container);

      await controller.search(term: 'bumi', scope: BookSearchScope.title);
      expect(stateOf(container).books, firstPage);

      await controller.loadMore();

      final CatalogSearchState state = stateOf(container);
      expect(state.books, firstPage);
      expect(state.loadMoreFailed, isTrue);
      expect(state.isLoadingMore, isFalse);
    },
  );

  test(
    'provider yang dibuang saat query berjalan tidak memunculkan galat',
    () async {
      final Completer<void> gate = Completer<void>();
      final FakeBookRepository repository = FakeBookRepository()
        ..searchGates['title:bumi'] = gate;
      final ProviderContainer container = ProviderContainer(
        overrides: [
          bookRepositoryProvider.overrideWith((Ref ref) => repository),
          connectivityProvider.overrideWith(
            (Ref ref) => Stream<bool>.value(true),
          ),
        ],
      );
      container.listen<AsyncValue<CatalogSearchState>>(
        catalogSearchProvider,
        (
          AsyncValue<CatalogSearchState>? previous,
          AsyncValue<CatalogSearchState> next,
        ) {},
      );
      final CatalogSearchController controller = container.read(
        catalogSearchProvider.notifier,
      );

      final Future<void> pending = controller.search(
        term: 'bumi',
        scope: BookSearchScope.title,
      );
      container.dispose();
      gate.complete();

      await expectLater(pending, completes);
    },
  );
}
