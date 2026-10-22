import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';
import 'package:libria/features/scanner/presentation/isbn_scanner_screen.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_isbn_log_repository.dart';

void main() {
  const String isbn = '9789799731234';

  Future<_ScannerHarness> pumpScanner(
    WidgetTester tester, {
    FakeBookRepository? bookRepository,
    FakeIsbnLogRepository? logRepository,
    ValueChanged<Book>? onBookFound,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeBookRepository books = bookRepository ?? FakeBookRepository();
    final FakeIsbnLogRepository logs = logRepository ?? FakeIsbnLogRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith((Ref ref) => books),
        isbnLogRepositoryProvider.overrideWith((Ref ref) => logs),
      ],
    );
    addTearDown(container.dispose);
    late ValueChanged<String> detect;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: IsbnScannerScreen(
            onBookFound: onBookFound,
            scannerBuilder:
                (BuildContext context, ValueChanged<String> onDetected) {
                  detect = onDetected;
                  return const SizedBox.expand();
                },
          ),
        ),
      ),
    );
    await tester.pump();

    return _ScannerHarness(books: books, logs: logs, detect: detect);
  }

  testWidgets('Menampilkan petunjuk pemindaian', (WidgetTester tester) async {
    await pumpScanner(tester);

    expect(find.text(AppStrings.isbnScanTitle), findsOneWidget);
    expect(find.text(AppStrings.isbnScanHintTitle), findsOneWidget);
    expect(find.text(AppStrings.isbnScanHintMessage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('isbn-scan-back')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('isbn-scan-torch')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ISBN terdaftar memanggil onBookFound', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, isbn: isbn);
    Book? found;
    final _ScannerHarness harness = await pumpScanner(
      tester,
      bookRepository: FakeBookRepository(books: <Book>[book]),
      onBookFound: (Book value) => found = value,
    );

    harness.detect('978-979-973-123-4');
    await tester.pumpAndSettle();

    expect(found, same(book));
    expect(harness.logs.recordCalls, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ISBN tak terdaftar menampilkan pesan dan mencatat log', (
    WidgetTester tester,
  ) async {
    final _ScannerHarness harness = await pumpScanner(tester);

    harness.detect('978-979-973-123-4');
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.isbnScanNotFoundTitle), findsOneWidget);
    expect(find.text(AppStrings.isbnScanNotFoundMessage(isbn)), findsOneWidget);
    expect(find.text(AppStrings.isbnScanLogRecorded), findsOneWidget);
    expect(harness.logs.recordCalls, 1);
    expect(harness.logs.recordedIsbns, <String>[isbn]);
    expect(find.text(AppStrings.isbnScanAgain), findsOneWidget);
    expect(find.text(AppStrings.isbnScanClose), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pindai Ulang memulai pemindaian berikutnya', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository books = FakeBookRepository();
    Book? found;
    final _ScannerHarness harness = await pumpScanner(
      tester,
      bookRepository: books,
      onBookFound: (Book value) => found = value,
    );

    harness.detect(isbn);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.isbnScanNotFoundTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.isbnScanAgain));
    await tester.pump();
    expect(find.text(AppStrings.isbnScanHintTitle), findsOneWidget);
    expect(find.text(AppStrings.isbnScanNotFoundTitle), findsNothing);

    final Book book = fakeBook(2, isbn: isbn);
    books.allBooks.add(book);
    harness.detect(isbn);
    await tester.pumpAndSettle();
    expect(found, same(book));
  });

  testWidgets('Barcode bukan ISBN tidak mencatat log', (
    WidgetTester tester,
  ) async {
    final _ScannerHarness harness = await pumpScanner(tester);

    harness.detect('12345');
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.isbnScanInvalidTitle), findsOneWidget);
    expect(find.text(AppStrings.isbnScanInvalidMessage), findsOneWidget);
    expect(harness.books.findByIsbnCalls, isEmpty);
    expect(harness.logs.recordCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pencarian gagal menampilkan pesan yang ramah', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository books = FakeBookRepository();
    books.findByIsbnError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    final _ScannerHarness harness = await pumpScanner(
      tester,
      bookRepository: books,
    );

    harness.detect(isbn);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.isbnScanErrorTitle), findsOneWidget);
    expect(find.text(AppStrings.isbnScanLookupNetworkError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(harness.logs.recordCalls, 0);
  });

  testWidgets(
    'Deteksi berulang saat mencari hanya menjalankan satu pencarian',
    (WidgetTester tester) async {
      final FakeBookRepository books = FakeBookRepository();
      final Completer<void> gate = Completer<void>();
      books.findByIsbnGate = gate;
      final _ScannerHarness harness = await pumpScanner(
        tester,
        bookRepository: books,
      );

      harness.detect(isbn);
      harness.detect(isbn);
      harness.detect(isbn);
      await tester.pump();

      expect(books.findByIsbnCalls, <String>[isbn]);
      expect(find.text(AppStrings.isbnScanSearchingTitle), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.isbnScanNotFoundTitle), findsOneWidget);
    },
  );

  testWidgets('Layar menutup dengan buku terpilih saat tanpa onBookFound', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final Book book = fakeBook(3, isbn: isbn);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith(
          (Ref ref) => FakeBookRepository(books: <Book>[book]),
        ),
        isbnLogRepositoryProvider.overrideWith(
          (Ref ref) => FakeIsbnLogRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    late ValueChanged<String> detect;

    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const _ScannerHome(),
        ),
        GoRoute(
          path: '/scan',
          builder: (BuildContext context, GoRouterState state) =>
              IsbnScannerScreen(
                scannerBuilder:
                    (BuildContext context, ValueChanged<String> onDetected) {
                      detect = onDetected;
                      return const SizedBox.expand();
                    },
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.tap(find.text('Buka Pemindai'));
    await tester.pumpAndSettle();
    detect(isbn);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.isbnScanTitle), findsNothing);
    expect(find.text('Buku terpilih: ${book.title}'), findsOneWidget);
  });

  testWidgets('Tata letak ponsel, tablet, dan landscape tanpa overflow', (
    WidgetTester tester,
  ) async {
    await pumpScanner(
      tester,
      viewSize: const Size(360, 800),
      theme: AppTheme.dark,
    );
    expect(tester.takeException(), isNull);

    await pumpScanner(
      tester,
      viewSize: const Size(800, 1280),
      theme: AppTheme.dark,
    );
    expect(tester.takeException(), isNull);

    final _ScannerHarness harness = await pumpScanner(
      tester,
      viewSize: const Size(640, 360),
      theme: AppTheme.light,
    );
    harness.detect(isbn);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.isbnScanNotFoundTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ScannerHarness {
  const _ScannerHarness({
    required this.books,
    required this.logs,
    required this.detect,
  });

  final FakeBookRepository books;
  final FakeIsbnLogRepository logs;
  final ValueChanged<String> detect;
}

class _ScannerHome extends StatefulWidget {
  const _ScannerHome();

  @override
  State<_ScannerHome> createState() => _ScannerHomeState();
}

class _ScannerHomeState extends State<_ScannerHome> {
  Book? _book;

  Future<void> _openScanner(BuildContext context) async {
    final Book? result = await context.push<Book>('/scan');
    if (mounted) {
      setState(() {
        _book = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => _openScanner(context),
            child: const Text('Buka Pemindai'),
          ),
          if (_book != null) Text('Buku terpilih: ${_book!.title}'),
        ],
      ),
    );
  }
}
