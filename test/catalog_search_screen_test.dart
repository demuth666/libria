import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_router.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';
import 'package:libria/core/widgets/empty_view.dart';
import 'package:libria/core/widgets/error_view.dart';
import 'package:libria/core/widgets/loading_view.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/library/data/library_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_library_repository.dart';

void main() {
  Future<_Harness> pumpSearch(
    WidgetTester tester, {
    required FakeBookRepository bookRepository,
    FakeLibraryRepository? libraryRepository,
    Stream<bool>? connectivity,
    String location = AppRoutes.homeLibrarySearch,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    bool settle = true,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(_FakeUser()),
        ),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(_user),
        ),
        bookRepositoryProvider.overrideWith((Ref ref) => bookRepository),
        libraryRepositoryProvider.overrideWith(
          (Ref ref) => libraryRepository ?? FakeLibraryRepository(),
        ),
        connectivityProvider.overrideWith(
          (Ref ref) => connectivity ?? Stream<bool>.value(true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _SearchTestApp(theme: theme ?? AppTheme.light),
      ),
    );
    router.go(location);

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _Harness(router: router, container: container);
  }

  Future<void> enterSearch(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Finder verticalScrollable() {
    return find.byWidgetPredicate(
      (Widget widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
  }

  testWidgets('Ikon pencarian di header Koleksi membuka layar pencarian', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSearch(
      tester,
      bookRepository: FakeBookRepository(),
      location: AppRoutes.homeLibrary,
    );

    final Size searchSize = tester.getSize(
      find.byTooltip(AppStrings.catalogSearchTitle),
    );
    expect(searchSize.width, greaterThanOrEqualTo(48));
    expect(searchSize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip(AppStrings.catalogSearchTitle));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrarySearch);
    expect(find.text(AppStrings.catalogSearchTitle), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
    final AppBottomNavBar navBar = tester.widget<AppBottomNavBar>(
      find.byType(AppBottomNavBar),
    );
    expect(navBar.selectedIndex, 1);
    expect(find.byType(EmptyView), findsOneWidget);
  });

  testWidgets('Tombol Cari Katalog pada Koleksi kosong membuka pencarian', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSearch(
      tester,
      bookRepository: FakeBookRepository(),
      libraryRepository: FakeLibraryRepository(),
      location: AppRoutes.homeLibrary,
    );

    expect(find.text(AppStrings.libraryEmptyTitle), findsOneWidget);
    await tester.tap(find.text(AppStrings.catalogSearchTitle));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrarySearch);
    expect(find.text(AppStrings.catalogSearchInitialTitle), findsOneWidget);
  });

  testWidgets('Tombol kembali mengembalikan pengguna ke Koleksi', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSearch(
      tester,
      bookRepository: FakeBookRepository(),
      location: AppRoutes.homeLibrary,
    );

    await tester.tap(find.byTooltip(AppStrings.catalogSearchTitle));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, AppRoutes.homeLibrarySearch);

    final Size backSize = tester.getSize(
      find.byTooltip(AppStrings.catalogSearchBack),
    );
    expect(backSize.width, greaterThanOrEqualTo(48));
    expect(backSize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip(AppStrings.catalogSearchBack));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrary);
    expect(find.text(AppStrings.libraryTitle), findsWidgets);
  });

  testWidgets('Keadaan awal memberi petunjuk dan kolom otomatis fokus', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository();
    await pumpSearch(tester, bookRepository: repository);

    expect(find.text(AppStrings.catalogSearchInitialTitle), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchInitialMessage), findsOneWidget);
    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);
    expect(repository.titleSearches, isEmpty);
    expect(repository.authorSearches, isEmpty);
    expect(repository.isbnSearches, isEmpty);

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.focusNode?.hasFocus, isTrue);
    expect(field.textInputAction, TextInputAction.search);
  });

  testWidgets(
    'Debounce 300 ms hanya menjalankan satu query untuk ketikan terakhir',
    (WidgetTester tester) async {
      final Book book = fakeBook(1, title: 'Bumi Manusia');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[book],
      );
      await pumpSearch(tester, bookRepository: repository);

      await tester.enterText(find.byType(TextField), 'b');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'bu');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'bum');
      await tester.pump(const Duration(milliseconds: 299));

      expect(repository.titleSearches, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(repository.titleSearches, <String>['bum']);
      expect(find.text(book.title), findsOneWidget);
    },
  );

  testWidgets('Kata kunci hanya spasi tidak menjalankan query', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository();
    await pumpSearch(tester, bookRepository: repository);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.titleSearches, isEmpty);
    expect(find.text(AppStrings.catalogSearchInitialTitle), findsOneWidget);
  });

  testWidgets('Aksi cari dari papan ketik langsung menjalankan query', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    await pumpSearch(tester, bookRepository: repository);

    await tester.enterText(find.byType(TextField), 'bumi');
    await tester.pump(const Duration(milliseconds: 50));
    expect(repository.titleSearches, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.titleSearches, <String>['bumi']);
    expect(find.text(book.title), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.titleSearches, hasLength(1));
  });

  testWidgets(
    'Tombol hapus mengosongkan kata kunci dan kembali ke petunjuk awal',
    (WidgetTester tester) async {
      final Book book = fakeBook(1, title: 'Bumi Manusia');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[book],
      );
      await pumpSearch(tester, bookRepository: repository);

      await enterSearch(tester, 'bumi');
      expect(find.text(book.title), findsOneWidget);
      expect(find.byTooltip(AppStrings.catalogSearchClear), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.catalogSearchClear));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(find.text(book.title), findsNothing);
      expect(find.text(AppStrings.catalogSearchInitialTitle), findsOneWidget);
      expect(find.text(AppStrings.catalogSearchInitialMessage), findsOneWidget);
      expect(repository.titleSearches, <String>['bumi']);
    },
  );

  testWidgets(
    'Tiga cakupan tersedia dan mengganti cakupan mempertahankan kata kunci',
    (WidgetTester tester) async {
      final Book titleBook = fakeBook(1, title: 'Bumi Manusia');
      final Book authorBook = fakeBook(
        2,
        title: 'Laskar Pelangi',
        author: 'Bumi Sakti',
      );
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[titleBook, authorBook],
      );
      await pumpSearch(tester, bookRepository: repository);

      expect(find.text(AppStrings.bookSearchScopeTitle), findsOneWidget);
      expect(find.text(AppStrings.bookSearchScopeAuthor), findsOneWidget);
      expect(find.text(AppStrings.bookSearchScopeIsbn), findsOneWidget);

      await enterSearch(tester, 'bumi');
      expect(find.text(titleBook.title), findsOneWidget);
      expect(find.text(authorBook.title), findsNothing);

      await tester.tap(find.text(AppStrings.bookSearchScopeAuthor));
      await tester.pumpAndSettle();

      expect(repository.authorSearches, <String>['bumi']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'bumi',
      );
      expect(find.text(authorBook.title), findsOneWidget);
      expect(find.text(titleBook.title), findsNothing);

      await tester.tap(find.text(AppStrings.bookSearchScopeIsbn));
      await tester.pumpAndSettle();

      expect(repository.isbnSearches, <String>['bumi']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'bumi',
      );
    },
  );

  testWidgets(
    'Pencarian ISBN menemukan buku yang sama meski input berformat lain',
    (WidgetTester tester) async {
      final Book book = fakeBook(1, title: 'Buku ISBN', isbn: '080442957X');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[book],
      );
      await pumpSearch(tester, bookRepository: repository);

      await tester.tap(find.text(AppStrings.bookSearchScopeIsbn));
      await tester.pumpAndSettle();
      await enterSearch(tester, '0-8044-2957-x');

      expect(repository.isbnSearches, <String>['0-8044-2957-x']);
      expect(find.text(book.title), findsOneWidget);
      expect(find.text(book.author), findsOneWidget);
    },
  );

  testWidgets('Muat Lebih Banyak mengambil halaman berikutnya', (
    WidgetTester tester,
  ) async {
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
    await pumpSearch(tester, bookRepository: repository);

    await enterSearch(tester, 'bumi');
    expect(find.text('Bumi 0'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(AppStrings.catalogSearchLoadMore),
      400,
      scrollable: verticalScrollable(),
    );
    await tester.tap(find.text(AppStrings.catalogSearchLoadMore));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Bumi 20'),
      400,
      scrollable: verticalScrollable(),
    );
    expect(find.text('Bumi 20'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Bumi 23'),
      200,
      scrollable: verticalScrollable(),
    );
    expect(find.text('Bumi 23'), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchLoadMore), findsNothing);
  });

  testWidgets(
    'Kegagalan muat lebih banyak mempertahankan hasil dan bisa dicoba lagi',
    (WidgetTester tester) async {
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
      await pumpSearch(tester, bookRepository: repository);

      await enterSearch(tester, 'bumi');
      repository.searchFailures['title:bumi'] = 1;

      await tester.scrollUntilVisible(
        find.text(AppStrings.catalogSearchLoadMore),
        400,
        scrollable: verticalScrollable(),
      );
      await tester.tap(find.text(AppStrings.catalogSearchLoadMore));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.catalogSearchLoadMoreError), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);

      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.catalogSearchLoadMoreError), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Bumi 20'),
        400,
        scrollable: verticalScrollable(),
      );
      expect(find.text('Bumi 20'), findsOneWidget);
    },
  );

  testWidgets('Loading hanya tampil saat query aktif', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final Completer<void> gate = Completer<void>();
    repository.searchGates['title:bumi'] = gate;
    await pumpSearch(tester, bookRepository: repository);

    expect(find.byType(LoadingView), findsNothing);
    expect(find.text(AppStrings.catalogSearchInitialTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bumi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchLoading), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchInitialTitle), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LoadingView), findsNothing);
    expect(find.text(book.title), findsOneWidget);
  });

  testWidgets('Pencarian kosong menampilkan pesan dan aksi menghapus', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[fakeBook(1, title: 'Bumi Manusia')],
    );
    await pumpSearch(tester, bookRepository: repository);

    await enterSearch(tester, 'tidak ada');

    expect(find.text(AppStrings.catalogSearchEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchInitialTitle), findsNothing);

    await tester.tap(find.text(AppStrings.catalogSearchClear));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.catalogSearchInitialTitle), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchEmptyTitle), findsNothing);
  });

  testWidgets(
    'Galat memakai pesan ramah, tanpa detail teknis, dan bisa dicoba lagi',
    (WidgetTester tester) async {
      final Book book = fakeBook(1, title: 'Bumi Manusia');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[book],
      )..searchError = StateError('detail internal tidak boleh tampil');
      await pumpSearch(tester, bookRepository: repository);

      await enterSearch(tester, 'bumi');

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text(AppStrings.catalogSearchError), findsOneWidget);
      expect(
        find.textContaining('detail internal tidak boleh tampil'),
        findsNothing,
      );

      repository.searchError = null;
      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsNothing);
      expect(find.text(book.title), findsOneWidget);
    },
  );

  testWidgets(
    'Offline tanpa cache menampilkan pesan offline, bukan loading tanpa akhir',
    (WidgetTester tester) async {
      final Book book = fakeBook(1, title: 'Bumi Manusia');
      final FakeBookRepository repository = FakeBookRepository();
      await pumpSearch(
        tester,
        bookRepository: repository,
        connectivity: Stream<bool>.value(false),
      );

      await enterSearch(tester, 'bumi');

      expect(find.text(AppStrings.catalogSearchOfflineTitle), findsOneWidget);
      expect(find.text(AppStrings.catalogSearchOfflineMessage), findsOneWidget);
      expect(find.byType(LoadingView), findsNothing);
      expect(find.text(AppStrings.retry), findsOneWidget);

      // Cache terisi setelah percobaan pertama; Coba Lagi memuat hasilnya.
      repository.allBooks.add(book);
      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();

      expect(find.text(book.title), findsOneWidget);
      expect(find.text(AppStrings.catalogSearchOfflineTitle), findsNothing);
    },
  );

  testWidgets('Hasil dari cache tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    await pumpSearch(
      tester,
      bookRepository: repository,
      connectivity: Stream<bool>.value(false),
    );

    await enterSearch(tester, 'bumi');

    expect(find.text(book.title), findsOneWidget);
    expect(find.text(AppStrings.catalogSearchOfflineTitle), findsNothing);
  });

  testWidgets('Mengetuk hasil membuka /book/:id', (WidgetTester tester) async {
    final Book book = fakeBook(7, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final _Harness harness = await pumpSearch(
      tester,
      bookRepository: repository,
    );

    await enterSearch(tester, 'bumi');
    await tester.tap(find.byKey(ValueKey<String>('catalog-search-${book.id}')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.bookDetailPath('book-7'));
    expect(find.text(AppStrings.bookDetailTitle), findsOneWidget);
  });

  for (final MapEntry<String, ThemeData> theme in <String, ThemeData>{
    'terang': AppTheme.light,
    'gelap': AppTheme.dark,
  }.entries) {
    for (final MapEntry<String, Size> size in <String, Size>{
      'ponsel': const Size(360, 800),
      'tablet': const Size(800, 1280),
    }.entries) {
      testWidgets(
        'Tampil tanpa overflow pada tema ${theme.key} ukuran ${size.key}',
        (WidgetTester tester) async {
          final Book book = fakeBook(
            1,
            title: 'Bumi Manusia yang Judulnya Cukup Panjang',
            author: 'Pramoedya Ananta Toer',
          );
          final FakeBookRepository repository = FakeBookRepository(
            books: <Book>[book],
          );
          await pumpSearch(
            tester,
            bookRepository: repository,
            viewSize: size.value,
            theme: theme.value,
          );

          expect(
            find.text(AppStrings.catalogSearchInitialTitle),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          await enterSearch(tester, 'bumi');

          expect(find.text(book.title), findsOneWidget);
          expect(find.text(book.author), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Harness {
  const _Harness({required this.router, required this.container});

  final GoRouter router;
  final ProviderContainer container;
}

class _SearchTestApp extends ConsumerWidget {
  const _SearchTestApp({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(theme: theme, routerConfig: router);
  }
}

final AppUser _user = AppUser(
  uid: 'u1',
  displayName: 'Pembaca',
  email: 'pembaca@libria.id',
  role: AppUser.roleUser,
);

class _FakeUser implements User {
  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
