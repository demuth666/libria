import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/active_session_repository.dart';
import 'package:libria/features/session/data/session_alarm_service.dart';
import 'package:libria/features/session/data/session_background_service.dart';
import 'package:libria/features/session/presentation/active_session_providers.dart';
import 'package:libria/features/session/presentation/session_setup_screen.dart';

import 'support/fake_active_session_repository.dart';
import 'support/fake_book_repository.dart';
import 'support/fake_library_repository.dart';
import 'support/fake_session_alarm_service.dart';
import 'support/fake_session_background_service.dart';

void main() {
  Future<_SetupHarness> pumpSetup(
    WidgetTester tester, {
    List<LibraryEntry>? entries,
    List<Book>? catalogBooks,
    Book? scanBook,
    String? initialBookId,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    Stream<bool>? connectivity,
    FakeLibraryRepository? libraryRepository,
    FakeBookRepository? bookRepository,
    FakeActiveSessionRepository? activeSessionRepository,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeLibraryRepository library =
        libraryRepository ??
        FakeLibraryRepository(entries: entries ?? <LibraryEntry>[]);
    final FakeBookRepository books =
        bookRepository ?? FakeBookRepository(books: catalogBooks ?? <Book>[]);
    final FakeActiveSessionRepository sessions =
        activeSessionRepository ?? FakeActiveSessionRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(library),
        bookRepositoryProvider.overrideWithValue(books),
        activeSessionRepositoryProvider.overrideWithValue(sessions),
        sessionBackgroundServiceProvider.overrideWithValue(
          FakeSessionBackgroundService(),
        ),
        sessionAlarmServiceProvider.overrideWithValue(
          FakeSessionAlarmService(),
        ),
        connectivityProvider.overrideWith(
          (Ref ref) => connectivity ?? Stream<bool>.value(true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: initialBookId == null
          ? AppRoutes.sessionSetup
          : AppRoutes.sessionSetupPath(initialBookId),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.sessionSetup,
          builder: (BuildContext context, GoRouterState state) =>
              SessionSetupScreen(
                initialBookId: state
                    .uri
                    .queryParameters[AppRoutes.sessionSetupBookIdParam],
              ),
        ),
        GoRoute(
          path: AppRoutes.sessionRun,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('session-run-test'))),
        ),
        GoRoute(
          path: AppRoutes.isbnScan,
          builder: (BuildContext context, GoRouterState state) =>
              _FakeScannerScreen(book: scanBook ?? fakeBook(99)),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-test'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    return _SetupHarness(
      container: container,
      router: router,
      library: library,
      sessions: sessions,
    );
  }

  testWidgets('Memulai sesi dari koleksi tanpa menambah buku lagi', (
    WidgetTester tester,
  ) async {
    final LibraryEntry entry = fakeLibraryEntry(
      1,
      title: 'Bumi Manusia',
      author: 'Pramoedya Ananta Toer',
      status: LibraryEntry.statusReading,
    );
    final _SetupHarness harness = await pumpSetup(
      tester,
      entries: <LibraryEntry>[entry],
    );

    expect(find.text(AppStrings.sessionSetupTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionSetupNoBookTitle), findsOneWidget);
    expect(find.text(entry.bookTitle), findsOneWidget);
    expect(find.text(entry.bookAuthor), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('session-setup-book-book-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionSetupNoBookTitle), findsNothing);
    expect(
      find.text(
        AppStrings.sessionSetupShelfStatus(AppStrings.librarySegmentReading),
      ),
      findsWidgets,
    );

    await tester.enterText(find.byType(TextField), '25');
    await tester.tap(find.byKey(const ValueKey<String>('session-setup-start')));
    await tester.pumpAndSettle();

    expect(harness.library.addBookCalls, 0);
    final ActiveSession? session = harness.session;
    expect(session, isNotNull);
    expect(session!.bookId, entry.bookId);
    expect(session.bookTitle, entry.bookTitle);
    expect(session.timer.target, const Duration(minutes: 25));
    expect(harness.router.state.uri.path, AppRoutes.sessionRun);
    expect(find.text('session-run-test'), findsOneWidget);
  });

  testWidgets(
    'Memilih buku katalog menambahkannya ke rak Sedang Dibaca lalu memulai',
    (WidgetTester tester) async {
      final Book book = fakeBook(
        2,
        title: 'Laskar Pelangi',
        author: 'Andrea Hirata',
      );
      final _SetupHarness harness = await pumpSetup(
        tester,
        catalogBooks: <Book>[book],
      );

      await tester.tap(find.text(AppStrings.sessionSetupSourceCatalog));
      await tester.pumpAndSettle();
      expect(find.text(book.title), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('session-setup-book-book-2')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.sessionSetupWillAdd), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('session-setup-start')),
      );
      await tester.pumpAndSettle();

      expect(harness.library.addBookCalls, 1);
      expect(harness.library.addedBooks.single.id, book.id);
      expect(
        harness.library.requestedStatuses,
        contains(LibraryEntry.statusReading),
      );
      final ActiveSession? session = harness.session;
      expect(session, isNotNull);
      expect(session!.bookId, book.id);
      expect(session.bookTitle, book.title);
      expect(session.timer.target, const Duration(minutes: 30));
      expect(harness.router.state.uri.path, AppRoutes.sessionRun);
    },
  );

  testWidgets('Buku katalog yang sudah ada di rak tidak ditambahkan lagi', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(2, title: 'Laskar Pelangi');
    final _SetupHarness harness = await pumpSetup(
      tester,
      entries: <LibraryEntry>[
        fakeLibraryEntry(2, title: book.title, status: LibraryEntry.statusWant),
      ],
      catalogBooks: <Book>[book],
    );

    await tester.tap(find.text(AppStrings.sessionSetupSourceCatalog));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('session-setup-book-book-2')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        AppStrings.sessionSetupShelfStatus(AppStrings.librarySegmentWant),
      ),
      findsWidgets,
    );

    await tester.tap(find.byKey(const ValueKey<String>('session-setup-start')));
    await tester.pumpAndSettle();

    expect(harness.library.addBookCalls, 0);
    expect(harness.session?.bookId, book.id);
    expect(harness.router.state.uri.path, AppRoutes.sessionRun);
  });

  testWidgets('Buku awal dari Detail Buku langsung terpilih', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final _SetupHarness harness = await pumpSetup(
      tester,
      initialBookId: book.id,
      entries: <LibraryEntry>[
        fakeLibraryEntry(
          1,
          title: book.title,
          status: LibraryEntry.statusReading,
        ),
      ],
      catalogBooks: <Book>[book],
    );

    expect(find.text(AppStrings.sessionSetupNoBookTitle), findsNothing);
    expect(find.text(book.title), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('session-setup-start')));
    await tester.pumpAndSettle();

    expect(harness.library.addBookCalls, 0);
    expect(harness.session?.bookId, book.id);
    expect(harness.router.state.uri.path, AppRoutes.sessionRun);
  });

  testWidgets('Pindai ISBN memilih buku dan menambahkannya saat sesi dimulai', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(3, title: 'Sapiens');
    final _SetupHarness harness = await pumpSetup(tester, scanBook: book);

    await tester.tap(find.byKey(const ValueKey<String>('session-setup-scan')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('fake-scan-result')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('fake-scan-result')));
    await tester.pumpAndSettle();

    expect(find.text(book.title), findsOneWidget);
    expect(find.text(AppStrings.sessionSetupWillAdd), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('session-setup-start')));
    await tester.pumpAndSettle();

    expect(harness.library.addBookCalls, 1);
    expect(harness.library.addedBooks.single.id, book.id);
    expect(
      harness.library.requestedStatuses,
      contains(LibraryEntry.statusReading),
    );
    expect(harness.session?.bookId, book.id);
    expect(harness.router.state.uri.path, AppRoutes.sessionRun);
  });

  testWidgets('Target menit kosong atau nol ditolak dengan pesan ramah', (
    WidgetTester tester,
  ) async {
    final LibraryEntry entry = fakeLibraryEntry(1);
    final _SetupHarness harness = await pumpSetup(
      tester,
      entries: <LibraryEntry>[entry],
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session-setup-book-book-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byKey(const ValueKey<String>('session-setup-start')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sessionSetupTargetRequired), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byKey(const ValueKey<String>('session-setup-start')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sessionSetupTargetPositive), findsOneWidget);

    expect(harness.session, isNull);
    expect(harness.router.state.uri.path, AppRoutes.sessionSetup);
  });

  testWidgets('Sesi yang masih aktif mencegah sesi baru dimulai', (
    WidgetTester tester,
  ) async {
    final ActiveSession active = ActiveSession.start(
      bookId: 'book-9',
      bookTitle: 'Sesi Lama',
      target: const Duration(minutes: 10),
    );
    final FakeActiveSessionRepository sessions = FakeActiveSessionRepository(
      session: active,
    );

    final _SetupHarness harness = await pumpSetup(
      tester,
      entries: <LibraryEntry>[fakeLibraryEntry(1)],
      activeSessionRepository: sessions,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session-setup-book-book-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('session-setup-start')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionAlreadyActive), findsOneWidget);
    expect(harness.library.addBookCalls, 0);
    expect(harness.router.state.uri.path, AppRoutes.sessionSetup);
    expect(harness.session?.bookId, 'book-9');
  });

  testWidgets('Galat katalog menampilkan pesan dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository books = FakeBookRepository()
      ..fetchPageFailuresRemaining = 1;
    await pumpSetup(tester, bookRepository: books);

    await tester.tap(find.text(AppStrings.sessionSetupSourceCatalog));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionSetupCatalogError), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sessionSetupCatalogEmptyTitle), findsOneWidget);
  });

  testWidgets('Layar rapi di mode gelap pada ponsel', (
    WidgetTester tester,
  ) async {
    final LibraryEntry entry = fakeLibraryEntry(
      1,
      title: 'Buku dengan Judul yang Cukup Panjang untuk Menguji Tata Letak',
    );

    await pumpSetup(
      tester,
      entries: <LibraryEntry>[entry],
      viewSize: const Size(360, 800),
      theme: AppTheme.dark,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('session-setup-book-book-1')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(entry.bookTitle), findsWidgets);
  });

  testWidgets('Layar rapi di mode gelap pada tablet', (
    WidgetTester tester,
  ) async {
    final LibraryEntry entry = fakeLibraryEntry(
      1,
      title: 'Buku dengan Judul yang Cukup Panjang untuk Menguji Tata Letak',
    );

    await pumpSetup(
      tester,
      entries: <LibraryEntry>[entry],
      viewSize: const Size(800, 1280),
      theme: AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.sessionSetupScanIsbn), findsOneWidget);
  });
}

class _SetupHarness {
  const _SetupHarness({
    required this.container,
    required this.router,
    required this.library,
    required this.sessions,
  });

  final ProviderContainer container;
  final GoRouter router;
  final FakeLibraryRepository library;
  final FakeActiveSessionRepository sessions;

  ActiveSession? get session => container.read(activeSessionProvider).value;
}

class _FakeScannerScreen extends StatelessWidget {
  const _FakeScannerScreen({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey<String>('fake-scan-result'),
          onPressed: () => context.pop<Book>(book),
          child: const Text('hasilkan-buku'),
        ),
      ),
    );
  }
}
