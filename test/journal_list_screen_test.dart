import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/features/journal/data/journal.dart';
import 'package:libria/features/journal/data/journal_repository.dart';
import 'package:libria/features/journal/presentation/journal_list_screen.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';

import 'support/fake_journal_repository.dart';
import 'support/fake_library_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required FakeJournalRepository repository,
    List<LibraryEntry> entries = const <LibraryEntry>[],
    bool online = true,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repository),
        libraryRepositoryProvider.overrideWithValue(
          FakeLibraryRepository(entries: List<LibraryEntry>.of(entries)),
        ),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(online),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.journal,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.journal,
          builder: (BuildContext context, GoRouterState state) =>
              const JournalListScreen(),
        ),
        GoRoute(
          path: AppRoutes.journalNew,
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: Text(
                'journal-new-test:'
                '${state.uri.queryParameters[AppRoutes.journalBookIdParam] ?? ''}',
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.homeSettings,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-settings-test'))),
        ),
        GoRoute(
          path: AppRoutes.homeLibrary,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-library-test'))),
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
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('Menampilkan seluruh jurnal dengan data lengkap', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[
        fakeJournal(
          1,
          bookTitle: 'Bumi Manusia',
          content: 'Catatan pertama tentang Minke.',
          createdAt: DateTime(2026, 10, 23, 9),
        ),
        fakeJournal(
          2,
          bookTitle: 'Laskar Pelangi',
          content: 'Catatan kedua tentang Ikal.',
          createdAt: DateTime(2026, 10, 22, 20, 15),
        ),
      ],
    );
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository);

    expect(find.text(AppStrings.journalTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Laskar Pelangi'), findsOneWidget);
    expect(find.text('Catatan pertama tentang Minke.'), findsOneWidget);
    expect(find.text('Catatan kedua tentang Ikal.'), findsOneWidget);
    expect(
      find.text(AppDateFormatter.dateTime(DateTime(2026, 10, 23, 9))),
      findsOneWidget,
    );
  });

  testWidgets('Filter per buku menyaring jurnal yang tampil', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[
        fakeJournal(1, bookId: 'book-1', bookTitle: 'Bumi Manusia'),
        fakeJournal(2, bookId: 'book-2', bookTitle: 'Laskar Pelangi'),
      ],
    );
    addTearDown(repository.dispose);

    await pumpScreen(
      tester,
      repository: repository,
      entries: <LibraryEntry>[
        fakeLibraryEntry(1, title: 'Bumi Manusia'),
        fakeLibraryEntry(2, title: 'Laskar Pelangi'),
      ],
    );

    expect(find.text('Bumi Manusia'), findsNWidgets(2));
    expect(find.text('Laskar Pelangi'), findsNWidgets(2));

    final Finder filterBook = find.byKey(
      const ValueKey<String>('journal-filter-book-2'),
    );
    await tester.ensureVisible(filterBook);
    await tester.pumpAndSettle();
    await tester.tap(filterBook);
    await tester.pump();
    await tester.pump();

    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Laskar Pelangi'), findsNWidgets(2));

    final Finder filterAll = find.byKey(
      const ValueKey<String>('journal-filter-all'),
    );
    await tester.ensureVisible(filterAll);
    await tester.pumpAndSettle();
    await tester.tap(filterAll);
    await tester.pump();
    await tester.pump();

    expect(find.text('Bumi Manusia'), findsNWidgets(2));
    expect(find.text('Laskar Pelangi'), findsNWidgets(2));
  });

  testWidgets('Keadaan kosong tanpa filter menampilkan ajakan menulis', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository);

    expect(find.text(AppStrings.journalEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.journalEmptyMessage), findsOneWidget);
  });

  testWidgets('Keadaan kosong per buku membuka formulir dengan buku itu', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpScreen(
      tester,
      repository: repository,
      entries: <LibraryEntry>[fakeLibraryEntry(2, title: 'Laskar Pelangi')],
    );

    await tester.tap(find.text('Laskar Pelangi'));
    await tester.pump();
    await tester.pump();

    expect(find.text(AppStrings.journalBookEmptyMessage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('journal-empty-add')));
    await tester.pumpAndSettle();

    expect(find.text('journal-new-test:book-2'), findsOneWidget);
  });

  testWidgets('Jurnal dari cache tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[
        fakeJournal(1, bookTitle: 'Bumi Manusia', content: 'Catatan cache.'),
      ],
    );
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository, online: false);

    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Catatan cache.'), findsOneWidget);
    expect(find.text(AppStrings.journalOfflineTitle), findsNothing);
  });

  testWidgets('Keadaan offline tanpa data menampilkan pesan offline', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository, online: false);

    expect(find.text(AppStrings.journalOfflineTitle), findsOneWidget);
    expect(find.text(AppStrings.journalOfflineMessage), findsOneWidget);
  });

  testWidgets('Galat pemuatan menampilkan tombol coba lagi', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    repository.readError = const JournalFailure('Gagal memuat.');
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository);

    expect(find.text('Gagal memuat.'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets('Hapus jurnal memanggil repository dan memperbarui daftar', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[fakeJournal(1, bookTitle: 'Bumi Manusia')],
    );
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository);

    expect(find.text('Bumi Manusia'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.journalDeleteDialogTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.journalDeleteConfirm));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.lastDeletedId, 'journal-1');
    expect(find.text('Bumi Manusia'), findsNothing);
    expect(find.text(AppStrings.journalEmptyTitle), findsOneWidget);
  });

  testWidgets('Galat hapus menampilkan pesan dan mempertahankan jurnal', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[fakeJournal(1, bookTitle: 'Bumi Manusia')],
    )..deleteError = const JournalFailure('Gagal menghapus jurnal uji.');
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.journalDeleteConfirm));
    await tester.pumpAndSettle();

    expect(find.text('Gagal menghapus jurnal uji.'), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
  });

  testWidgets('Muat Lebih Banyak menambah jurnal yang tampil', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: List<Journal>.generate(
        25,
        (int index) => fakeJournal(
          index,
          bookTitle: 'Buku $index',
          createdAt: DateTime(2026, 1, 1 + index),
        ),
      ),
    );
    addTearDown(repository.dispose);

    await pumpScreen(tester, repository: repository);

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.journalLoadMore),
      400,
      scrollable: listScrollable,
    );
    expect(find.text(AppStrings.journalLoadMore), findsOneWidget);

    await tester.tap(find.text(AppStrings.journalLoadMore));
    await tester.pumpAndSettle();

    // Seluruh 25 jurnal kini berada di bawah batas baru (40), sehingga
    // tombol "Muat Lebih Banyak" tidak lagi tampil.
    expect(find.text(AppStrings.journalLoadMore), findsNothing);
  });

  testWidgets('Filter banyak buku dapat digulir pada layar sempit gelap', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[fakeJournal(1, bookTitle: 'Bumi Manusia')],
    );
    addTearDown(repository.dispose);

    await pumpScreen(
      tester,
      repository: repository,
      entries: List<LibraryEntry>.generate(
        30,
        (int index) => fakeLibraryEntry(
          index,
          title: 'Judul buku yang sangat panjang nomor $index',
        ),
      ),
      viewSize: const Size(320, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(find.text(AppStrings.journalTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text(AppStrings.journalFilterAll), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
