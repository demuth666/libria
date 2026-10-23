import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/session/presentation/session_setup_providers.dart';

import 'support/fake_book_repository.dart';

void main() {
  ProviderContainer createContainer(FakeBookRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [bookRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // Menjaga provider autoDispose tetap hidup selama uji.
    container.listen<AsyncValue<SessionCatalogData>>(
      sessionCatalogProvider,
      (
        AsyncValue<SessionCatalogData>? previous,
        AsyncValue<SessionCatalogData> next,
      ) {},
    );
    return container;
  }

  test('ensureLoaded memuat halaman pertama sekali saja', () async {
    final FakeBookRepository repository = FakeBookRepository();
    final ProviderContainer container = createContainer(repository);

    await container.read(sessionCatalogProvider.notifier).ensureLoaded();
    await container.read(sessionCatalogProvider.notifier).ensureLoaded();

    final SessionCatalogData data = container
        .read(sessionCatalogProvider)
        .requireValue;
    expect(data.books, isEmpty);
    expect(data.hasMore, isFalse);
    expect(repository.fetchPageCalls, 1);
  });

  test('loadMore menambahkan halaman berikutnya tanpa duplikat', () async {
    final FakeBookRepository repository = FakeBookRepository()
      ..pages = <List<Book>>[
        <Book>[fakeBook(1), fakeBook(2)],
        <Book>[fakeBook(2), fakeBook(3)],
      ];
    final ProviderContainer container = createContainer(repository);

    await container.read(sessionCatalogProvider.notifier).ensureLoaded();
    expect(
      container
          .read(sessionCatalogProvider)
          .requireValue
          .books
          .map((Book book) => book.id),
      <String>['book-1', 'book-2'],
    );

    await container.read(sessionCatalogProvider.notifier).loadMore();

    final SessionCatalogData data = container
        .read(sessionCatalogProvider)
        .requireValue;
    expect(data.books.map((Book book) => book.id), <String>[
      'book-1',
      'book-2',
      'book-3',
    ]);
    expect(data.hasMore, isFalse);
    expect(data.isLoadingMore, isFalse);
    expect(data.loadMoreFailed, isFalse);
    expect(repository.fetchPageCalls, 2);
  });

  test(
    'loadMore yang gagal mempertahankan buku dan bisa dicoba lagi',
    () async {
      final FakeBookRepository repository = FakeBookRepository()
        ..pages = <List<Book>>[
          <Book>[fakeBook(1)],
          <Book>[fakeBook(2)],
        ];
      final ProviderContainer container = createContainer(repository);

      await container.read(sessionCatalogProvider.notifier).ensureLoaded();
      repository.fetchPageFailuresRemaining = 1;
      await container.read(sessionCatalogProvider.notifier).loadMore();

      final SessionCatalogData failed = container
          .read(sessionCatalogProvider)
          .requireValue;
      expect(failed.books.map((Book book) => book.id), <String>['book-1']);
      expect(failed.loadMoreFailed, isTrue);
      expect(failed.isLoadingMore, isFalse);
      expect(failed.hasMore, isTrue);

      await container.read(sessionCatalogProvider.notifier).loadMore();

      final SessionCatalogData recovered = container
          .read(sessionCatalogProvider)
          .requireValue;
      expect(recovered.books.map((Book book) => book.id), <String>[
        'book-1',
        'book-2',
      ]);
      expect(recovered.loadMoreFailed, isFalse);
    },
  );

  test('retry memuat ulang halaman pertama setelah galat', () async {
    final FakeBookRepository repository = FakeBookRepository()
      ..fetchPageFailuresRemaining = 1;
    final ProviderContainer container = createContainer(repository);

    await container.read(sessionCatalogProvider.notifier).ensureLoaded();
    expect(container.read(sessionCatalogProvider).hasError, isTrue);

    await container.read(sessionCatalogProvider.notifier).retry();

    final AsyncValue<SessionCatalogData> state = container.read(
      sessionCatalogProvider,
    );
    expect(state.hasError, isFalse);
    expect(state.requireValue.books, isEmpty);
    expect(repository.fetchPageCalls, 2);
  });
}
