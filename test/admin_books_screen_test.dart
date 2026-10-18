import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_router.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';
import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';

import 'support/fake_book_repository.dart';

void main() {
  Future<_Harness> pumpBooks(
    WidgetTester tester, {
    required FakeBookRepository repository,
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

    final _FakeAuthRepository auth = _FakeAuthRepository();
    addTearDown(auth.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((Ref ref) => auth),
        authStateProvider.overrideWith((Ref ref) => auth.authStateChanges),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(_adminUser),
        ),
        bookRepositoryProvider.overrideWith((Ref ref) => repository),
        adminDashboardRepositoryProvider.overrideWith(
          (Ref ref) => _FakeAdminDashboardRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _BooksTestApp(theme: theme ?? AppTheme.light),
      ),
    );
    router.go(AppRoutes.adminBooks);

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _Harness(router: router, repository: repository);
  }

  testWidgets('Menampilkan keadaan loading saat halaman pertama dimuat', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository();
    repository.fetchPageGate = Completer<void>();

    await pumpBooks(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.adminBooksLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.adminBooksEmptyTitle), findsNothing);

    repository.fetchPageGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminBooksLoading), findsNothing);
    expect(find.text(AppStrings.adminBooksEmptyTitle), findsOneWidget);
  });

  testWidgets('Menampilkan sampul, judul, penulis, dan ISBN tiap buku', (
    WidgetTester tester,
  ) async {
    final Book first = fakeBook(
      1,
      title: 'Bumi Manusia',
      author: 'Pramoedya Ananta Toer',
      isbn: '978-979-973-123-4',
    );
    final Book second = fakeBook(
      2,
      title: 'Laskar Pelangi',
      author: 'Andrea Hirata',
    );
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[first, second],
    );

    await pumpBooks(tester, repository: repository);

    expect(find.text(AppStrings.adminBooksTitle), findsOneWidget);
    expect(find.text(AppStrings.adminBooksAdd), findsOneWidget);
    expect(find.text(AppStrings.adminBooksSearchLabel), findsOneWidget);
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(first.author), findsOneWidget);
    expect(find.text(AppStrings.isbnLabel(first.isbn)), findsOneWidget);
    expect(find.text(second.title), findsOneWidget);
    expect(
      find.byTooltip(AppStrings.adminBooksDeleteTooltip(first.title)),
      findsOneWidget,
    );
    expect(
      find.byTooltip(AppStrings.adminBooksDeleteTooltip(second.title)),
      findsOneWidget,
    );
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('Muat Lebih Banyak menambah halaman tanpa duplikat dan hilang', (
    WidgetTester tester,
  ) async {
    final List<Book> firstPage = List<Book>.generate(
      20,
      (int index) => fakeBook(index),
    );
    final List<Book> secondPage = <Book>[
      firstPage.last,
      ...List<Book>.generate(4, (int index) => fakeBook(index + 20)),
    ];
    final FakeBookRepository repository = FakeBookRepository()
      ..pages = <List<Book>>[firstPage, secondPage];

    await pumpBooks(tester, repository: repository);

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminBooksLoadMore),
      400,
      scrollable: listScrollable,
    );

    expect(find.text(AppStrings.adminBooksLoadMore), findsOneWidget);
    expect(repository.fetchPageCalls, 1);

    await tester.tap(find.text(AppStrings.adminBooksLoadMore));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminBooksLoadMore), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Buku 23'),
      400,
      scrollable: listScrollable,
    );
    expect(find.text('Buku 23'), findsOneWidget);
  });

  testWidgets('Pencarian dijalankan setelah debounce 300 ms', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[fakeBook(1, title: 'Bumi Manusia')],
    );
    await pumpBooks(tester, repository: repository);

    final Finder searchField = find.byType(TextField);
    await tester.enterText(searchField, 'b');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(searchField, 'bu');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(searchField, 'bum');
    await tester.pump(const Duration(milliseconds: 299));

    expect(repository.titleSearches, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.titleSearches, <String>['bum']);
  });

  testWidgets(
    'Pencarian judul, penulis, dan ISBN memakai cakupan yang dipilih',
    (WidgetTester tester) async {
      final Book bumi = fakeBook(
        1,
        title: 'Bumi Manusia',
        author: 'Pramoedya Ananta Toer',
        isbn: '978-979-973-123-4',
      );
      final Book laskar = fakeBook(
        2,
        title: 'Laskar Pelangi',
        author: 'Andrea Hirata',
      );
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[bumi, laskar],
      );
      await pumpBooks(tester, repository: repository);

      await tester.enterText(find.byType(TextField), 'bumi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repository.titleSearches, <String>['bumi']);
      expect(find.text(bumi.title), findsOneWidget);
      expect(find.text(laskar.title), findsNothing);

      await tester.tap(find.text(AppStrings.adminBooksSearchScopeAuthor));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pram');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repository.authorSearches.last, 'pram');
      expect(find.text(bumi.title), findsOneWidget);
      expect(find.text(laskar.title), findsNothing);

      await tester.tap(find.text(AppStrings.adminBooksSearchScopeIsbn).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '978-979');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repository.isbnSearches.last, '978-979');
      expect(find.text(bumi.title), findsOneWidget);
      expect(find.text(laskar.title), findsNothing);
    },
  );

  testWidgets('Mengosongkan pencarian mengembalikan daftar lengkap', (
    WidgetTester tester,
  ) async {
    final Book bumi = fakeBook(1, title: 'Bumi Manusia');
    final Book laskar = fakeBook(2, title: 'Laskar Pelangi');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[bumi, laskar],
    );
    await pumpBooks(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'bumi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text(laskar.title), findsNothing);

    await tester.tap(find.byTooltip(AppStrings.adminBooksClearSearch));
    await tester.pumpAndSettle();

    expect(find.text(bumi.title), findsOneWidget);
    expect(find.text(laskar.title), findsOneWidget);
    expect(find.byTooltip(AppStrings.adminBooksClearSearch), findsNothing);
  });

  testWidgets('Pencarian tanpa hasil menampilkan pesan kosong pencarian', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[fakeBook(1, title: 'Bumi Manusia')],
    );
    await pumpBooks(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'tidak ada');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminBooksEmptySearchTitle), findsOneWidget);
    expect(find.text(AppStrings.adminBooksEmptySearchMessage), findsOneWidget);

    await tester.tap(find.text(AppStrings.adminBooksClearSearch));
    await tester.pumpAndSettle();
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text(AppStrings.adminBooksEmptySearchTitle), findsNothing);
  });

  testWidgets('Daftar kosong menampilkan ajakan menambah buku', (
    WidgetTester tester,
  ) async {
    await pumpBooks(tester, repository: FakeBookRepository());

    expect(find.text(AppStrings.adminBooksEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.adminBooksEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.adminBooksEmptySearchTitle), findsNothing);
  });

  testWidgets('Galat menampilkan pesan ramah dan Coba Lagi memuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[fakeBook(1, title: 'Bumi Manusia')],
    )..fetchPageFailuresRemaining = 1;
    await pumpBooks(tester, repository: repository);

    expect(find.text(AppStrings.adminBooksLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsNothing);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminBooksLoadError), findsNothing);
    expect(find.text('Bumi Manusia'), findsOneWidget);
  });

  testWidgets('Tombol tambah dan ketuk baris membuka rute formulir', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final _Harness harness = await pumpBooks(
      tester,
      repository: FakeBookRepository(books: <Book>[book]),
    );

    await tester.tap(find.text(AppStrings.adminBooksAdd));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminBookNew);
    expect(find.text(AppStrings.adminBookNewTitle), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(book.title));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminBookEditPath(book.id));
    expect(find.text(AppStrings.adminBookEditTitle), findsOneWidget);
  });

  testWidgets('Batal pada dialog hapus tidak mengubah apa pun', (
    WidgetTester tester,
  ) async {
    final Book first = fakeBook(1, title: 'Buku Pertama');
    final Book second = fakeBook(2, title: 'Buku Kedua');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[first, second],
    );
    final _Harness harness = await pumpBooks(tester, repository: repository);

    await tester.tap(
      find.byTooltip(AppStrings.adminBooksDeleteTooltip(first.title)),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminBooksDeleteDialogTitle), findsOneWidget);
    expect(
      find.text(AppStrings.adminBooksDeleteDialogMessage(first.title)),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(find.text(first.title), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.adminBooks);
  });

  testWidgets(
    'Konfirmasi hapus membuang baris tanpa meninggalkan layar dan mencegah ketukan ganda',
    (WidgetTester tester) async {
      final Book first = fakeBook(1, title: 'Buku Pertama');
      final Book second = fakeBook(2, title: 'Buku Kedua');
      final FakeBookRepository repository = FakeBookRepository(
        books: <Book>[first, second],
      );
      final Completer<void> deleteGate = Completer<void>();
      repository.deleteGate = deleteGate;
      final _Harness harness = await pumpBooks(tester, repository: repository);

      await tester.tap(
        find.byTooltip(AppStrings.adminBooksDeleteTooltip(first.title)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.adminBooksDeleteConfirm));
      await tester.pump();
      await tester.pump();

      expect(repository.deleteCalls, 1);
      expect(
        find.byTooltip(AppStrings.adminBooksDeleteTooltip(first.title)),
        findsNothing,
      );
      expect(
        find.byTooltip(AppStrings.adminBooksDeleteTooltip(second.title)),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      deleteGate.complete();
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, 1);
      expect(find.text(first.title), findsNothing);
      expect(find.text(second.title), findsOneWidget);
      expect(find.text(AppStrings.adminBooksDeleteSuccess), findsOneWidget);
      expect(harness.router.state.uri.path, AppRoutes.adminBooks);
    },
  );

  testWidgets('Kegagalan hapus menampilkan pesan ramah dan baris tetap ada', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    )..deleteError = StateError('gagal menghapus');
    final _Harness harness = await pumpBooks(tester, repository: repository);

    await tester.tap(
      find.byTooltip(AppStrings.adminBooksDeleteTooltip(book.title)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adminBooksDeleteConfirm));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text(AppStrings.adminBooksDeleteError), findsOneWidget);
    expect(find.text(book.title), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.adminBooks);
  });

  testWidgets('Hapus pada hasil pencarian menampilkan keadaan kosong', (
    WidgetTester tester,
  ) async {
    final Book first = fakeBook(1, title: 'Buku Pertama');
    final Book second = fakeBook(2, title: 'Buku Kedua');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[first, second],
    );
    await pumpBooks(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'buku pert');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text(second.title), findsNothing);

    await tester.tap(
      find.byTooltip(AppStrings.adminBooksDeleteTooltip(first.title)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adminBooksDeleteConfirm));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text(first.title), findsNothing);
    expect(find.text(AppStrings.adminBooksEmptySearchTitle), findsOneWidget);
  });

  final List<Size> responsiveSizes = <Size>[
    const Size(360, 800),
    const Size(640, 360),
    const Size(800, 1280),
    const Size(1280, 800),
  ];

  for (final Size size in responsiveSizes) {
    testWidgets(
      'Daftar buku muat pada ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        final FakeBookRepository repository = FakeBookRepository(
          books: <Book>[fakeBook(1), fakeBook(2), fakeBook(3)],
        );

        await pumpBooks(
          tester,
          repository: repository,
          viewSize: size,
          theme: size.width >= 600 ? AppTheme.dark : AppTheme.light,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.adminBooksTitle), findsOneWidget);
        expect(find.text(AppStrings.adminBooksAdd), findsOneWidget);
        expect(find.text(AppStrings.adminBooksSearchLabel), findsOneWidget);
        expect(find.byType(AppBottomNavBar), findsOneWidget);
      },
    );
  }
}

const AppUser _adminUser = AppUser(
  uid: 'admin-1',
  displayName: 'Admin Libria',
  email: 'admin@libria.id',
  role: AppUser.roleAdmin,
);

class _Harness {
  const _Harness({required this.router, required this.repository});

  final GoRouter router;
  final FakeBookRepository repository;
}

class _BooksTestApp extends ConsumerWidget {
  const _BooksTestApp({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(theme: theme, routerConfig: router);
  }
}

class _FakeAdminDashboardRepository implements AdminDashboardRepository {
  @override
  Future<AdminDashboardStats> fetchStats() async {
    return const AdminDashboardStats(
      totalBooks: 0,
      openReports: 0,
      unhandledIsbnLogs: 0,
      totalUsers: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  final StreamController<User?> _authState = StreamController<User?>();

  _FakeAuthRepository() {
    _authState.add(_FakeUser());
  }

  @override
  User? currentUser = _FakeUser();

  @override
  Stream<User?> get authStateChanges => _authState.stream;

  Future<void> dispose() => _authState.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
