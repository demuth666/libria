import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_router.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';
import 'package:libria/core/widgets/book_cover_image.dart';
import 'package:libria/core/widgets/empty_view.dart';
import 'package:libria/core/widgets/error_view.dart';
import 'package:libria/core/widgets/loading_view.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/session/data/session_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_library_repository.dart';
import 'support/fake_session_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpDetail(
    WidgetTester tester, {
    required FakeBookRepository bookRepository,
    FakeLibraryRepository? libraryRepository,
    FakeSessionRepository? sessionRepository,
    Stream<bool>? connectivity,
    String? location,
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

    final FakeLibraryRepository library =
        libraryRepository ?? FakeLibraryRepository();
    final FakeSessionRepository sessionHistory =
        sessionRepository ?? FakeSessionRepository();
    addTearDown(sessionHistory.dispose);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(_FakeUser()),
        ),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(_user),
        ),
        bookRepositoryProvider.overrideWith((Ref ref) => bookRepository),
        libraryRepositoryProvider.overrideWith((Ref ref) => library),
        sessionRepositoryProvider.overrideWithValue(sessionHistory),
        connectivityProvider.overrideWith(
          (Ref ref) => connectivity ?? Stream<bool>.value(true),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Samakan dengan aplikasi yang memasang OfflineBannerHost di akar widget:
    // status koneksi sudah diketahui sebelum layar detail dibaca.
    final ProviderSubscription<AsyncValue<bool>> connectivitySubscription =
        container.listen<AsyncValue<bool>>(
          connectivityProvider,
          (AsyncValue<bool>? previous, AsyncValue<bool> next) {},
          fireImmediately: true,
        );
    addTearDown(connectivitySubscription.close);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _DetailTestApp(theme: theme ?? AppTheme.light),
      ),
    );
    // Biarkan status koneksi terlebih dahulu agar provider detail memilih
    // sumber server atau cache dengan benar sejak awal.
    await tester.pump();
    router.go(location ?? AppRoutes.bookDetailPath('book-1'));

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _Harness(router: router, container: container);
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> savePage(WidgetTester tester, String value) async {
    final Finder field = find.byType(TextField);
    await scrollTo(tester, field);
    await tester.enterText(field, value);
    await tester.pump();
    final Finder button = find.byKey(
      const ValueKey<String>('book-detail-save-page'),
    );
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> tapStatus(WidgetTester tester, String status) async {
    final Finder chip = find.byKey(
      ValueKey<String>('book-detail-status-$status'),
    );
    await scrollTo(tester, chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('Menampilkan sampul dan seluruh metadata buku', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
    );

    expect(find.text(AppStrings.bookDetailTitle), findsOneWidget);
    expect(find.text(book.title), findsOneWidget);
    expect(
      find.text(AppStrings.bookDetailByAuthor(book.author)),
      findsOneWidget,
    );
    expect(find.text(book.isbn), findsOneWidget);
    expect(find.text(book.publisher), findsOneWidget);
    expect(find.text('${book.year}'), findsOneWidget);
    expect(find.text('${book.totalPages}'), findsOneWidget);
    expect(find.text(book.category), findsOneWidget);
    expect(find.text(book.synopsis), findsOneWidget);
    expect(find.text(AppStrings.bookDetailSectionDetails), findsOneWidget);
    expect(find.text(AppStrings.bookDetailSectionSynopsis), findsOneWidget);

    final BookCoverImage cover = tester.widget<BookCoverImage>(
      find.byType(BookCoverImage),
    );
    expect(cover.requestWidth, BookCoverWidth.detail);
    expect(find.byType(AppBottomNavBar), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('book-detail-start-session')),
      findsOneWidget,
    );
  });

  testWidgets('Nilai metadata kosong tampil sebagai Belum tersedia', (
    WidgetTester tester,
  ) async {
    final Book book = _book(
      author: '',
      isbn: '',
      publisher: '',
      year: 0,
      category: '',
      synopsis: '',
    );
    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.bookDetailUnavailable), findsWidgets);
    expect(find.text(AppStrings.bookDetailByAuthor('')), findsNothing);
  });

  testWidgets('Menampilkan loading sampai buku selesai dimuat', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final Completer<void> gate = Completer<void>();
    repository.getByIdGate = gate;

    await pumpDetail(tester, bookRepository: repository, settle: false);

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(AppStrings.bookDetailLoading), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text(book.title), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);
  });

  testWidgets('Buku tidak ditemukan menampilkan pesan dan jalan kembali', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(),
    );

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text(AppStrings.bookDetailNotFoundTitle), findsOneWidget);
    expect(find.text(AppStrings.bookDetailNotFoundMessage), findsOneWidget);
    expect(find.text(AppStrings.bookDetailBack), findsOneWidget);

    await tester.tap(find.text(AppStrings.bookDetailBack));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrary);
  });

  testWidgets('Galat pemuatan memakai pesan ramah dan Coba Lagi memuat ulang', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    )..getByIdFailuresRemaining = 1;

    await pumpDetail(tester, bookRepository: repository);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text(AppStrings.bookDetailLoadError), findsOneWidget);
    expect(find.textContaining('detail internal'), findsNothing);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(book.title), findsOneWidget);
    expect(repository.getByIdCalls, 2);
  });

  testWidgets('Offline tanpa cache menampilkan keadaan offline dan bisa '
      'dicoba lagi', (WidgetTester tester) async {
    final Book book = _book();
    final FakeBookRepository repository = FakeBookRepository();

    await pumpDetail(
      tester,
      bookRepository: repository,
      connectivity: Stream<bool>.value(false),
    );

    expect(find.text(AppStrings.bookDetailOfflineTitle), findsOneWidget);
    expect(find.text(AppStrings.bookDetailOfflineMessage), findsOneWidget);
    expect(find.text(AppStrings.bookDetailNotFoundTitle), findsNothing);
    expect(find.byType(LoadingView), findsNothing);

    repository.allBooks.add(book);
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(book.title), findsOneWidget);
    expect(repository.getByIdSources.last, BookSearchSource.cacheOnly);
  });

  testWidgets('Buku dari cache tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );

    await pumpDetail(
      tester,
      bookRepository: repository,
      connectivity: Stream<bool>.value(false),
    );

    expect(find.text(book.title), findsOneWidget);
    expect(find.text(AppStrings.bookDetailOfflineTitle), findsNothing);
    expect(repository.getByIdSources, <BookSearchSource>[
      BookSearchSource.cacheOnly,
    ]);
  });

  testWidgets('Data rak dari cache tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 80,
          totalPages: book.totalPages,
        ),
      ],
    );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
      connectivity: Stream<bool>.value(false),
    );

    expect(find.text(book.title), findsOneWidget);
    expect(find.text(AppStrings.percentDone(25)), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('book-detail-status-reading')),
      findsOneWidget,
    );
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('Perubahan koneksi mempertahankan data dan isian halaman', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 10,
          totalPages: book.totalPages,
        ),
      ],
    );
    final StreamController<bool> connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    connectivity.add(true);

    await pumpDetail(
      tester,
      bookRepository: repository,
      libraryRepository: library,
      connectivity: connectivity.stream,
    );

    final Finder field = find.byType(TextField);
    await scrollTo(tester, field);
    await tester.enterText(field, '150');
    await tester.pump();

    final Completer<void> gate = Completer<void>();
    repository.getByIdGate = gate;
    connectivity.add(false);
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingView), findsNothing);
    expect(find.text(book.title), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '150',
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text(book.title), findsOneWidget);
  });

  testWidgets('Membuka detail dari Koleksi lalu kembali ke layar asal', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(1, title: book.title, author: book.author),
      ],
    );
    final _Harness harness = await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
      location: AppRoutes.homeLibrary,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('library-reading-book-1')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.bookDetailPath('book-1'));
    expect(find.text(book.synopsis), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-back')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrary);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('Membuka detail dari hasil pencarian lalu kembali ke pencarian', (
    WidgetTester tester,
  ) async {
    final Book book = _book(title: 'Bumi Manusia');
    final _Harness harness = await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      location: AppRoutes.homeLibrarySearch,
    );

    await tester.enterText(find.byType(TextField), 'bumi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey<String>('catalog-search-${book.id}')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.bookDetailPath(book.id));

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-back')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrarySearch);
    expect(find.text(book.title), findsOneWidget);
  });

  testWidgets('Tombol Mulai Sesi membuka /session/setup dengan ID buku', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final _Harness harness = await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('book-detail-start-session')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.sessionSetup);
    expect(
      harness.router.state.uri.queryParameters[AppRoutes
          .sessionSetupBookIdParam],
      book.id,
    );
    expect(find.text(AppStrings.sessionSetupTitle), findsOneWidget);
  });

  testWidgets('Menambah buku ke rak menulis sekali dan menampilkan status', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository();

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-add')));
    await tester.pumpAndSettle();

    expect(library.addBookCalls, 1);
    expect(library.addedBooks.single.id, book.id);
    expect(library.requestedStatuses, <String>[LibraryEntry.statusWant]);
    expect(library.entryFor(book.id)?.status, LibraryEntry.statusWant);
    expect(find.byKey(const ValueKey<String>('book-detail-add')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('book-detail-status-want')),
      findsOneWidget,
    );
  });

  testWidgets('Buku yang ditambahkan langsung muncul di segmen Ingin Dibaca', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository();
    final _Harness harness = await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-back')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrary);
    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-want')),
    );
    await tester.pumpAndSettle();

    expect(find.text(book.title), findsOneWidget);
  });

  testWidgets('Mengetuk tambah dua kali saat menyimpan hanya menulis sekali', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository();
    final Completer<void> gate = Completer<void>();
    library.addBookGate = gate;

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('book-detail-add')));
    await tester.pump();

    expect(library.addBookCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(library.addBookCalls, 1);
    expect(
      find.byKey(const ValueKey<String>('book-detail-status-want')),
      findsOneWidget,
    );
  });

  testWidgets('Mengetuk status dua kali saat menyimpan hanya menulis sekali', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 80,
          totalPages: book.totalPages,
        ),
      ],
    );
    final Completer<void> gate = Completer<void>();
    library.updateStatusGate = gate;

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    final Finder finished = find.byKey(
      const ValueKey<String>('book-detail-status-finished'),
    );
    await scrollTo(tester, finished);
    await tester.tap(finished);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('book-detail-status-want')),
    );
    await tester.pump();

    expect(library.updateStatusCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(library.updateStatusCalls, 1);
    expect(library.entryFor(book.id)?.status, LibraryEntry.statusFinished);
  });

  testWidgets('Mengetuk simpan halaman dua kali saat menyimpan hanya menulis '
      'sekali', (WidgetTester tester) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 10,
          totalPages: book.totalPages,
        ),
      ],
    );
    final Completer<void> gate = Completer<void>();
    library.updateCurrentPageGate = gate;

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    final Finder field = find.byType(TextField);
    await scrollTo(tester, field);
    await tester.enterText(field, '150');
    await tester.pump();
    final Finder button = find.byKey(
      const ValueKey<String>('book-detail-save-page'),
    );
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(library.updateCurrentPageCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(library.updateCurrentPageCalls, 1);
    expect(library.entryFor(book.id)?.currentPage, 150);
  });

  testWidgets('Buku yang sudah ada di rak menampilkan status dan halaman', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 80,
          totalPages: book.totalPages,
        ),
      ],
    );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    expect(find.byKey(const ValueKey<String>('book-detail-add')), findsNothing);
    expect(find.text(AppStrings.percentDone(25)), findsOneWidget);
    expect(
      find.text(AppStrings.pagesRead(80, book.totalPages)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('book-detail-status-reading')),
      findsOneWidget,
    );
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '80');
  });

  testWidgets('Mengubah status ke Selesai mengisi tanggal dan status lain '
      'mengosongkannya', (WidgetTester tester) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 80,
          totalPages: book.totalPages,
        ),
      ],
    );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await tapStatus(tester, 'finished');

    expect(library.updateStatusCalls, 1);
    expect(library.requestedStatuses.last, LibraryEntry.statusFinished);
    expect(library.entryFor(book.id)?.finishedAt, isNotNull);
    expect(
      find.text(
        AppStrings.libraryFinishedOn(
          AppDateFormatter.date(library.entryFor(book.id)!.finishedAt!),
        ),
      ),
      findsOneWidget,
    );

    await tapStatus(tester, 'want');

    expect(library.requestedStatuses.last, LibraryEntry.statusWant);
    expect(library.entryFor(book.id)?.finishedAt, isNull);
    final ChoiceChip wantChip = tester.widget<ChoiceChip>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('book-detail-status-want')),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(wantChip.selected, isTrue);
  });

  testWidgets('Halaman terakhir yang valid tersimpan dan progres diperbarui', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 10,
          totalPages: book.totalPages,
        ),
      ],
    );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await savePage(tester, '150');

    expect(library.updateCurrentPageCalls, 1);
    expect(library.requestedPages, <int>[150]);
    expect(library.entryFor(book.id)?.currentPage, 150);
    expect(find.text(AppStrings.percentDone(47)), findsOneWidget);
    expect(
      find.text(AppStrings.pagesRead(150, book.totalPages)),
      findsOneWidget,
    );
  });

  testWidgets('Halaman di luar 0 sampai total ditolak dengan pesan ramah', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 10,
          totalPages: book.totalPages,
        ),
      ],
    );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await savePage(tester, '');
    expect(find.text(AppStrings.bookDetailPageRequired), findsOneWidget);

    await savePage(tester, 'abc');
    expect(find.text(AppStrings.bookDetailPageInvalid), findsOneWidget);

    await savePage(tester, '-1');
    expect(find.text(AppStrings.bookDetailPageNegative), findsOneWidget);

    await savePage(tester, '${book.totalPages + 1}');
    expect(
      find.text(AppStrings.bookDetailPageExceeds(book.totalPages)),
      findsOneWidget,
    );

    expect(library.updateCurrentPageCalls, 0);
  });

  testWidgets('Halaman sama dengan total otomatis Selesai dan Koleksi ikut '
      'berubah', (WidgetTester tester) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 10,
          totalPages: book.totalPages,
        ),
      ],
    );
    final _Harness harness = await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
      location: AppRoutes.homeLibrary,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('library-reading-book-1')),
    );
    await tester.pumpAndSettle();

    await savePage(tester, '${book.totalPages}');

    expect(library.entryFor(book.id)?.currentPage, book.totalPages);
    expect(library.entryFor(book.id)?.status, LibraryEntry.statusFinished);
    expect(library.entryFor(book.id)?.finishedAt, isNotNull);
    expect(find.text(AppStrings.percentDone(100)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-back')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.homeLibrary);
    expect(find.text(AppStrings.libraryEmptyReadingTitle), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-finished')),
    );
    await tester.pumpAndSettle();

    expect(find.text(book.title), findsOneWidget);
  });

  testWidgets('Total halaman 0 tidak menawarkan input halaman', (
    WidgetTester tester,
  ) async {
    final Book book = _book(totalPages: 0);
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          author: book.author,
          currentPage: 0,
          totalPages: 0,
        ),
      ],
    );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(AppStrings.bookDetailPageUnavailable), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('book-detail-save-page')),
      findsNothing,
    );
  });

  testWidgets('Kegagalan tambah menampilkan pesan ramah dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository()
      ..addBookError = const LibraryFailure(AppStrings.libraryAddNetworkError);

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-add')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.libraryAddNetworkError), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('book-detail-add')),
      findsOneWidget,
    );
    expect(library.entryFor(book.id), isNull);

    library.addBookError = null;
    await tester.tap(find.byKey(const ValueKey<String>('book-detail-add')));
    await tester.pumpAndSettle();

    expect(library.addBookCalls, 2);
    expect(library.entryFor(book.id)?.status, LibraryEntry.statusWant);
  });

  testWidgets('Kegagalan tulis saat offline dijelaskan dengan pesan ramah', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library = FakeLibraryRepository()
      ..addBookError = const LibraryFailure(AppStrings.libraryAddNetworkError);

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
      connectivity: Stream<bool>.value(false),
    );

    await tester.tap(find.byKey(const ValueKey<String>('book-detail-add')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.libraryAddNetworkError), findsOneWidget);
    expect(library.entryFor(book.id), isNull);
  });

  testWidgets('Kegagalan status mempertahankan data terakhir dan pesan ramah', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeLibraryRepository library =
        FakeLibraryRepository(
            entries: <LibraryEntry>[
              fakeLibraryEntry(
                1,
                title: book.title,
                author: book.author,
                currentPage: 80,
                totalPages: book.totalPages,
              ),
            ],
          )
          ..updateStatusError = const LibraryFailure(
            AppStrings.libraryStatusNetworkError,
          );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await tapStatus(tester, 'finished');

    expect(find.text(AppStrings.libraryStatusNetworkError), findsOneWidget);
    expect(library.entryFor(book.id)?.status, LibraryEntry.statusReading);
    expect(find.text(AppStrings.percentDone(25)), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('book-detail-status-reading')),
      findsOneWidget,
    );
  });

  testWidgets('Kegagalan menyimpan halaman menampilkan pesan ramah dan data '
      'terakhir tetap tampil', (WidgetTester tester) async {
    final Book book = _book();
    final FakeLibraryRepository library =
        FakeLibraryRepository(
            entries: <LibraryEntry>[
              fakeLibraryEntry(
                1,
                title: book.title,
                author: book.author,
                currentPage: 80,
                totalPages: book.totalPages,
              ),
            ],
          )
          ..updateCurrentPageError = const LibraryFailure(
            AppStrings.libraryPageNetworkError,
          );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      libraryRepository: library,
    );

    await savePage(tester, '150');

    expect(find.text(AppStrings.libraryPageNetworkError), findsOneWidget);
    expect(library.entryFor(book.id)?.currentPage, 80);
    expect(
      find.text(AppStrings.pagesRead(80, book.totalPages)),
      findsOneWidget,
    );
  });

  testWidgets('Menampilkan riwayat sesi buku terbaru lebih dulu', (
    WidgetTester tester,
  ) async {
    final Book book = _book();
    final FakeSessionRepository sessions = FakeSessionRepository();
    sessions.sessions.addAll(<ReadingSession>[
      _readingSession(
        id: 'old',
        startedAt: DateTime(2026, 10, 22, 20, 15),
        durationSeconds: 15 * 60,
        startPage: 10,
        endPage: 30,
      ),
      _readingSession(
        id: 'new',
        startedAt: DateTime(2026, 10, 23, 9),
        durationSeconds: 25 * 60,
        startPage: 30,
        endPage: 75,
        targetSeconds: 25 * 60,
        targetReached: true,
      ),
      _readingSession(
        id: 'other-book',
        bookId: 'book-2',
        bookTitle: 'Buku Lain',
        startedAt: DateTime(2026, 10, 23, 12),
      ),
    ]);

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      sessionRepository: sessions,
    );

    await scrollTo(tester, find.text(AppStrings.sessionHistoryTitle));

    expect(sessions.lastBookId, book.id);
    expect(find.text(AppStrings.sessionHistoryTitle), findsOneWidget);
    expect(
      find.text(AppDateFormatter.dateTime(DateTime(2026, 10, 23, 9))),
      findsOneWidget,
    );
    expect(
      find.text(AppDateFormatter.dateTime(DateTime(2026, 10, 22, 20, 15))),
      findsOneWidget,
    );
    expect(find.text('00:25:00'), findsOneWidget);
    expect(find.text('00:15:00'), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryPages(30, 75)), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryPages(10, 30)), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishTargetReached), findsOneWidget);
    expect(find.text('Buku Lain'), findsNothing);
  });

  testWidgets('Riwayat sesi kosong menampilkan ajakan menyelesaikan sesi', (
    WidgetTester tester,
  ) async {
    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[_book()]),
    );

    await scrollTo(tester, find.text(AppStrings.sessionHistoryTitle));

    expect(
      find.text(AppStrings.sessionHistoryBookEmptyMessage),
      findsOneWidget,
    );
  });

  testWidgets('Riwayat sesi cache tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final ReadingSession session = _readingSession(
      id: 'cached',
      startedAt: DateTime(2026, 10, 23, 9),
      durationSeconds: 20 * 60,
      startPage: 40,
      endPage: 60,
    );
    final FakeSessionRepository sessions = FakeSessionRepository();
    sessions.sessions.add(session);

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[_book()]),
      sessionRepository: sessions,
      connectivity: Stream<bool>.value(false),
    );

    await scrollTo(tester, find.text(AppStrings.sessionHistoryTitle));

    expect(find.text('00:20:00'), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryPages(40, 60)), findsOneWidget);
    expect(
      find.text(AppStrings.sessionHistoryBookOfflineMessage),
      findsNothing,
    );
  });

  testWidgets('Galat riwayat sesi memakai pesan ramah dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository sessions = FakeSessionRepository();
    sessions.readError = const SessionFailure(
      AppStrings.sessionHistoryNetworkError,
    );

    await pumpDetail(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[_book()]),
      sessionRepository: sessions,
    );

    await scrollTo(tester, find.text(AppStrings.sessionHistoryTitle));

    expect(find.text(AppStrings.sessionHistoryNetworkError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    sessions.readError = null;
    sessions.sessions.add(
      _readingSession(
        id: 'after-retry',
        startedAt: DateTime(2026, 10, 23, 9),
        durationSeconds: 10 * 60,
      ),
    );
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('00:10:00'), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryNetworkError), findsNothing);
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
          final Book book = _book(
            title: 'Bumi Manusia yang Judulnya Cukup Panjang',
            author: 'Pramoedya Ananta Toer',
          );
          final FakeLibraryRepository library = FakeLibraryRepository(
            entries: <LibraryEntry>[
              fakeLibraryEntry(
                1,
                title: book.title,
                author: book.author,
                currentPage: 80,
                totalPages: book.totalPages,
              ),
            ],
          );

          await pumpDetail(
            tester,
            bookRepository: FakeBookRepository(books: <Book>[book]),
            libraryRepository: library,
            viewSize: size.value,
            theme: theme.value,
          );

          expect(find.text(book.title), findsOneWidget);
          expect(
            find.text(AppStrings.bookDetailSectionDetails),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          await scrollTo(
            tester,
            find.byKey(const ValueKey<String>('book-detail-save-page')),
          );
          expect(find.byType(TextField), findsOneWidget);
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

class _DetailTestApp extends ConsumerWidget {
  const _DetailTestApp({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(theme: theme, routerConfig: router);
  }
}

ReadingSession _readingSession({
  required String id,
  String bookId = 'book-1',
  String bookTitle = 'Bumi Manusia',
  DateTime? startedAt,
  int durationSeconds = 20 * 60,
  int targetSeconds = 30 * 60,
  int startPage = 40,
  int endPage = 75,
  bool targetReached = false,
}) {
  return ReadingSession(
    id: id,
    bookId: bookId,
    bookTitle: bookTitle,
    startedAt: startedAt ?? DateTime(2026, 10, 23, 9),
    endedAt: (startedAt ?? DateTime(2026, 10, 23, 9)).add(
      Duration(seconds: durationSeconds),
    ),
    durationSeconds: durationSeconds,
    targetSeconds: targetSeconds,
    startPage: startPage,
    endPage: endPage,
    targetReached: targetReached,
  );
}

Book _book({
  String title = 'Bumi Manusia',
  String author = 'Pramoedya Ananta Toer',
  String isbn = '9789799731234',
  String publisher = 'Lentera Dipantara',
  int year = 1980,
  int totalPages = 320,
  String category = 'Fiksi',
  String synopsis = 'Kisah Minke dan perjalanan hidupnya di masa kolonial.',
}) {
  return Book(
    id: 'book-1',
    title: title,
    author: author,
    isbn: isbn,
    publisher: publisher,
    year: year,
    totalPages: totalPages,
    category: category,
    synopsis: synopsis,
    createdBy: 'admin-1',
  );
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
