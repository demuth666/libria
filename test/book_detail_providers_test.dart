import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/books/presentation/book_detail_providers.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_library_repository.dart';

void main() {
  Future<ProviderContainer> createContainer({
    required FakeBookRepository bookRepository,
    FakeLibraryRepository? libraryRepository,
    bool online = true,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith((Ref ref) => bookRepository),
        libraryRepositoryProvider.overrideWith(
          (Ref ref) => libraryRepository ?? FakeLibraryRepository(),
        ),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(online),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Pastikan status koneksi sudah diketahui sebelum provider detail dibaca,
    // sama seperti aplikasi yang memasang OfflineBannerHost di akar widget.
    final ProviderSubscription<AsyncValue<bool>> connectivitySubscription =
        container.listen<AsyncValue<bool>>(
          connectivityProvider,
          (AsyncValue<bool>? previous, AsyncValue<bool> next) {},
          fireImmediately: true,
        );
    await Future<void>.delayed(Duration.zero);
    connectivitySubscription.close();
    return container;
  }

  Future<AsyncValue<Book>> loadState(
    ProviderContainer container,
    String bookId,
  ) {
    final Completer<AsyncValue<Book>> completer = Completer<AsyncValue<Book>>();
    final ProviderSubscription<AsyncValue<Book>> subscription = container
        .listen(bookDetailProvider(bookId), (
          AsyncValue<Book>? previous,
          AsyncValue<Book> next,
        ) {
          if (next.isLoading || completer.isCompleted) {
            return;
          }
          completer.complete(next);
        }, fireImmediately: true);
    addTearDown(subscription.close);
    return completer.future;
  }

  test(
    'Memuat buku dari repository dengan sumber default saat online',
    () async {
      final Book book = fakeBook(1, title: 'Bumi Manusia');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[book],
      );
      final ProviderContainer container = await createContainer(
        bookRepository: repository,
      );

      final AsyncValue<Book> state = await loadState(container, book.id);

      expect(state.value, same(book));
      expect(repository.getByIdSources, <BookSearchSource>[
        BookSearchSource.serverAndCache,
      ]);
    },
  );

  test('Buku yang tidak ada menjadi kegagalan tidak ditemukan', () async {
    final ProviderContainer container = await createContainer(
      bookRepository: FakeBookRepository(),
    );

    final AsyncValue<Book> state = await loadState(container, 'missing');

    expect(
      state.error,
      isA<BookDetailFailure>()
          .having(
            (BookDetailFailure failure) => failure.code,
            'code',
            BookDetailFailureCode.notFound,
          )
          .having(
            (BookDetailFailure failure) => failure.message,
            'message',
            AppStrings.bookDetailNotFoundMessage,
          ),
    );
  });

  test('Saat offline memakai cache dan menampilkan buku tersimpan', () async {
    final Book book = fakeBook(1, title: 'Buku Cache');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final ProviderContainer container = await createContainer(
      bookRepository: repository,
      online: false,
    );

    final AsyncValue<Book> state = await loadState(container, book.id);

    expect(state.value, same(book));
    expect(repository.getByIdSources, <BookSearchSource>[
      BookSearchSource.cacheOnly,
    ]);
  });

  test(
    'Offline tanpa cache menjadi kegagalan offline, bukan tidak ditemukan',
    () async {
      final ProviderContainer container = await createContainer(
        bookRepository: FakeBookRepository(),
        online: false,
      );

      final AsyncValue<Book> state = await loadState(container, 'missing');

      expect(
        state.error,
        isA<BookDetailFailure>()
            .having(
              (BookDetailFailure failure) => failure.code,
              'code',
              BookDetailFailureCode.offline,
            )
            .having(
              (BookDetailFailure failure) => failure.message,
              'message',
              AppStrings.bookDetailOfflineMessage,
            ),
      );
    },
  );

  test('Galat pemuatan menjadi pesan ramah tanpa detail teknis', () async {
    final FakeBookRepository repository = FakeBookRepository()
      ..getByIdFailuresRemaining = 1;
    final ProviderContainer container = await createContainer(
      bookRepository: repository,
    );

    final AsyncValue<Book> state = await loadState(container, 'book-1');

    expect(
      state.error,
      isA<BookDetailFailure>()
          .having(
            (BookDetailFailure failure) => failure.code,
            'code',
            BookDetailFailureCode.load,
          )
          .having(
            (BookDetailFailure failure) => failure.message,
            'message',
            AppStrings.bookDetailLoadError,
          ),
    );
  });

  test('Provider entri rak mengikuti perubahan dari repository', () async {
    final FakeLibraryRepository repository = FakeLibraryRepository(
      entries: <LibraryEntry>[fakeLibraryEntry(1, currentPage: 10)],
    );
    final ProviderContainer container = await createContainer(
      bookRepository: FakeBookRepository(),
      libraryRepository: repository,
    );
    final List<LibraryEntry?> values = <LibraryEntry?>[];
    final ProviderSubscription<AsyncValue<LibraryEntry?>> subscription =
        container.listen<AsyncValue<LibraryEntry?>>(
          libraryEntryProvider('book-1'),
          (
            AsyncValue<LibraryEntry?>? previous,
            AsyncValue<LibraryEntry?> next,
          ) {
            if (next.hasValue) {
              values.add(next.value);
            }
          },
          fireImmediately: true,
        );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);
    await repository.updateCurrentPage('book-1', 50);
    await Future<void>.delayed(Duration.zero);

    expect(values.last?.currentPage, 50);
  });
}
