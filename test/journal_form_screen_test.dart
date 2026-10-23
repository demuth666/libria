import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/journal/data/journal.dart';
import 'package:libria/features/journal/data/journal_repository.dart';
import 'package:libria/features/journal/presentation/journal_form_screen.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';

import 'support/fake_journal_repository.dart';
import 'support/fake_library_repository.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    required FakeJournalRepository repository,
    List<LibraryEntry> entries = const <LibraryEntry>[],
    String initialLocation = AppRoutes.journalNew,
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
          (Ref ref) => Stream<bool>.value(true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: initialLocation,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.journal,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('journal-list-test'))),
        ),
        GoRoute(
          path: AppRoutes.homeLibrary,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-library-test'))),
        ),
        GoRoute(
          path: AppRoutes.journalNew,
          builder: (BuildContext context, GoRouterState state) =>
              JournalFormScreen(
                initialBookId:
                    state.uri.queryParameters[AppRoutes.journalBookIdParam],
                journalId: state.uri.queryParameters[AppRoutes.journalIdParam],
              ),
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
    await tester.pumpAndSettle();
  }

  Finder contentField() {
    return find.descendant(
      of: find.byKey(const ValueKey<String>('journal-content-field')),
      matching: find.byType(TextField),
    );
  }

  Future<void> enterContent(WidgetTester tester, String content) async {
    await tester.enterText(contentField(), content);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('journal-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('Formulir baru menyimpan jurnal untuk buku yang dipilih', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      entries: <LibraryEntry>[
        fakeLibraryEntry(1, title: 'Bumi Manusia'),
        fakeLibraryEntry(2, title: 'Laskar Pelangi'),
      ],
    );

    expect(find.text(AppStrings.journalNewTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('journal-book-book-2')));
    await tester.pump();
    await enterContent(tester, 'Refleksi tentang Ikal.');
    await save(tester);

    expect(repository.addCalls, 1);
    expect(repository.lastAddedBookId, 'book-2');
    expect(repository.lastAddedBookTitle, 'Laskar Pelangi');
    expect(repository.lastAddedContent, 'Refleksi tentang Ikal.');
    expect(find.text('journal-list-test'), findsOneWidget);
  });

  testWidgets('Buku awal dari tautan langsung langsung terpilih', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      entries: <LibraryEntry>[
        fakeLibraryEntry(1, title: 'Bumi Manusia'),
        fakeLibraryEntry(2, title: 'Laskar Pelangi'),
      ],
      initialLocation: AppRoutes.journalNewPath(bookId: 'book-2'),
    );

    await enterContent(tester, 'Catatan dari sesi membaca.');
    await save(tester);

    expect(repository.addCalls, 1);
    expect(repository.lastAddedBookId, 'book-2');
    expect(repository.lastAddedBookTitle, 'Laskar Pelangi');
    expect(repository.lastAddedContent, 'Catatan dari sesi membaca.');
  });

  testWidgets('Buku dan isi wajib diisi sebelum menyimpan', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpForm(tester, repository: repository);

    await save(tester);

    expect(find.text(AppStrings.journalBookRequired), findsOneWidget);
    expect(find.text(AppStrings.journalContentRequired), findsOneWidget);
    expect(repository.addCalls, 0);
  });

  testWidgets('Isi jurnal yang hanya berisi spasi ditolak', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      entries: <LibraryEntry>[fakeLibraryEntry(1)],
    );

    await tester.tap(find.byKey(const ValueKey<String>('journal-book-book-1')));
    await tester.pump();
    await enterContent(tester, '   ');
    await save(tester);

    expect(find.text(AppStrings.journalContentRequired), findsOneWidget);
    expect(repository.addCalls, 0);
  });

  testWidgets('Formulir ubah memuat isi lama dan menyimpan perubahan', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[
        fakeJournal(
          1,
          bookId: 'book-1',
          bookTitle: 'Bumi Manusia',
          content: 'Isi lama.',
        ),
      ],
    );
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      initialLocation: AppRoutes.journalEditPath('journal-1'),
    );

    expect(find.text(AppStrings.journalEditTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(contentField(), findsOneWidget);
    expect(find.text('Isi lama.'), findsOneWidget);

    await enterContent(tester, 'Isi yang sudah diperbaiki.');
    await save(tester);

    expect(repository.updateCalls, 1);
    expect(repository.addCalls, 0);
    expect(repository.lastUpdatedId, 'journal-1');
    expect(repository.lastUpdatedContent, 'Isi yang sudah diperbaiki.');
    expect(find.text('journal-list-test'), findsOneWidget);
  });

  testWidgets('Jurnal yang tidak ada menampilkan keadaan kosong', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      initialLocation: AppRoutes.journalEditPath('journal-hilang'),
    );

    expect(find.text(AppStrings.journalNotFound), findsOneWidget);
    expect(find.text(AppStrings.journalBack), findsOneWidget);
  });

  testWidgets('Galat muat jurnal dapat dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      journals: <Journal>[fakeJournal(1, content: 'Isi lama.')],
    )..readError = const JournalFailure('Gagal memuat jurnal uji.');
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      initialLocation: AppRoutes.journalEditPath('journal-1'),
    );

    expect(find.text('Gagal memuat jurnal uji.'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    repository.readError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.journalEditTitle), findsOneWidget);
    expect(find.text('Isi lama.'), findsOneWidget);
  });

  testWidgets('Galat simpan ditampilkan tanpa meninggalkan formulir', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository()
      ..addError = const JournalFailure('Gagal menyimpan jurnal uji.');
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      entries: <LibraryEntry>[fakeLibraryEntry(1)],
    );

    await tester.tap(find.byKey(const ValueKey<String>('journal-book-book-1')));
    await tester.pump();
    await enterContent(tester, 'Refleksi yang gagal disimpan.');
    await save(tester);

    expect(repository.addCalls, 1);
    expect(find.text('Gagal menyimpan jurnal uji.'), findsOneWidget);
    expect(find.text(AppStrings.journalNewTitle), findsOneWidget);
    expect(find.text(AppStrings.journalSaving), findsNothing);
    expect(find.text(AppStrings.journalSave), findsOneWidget);
  });

  testWidgets('Formulir tetap terbaca pada layar sempit mode gelap', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository();
    addTearDown(repository.dispose);

    await pumpForm(
      tester,
      repository: repository,
      entries: <LibraryEntry>[
        fakeLibraryEntry(1, title: 'Bumi Manusia'),
        fakeLibraryEntry(2, title: 'Laskar Pelangi'),
      ],
      viewSize: const Size(320, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(find.text(AppStrings.journalNewTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Laskar Pelangi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
