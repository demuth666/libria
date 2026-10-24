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
import 'package:libria/core/widgets/empty_view.dart';
import 'package:libria/core/widgets/error_view.dart';
import 'package:libria/core/widgets/loading_view.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';
import 'package:libria/features/library/presentation/library_shelves.dart';
import 'package:libria/features/reviews/data/review_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_library_repository.dart';
import 'support/fake_review_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpLibrary(
    WidgetTester tester, {
    required FakeLibraryRepository repository,
    Stream<bool>? connectivity,
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
        libraryRepositoryProvider.overrideWith((Ref ref) => repository),
        bookRepositoryProvider.overrideWith((Ref ref) => FakeBookRepository()),
        reviewRepositoryProvider.overrideWithValue(FakeReviewRepository()),
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
        child: _LibraryTestApp(theme: theme ?? AppTheme.light),
      ),
    );
    router.go(AppRoutes.homeLibrary);

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _Harness(router: router);
  }

  testWidgets('Menampilkan loading saat rak belum mengemit data', (
    WidgetTester tester,
  ) async {
    final StreamController<List<LibraryEntry>> controller =
        StreamController<List<LibraryEntry>>();
    addTearDown(controller.close);
    final FakeLibraryRepository repository = FakeLibraryRepository()
      ..watchLibraryFactory = () => controller.stream;

    await pumpLibrary(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.libraryLoading), findsOneWidget);
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.libraryEmptyTitle), findsNothing);
  });

  testWidgets('Menampilkan header, segmen, hitungan, dan kartu Sedang Dibaca', (
    WidgetTester tester,
  ) async {
    final LibraryEntry first = fakeLibraryEntry(
      1,
      title: 'Bumi Manusia',
      author: 'Pramoedya Ananta Toer',
      currentPage: 75,
      totalPages: 100,
    );
    final LibraryEntry second = fakeLibraryEntry(
      2,
      title: 'Laskar Pelangi',
      author: 'Andrea Hirata',
      currentPage: 10,
      totalPages: 200,
    );
    final LibraryEntry want = fakeLibraryEntry(
      3,
      title: 'Filosofi Teras',
      author: 'Henry Manampiring',
      status: LibraryEntry.statusWant,
    );
    final LibraryEntry finished = fakeLibraryEntry(
      4,
      title: 'Sapiens',
      author: 'Yuval Noah Harari',
      status: LibraryEntry.statusFinished,
      finishedAt: DateTime(2026, 3, 12),
    );
    final FakeLibraryRepository repository = FakeLibraryRepository(
      entries: <LibraryEntry>[first, want, finished, second],
    );

    await pumpLibrary(tester, repository: repository);

    expect(find.text(AppStrings.libraryTitle), findsWidgets);
    expect(find.byIcon(Icons.person), findsNothing);
    expect(_count(tester, LibrarySection.reading), '2');
    expect(_count(tester, LibrarySection.want), '1');
    expect(_count(tester, LibrarySection.finished), '1');

    expect(find.text(first.bookTitle), findsOneWidget);
    expect(find.text(first.bookAuthor), findsOneWidget);
    expect(find.text(AppStrings.percentDone(75)), findsOneWidget);
    expect(find.text(AppStrings.pagesRead(75, 100)), findsOneWidget);
    expect(find.text(second.bookTitle), findsOneWidget);
    expect(find.text(want.bookTitle), findsNothing);
    expect(find.text(finished.bookTitle), findsNothing);

    expect(find.byType(AppBottomNavBar), findsOneWidget);
    final AppBottomNavBar navBar = tester.widget<AppBottomNavBar>(
      find.byType(AppBottomNavBar),
    );
    expect(navBar.selectedIndex, 1);

    // Pencarian dibuka sebagai layar tersendiri (T-042); FAB Tambah Buku,
    // menu ubah status, dan Lanjut Sesi masih milik tiket lain.
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byTooltip(AppStrings.catalogSearchTitle), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Tambah Buku'), findsNothing);
    expect(find.text('Lanjut Sesi'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('Segmen hanya menampilkan status yang sesuai dan mengabaikan '
      'status tak dikenal', (WidgetTester tester) async {
    final LibraryEntry reading = fakeLibraryEntry(
      1,
      title: 'Buku Sedang',
      status: LibraryEntry.statusReading,
    );
    final LibraryEntry want = fakeLibraryEntry(
      2,
      title: 'Buku Antrean',
      status: LibraryEntry.statusWant,
    );
    final LibraryEntry finished = fakeLibraryEntry(
      3,
      title: 'Buku Tamat',
      status: LibraryEntry.statusFinished,
      finishedAt: DateTime(2026, 3, 12),
    );
    final LibraryEntry withoutDate = fakeLibraryEntry(
      4,
      title: 'Buku Tanpa Tanggal',
      status: LibraryEntry.statusFinished,
    );
    final LibraryEntry unknown = fakeLibraryEntry(
      5,
      title: 'Buku Status Asing',
      status: 'paused',
    );
    final FakeLibraryRepository repository = FakeLibraryRepository(
      entries: <LibraryEntry>[reading, want, finished, withoutDate, unknown],
    );

    await pumpLibrary(tester, repository: repository);

    expect(_count(tester, LibrarySection.reading), '1');
    expect(_count(tester, LibrarySection.want), '1');
    expect(_count(tester, LibrarySection.finished), '2');
    expect(find.text(unknown.bookTitle), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-want')),
    );
    await tester.pumpAndSettle();

    expect(find.text(want.bookTitle), findsOneWidget);
    expect(find.text(reading.bookTitle), findsNothing);
    expect(find.text(finished.bookTitle), findsNothing);
    expect(
      find.byKey(ValueKey<String>('library-want-${want.bookId}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-finished')),
    );
    await tester.pumpAndSettle();

    expect(find.text(finished.bookTitle), findsOneWidget);
    expect(find.text(withoutDate.bookTitle), findsOneWidget);
    expect(
      find.text(
        AppStrings.libraryFinishedOn(
          AppDateFormatter.date(DateTime(2026, 3, 12)),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          ValueKey<String>('library-finished-${withoutDate.bookId}'),
        ),
        matching: find.textContaining('Selesai '),
      ),
      findsNothing,
    );
    expect(find.text(reading.bookTitle), findsNothing);
  });

  testWidgets('Segmen kosong menyebut segmennya', (WidgetTester tester) async {
    final FakeLibraryRepository repository = FakeLibraryRepository(
      entries: <LibraryEntry>[fakeLibraryEntry(1, title: 'Buku Aktif')],
    );

    await pumpLibrary(tester, repository: repository);
    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-want')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.libraryEmptyWantTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryEmptyWantMessage), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-finished')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.libraryEmptyFinishedTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryEmptyFinishedMessage), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-reading')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buku Aktif'), findsOneWidget);
  });

  testWidgets('Segmen Sedang Dibaca kosong menyebut segmennya', (
    WidgetTester tester,
  ) async {
    final LibraryEntry want = fakeLibraryEntry(
      1,
      title: 'Buku Antrean',
      status: LibraryEntry.statusWant,
    );

    await pumpLibrary(
      tester,
      repository: FakeLibraryRepository(entries: <LibraryEntry>[want]),
    );

    expect(find.text(AppStrings.libraryEmptyReadingTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryEmptyReadingMessage), findsOneWidget);
    expect(_count(tester, LibrarySection.reading), '0');
    expect(find.text(want.bookTitle), findsNothing);
  });

  testWidgets('Rak yang benar-benar kosong menampilkan satu keadaan kosong', (
    WidgetTester tester,
  ) async {
    await pumpLibrary(tester, repository: FakeLibraryRepository());

    expect(find.text(AppStrings.libraryEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryEmptyMessage), findsOneWidget);
    expect(find.byType(EmptyView), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('library-section-reading')),
      findsOneWidget,
    );
    expect(_count(tester, LibrarySection.reading), '0');
    expect(_count(tester, LibrarySection.want), '0');
    expect(_count(tester, LibrarySection.finished), '0');
    expect(find.text(AppStrings.libraryEmptyWantTitle), findsNothing);
  });

  testWidgets('Status tak dikenal saja tidak membuat layar gagal', (
    WidgetTester tester,
  ) async {
    await pumpLibrary(
      tester,
      repository: FakeLibraryRepository(
        entries: <LibraryEntry>[
          fakeLibraryEntry(1, title: 'Buku Asing', status: 'paused'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.libraryEmptyTitle), findsOneWidget);
    expect(find.text('Buku Asing'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('library-section-reading')),
      findsOneWidget,
    );
    expect(_count(tester, LibrarySection.reading), '0');
    expect(find.text(AppStrings.libraryEmptyReadingTitle), findsNothing);
  });

  testWidgets('Galat awal memakai pesan LibraryFailure dan Coba Lagi memuat '
      'ulang', (WidgetTester tester) async {
    final LibraryEntry entry = fakeLibraryEntry(1, title: 'Buku Setelah Galat');
    final List<Stream<List<LibraryEntry>>> streams =
        <Stream<List<LibraryEntry>>>[
          Stream<List<LibraryEntry>>.error(
            const LibraryFailure(AppStrings.libraryLoadNetworkError),
          ),
          Stream<List<LibraryEntry>>.value(<LibraryEntry>[entry]),
        ];
    final FakeLibraryRepository repository = FakeLibraryRepository()
      ..watchLibraryFactory = () => streams.removeAt(0);

    await pumpLibrary(tester, repository: repository);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text(AppStrings.libraryLoadNetworkError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.libraryLoading), findsNothing);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(entry.bookTitle), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    expect(repository.watchLibraryCalls, 2);
  });

  testWidgets('Galat lain memakai pesan umum tanpa detail teknis', (
    WidgetTester tester,
  ) async {
    final FakeLibraryRepository repository = FakeLibraryRepository()
      ..watchLibraryFactory = () => Stream<List<LibraryEntry>>.error(
        StateError('detail internal tidak boleh tampil'),
      );

    await pumpLibrary(tester, repository: repository);

    expect(find.text(AppStrings.libraryLoadError), findsOneWidget);
    expect(
      find.textContaining('detail internal tidak boleh tampil'),
      findsNothing,
    );
    expect(find.byType(ErrorView), findsOneWidget);
  });

  testWidgets(
    'Galat izin saat offline tetap menampilkan pesan LibraryFailure',
    (WidgetTester tester) async {
      final FakeLibraryRepository repository = FakeLibraryRepository()
        ..watchLibraryFactory = () => Stream<List<LibraryEntry>>.error(
          const LibraryFailure(AppStrings.libraryLoadPermissionDenied),
        );

      await pumpLibrary(
        tester,
        repository: repository,
        connectivity: Stream<bool>.value(false),
      );

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text(AppStrings.libraryLoadPermissionDenied), findsOneWidget);
      expect(find.text(AppStrings.libraryOfflineTitle), findsNothing);
    },
  );

  testWidgets('Rak kosong yang sudah dimuat tetap kosong saat offline', (
    WidgetTester tester,
  ) async {
    await pumpLibrary(
      tester,
      repository: FakeLibraryRepository(),
      connectivity: Stream<bool>.value(false),
    );

    expect(find.text(AppStrings.libraryEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryOfflineTitle), findsNothing);
  });

  testWidgets('Galat setelah data kosong tetap mempertahankan keadaan kosong', (
    WidgetTester tester,
  ) async {
    final StreamController<List<LibraryEntry>> controller =
        StreamController<List<LibraryEntry>>();
    addTearDown(controller.close);
    final FakeLibraryRepository repository = FakeLibraryRepository()
      ..watchLibraryFactory = () => controller.stream;

    await pumpLibrary(tester, repository: repository, settle: false);
    controller.add(const <LibraryEntry>[]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.libraryEmptyTitle), findsOneWidget);

    controller.addError(
      const LibraryFailure(AppStrings.libraryLoadNetworkError),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.libraryEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryStaleMessage), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('Galat setelah data tampil mempertahankan daftar dan memberi '
      'pemberitahuan ringan', (WidgetTester tester) async {
    final LibraryEntry entry = fakeLibraryEntry(1, title: 'Buku Terakhir');
    final LibraryEntry updated = fakeLibraryEntry(
      2,
      title: 'Buku Terbaru Setelah Coba Lagi',
    );
    final StreamController<List<LibraryEntry>> controller =
        StreamController<List<LibraryEntry>>();
    addTearDown(controller.close);
    final List<Stream<List<LibraryEntry>>> streams =
        <Stream<List<LibraryEntry>>>[
          controller.stream,
          Stream<List<LibraryEntry>>.value(<LibraryEntry>[updated]),
        ];
    final FakeLibraryRepository repository = FakeLibraryRepository()
      ..watchLibraryFactory = () => streams.removeAt(0);

    await pumpLibrary(tester, repository: repository, settle: false);
    controller.add(<LibraryEntry>[entry]);
    await tester.pumpAndSettle();

    expect(find.text(entry.bookTitle), findsOneWidget);

    controller.addError(
      const LibraryFailure(AppStrings.libraryLoadNetworkError),
    );
    await tester.pumpAndSettle();

    expect(find.text(entry.bookTitle), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.text(AppStrings.libraryStaleMessage), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(updated.bookTitle), findsOneWidget);
    expect(find.text(entry.bookTitle), findsNothing);
    expect(find.text(AppStrings.libraryStaleMessage), findsNothing);
    expect(repository.watchLibraryCalls, 2);
  });

  testWidgets('Data yang sudah dimuat tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final LibraryEntry entry = fakeLibraryEntry(1, title: 'Buku Dari Cache');
    final FakeLibraryRepository repository = FakeLibraryRepository(
      entries: <LibraryEntry>[entry],
    );

    await pumpLibrary(
      tester,
      repository: repository,
      connectivity: Stream<bool>.value(false),
    );

    expect(find.text(entry.bookTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryOfflineTitle), findsNothing);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('Offline tanpa cache menampilkan keadaan offline, bukan loading '
      'tanpa akhir', (WidgetTester tester) async {
    final LibraryEntry entry = fakeLibraryEntry(1, title: 'Buku Cache Baru');
    final StreamController<List<LibraryEntry>> pending =
        StreamController<List<LibraryEntry>>();
    addTearDown(pending.close);
    final List<Stream<List<LibraryEntry>>> streams =
        <Stream<List<LibraryEntry>>>[
          pending.stream,
          Stream<List<LibraryEntry>>.value(<LibraryEntry>[entry]),
        ];
    final FakeLibraryRepository repository = FakeLibraryRepository()
      ..watchLibraryFactory = () => streams.removeAt(0);

    await pumpLibrary(
      tester,
      repository: repository,
      connectivity: Stream<bool>.value(false),
    );

    expect(find.text(AppStrings.libraryOfflineTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryOfflineMessage), findsOneWidget);
    expect(find.text(AppStrings.libraryLoading), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(AppStrings.retry), findsOneWidget);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(entry.bookTitle), findsOneWidget);
    expect(find.text(AppStrings.libraryOfflineTitle), findsNothing);
    expect(repository.watchLibraryCalls, 2);
  });

  testWidgets('Pemulihan koneksi memuat data terbaru tanpa mengubah segmen '
      'aktif', (WidgetTester tester) async {
    final StreamController<bool> connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final LibraryEntry readingBefore = fakeLibraryEntry(
      1,
      title: 'Buku Lama',
      status: LibraryEntry.statusReading,
    );
    final LibraryEntry wantBefore = fakeLibraryEntry(
      2,
      title: 'Antrean Awal',
      status: LibraryEntry.statusWant,
    );
    final LibraryEntry readingAfter = fakeLibraryEntry(
      1,
      title: 'Buku Baru',
      status: LibraryEntry.statusReading,
    );
    final LibraryEntry wantAfter = fakeLibraryEntry(
      3,
      title: 'Antrean Baru',
      status: LibraryEntry.statusWant,
    );
    final List<Stream<List<LibraryEntry>>> streams =
        <Stream<List<LibraryEntry>>>[
          Stream<List<LibraryEntry>>.value(<LibraryEntry>[
            readingBefore,
            wantBefore,
          ]),
          Stream<List<LibraryEntry>>.value(<LibraryEntry>[
            readingAfter,
            wantBefore,
            wantAfter,
          ]),
        ];
    final FakeLibraryRepository repository = FakeLibraryRepository()
      ..watchLibraryFactory = () => streams.removeAt(0);

    await pumpLibrary(
      tester,
      repository: repository,
      connectivity: connectivity.stream,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-want')),
    );
    await tester.pumpAndSettle();
    expect(find.text(wantBefore.bookTitle), findsOneWidget);

    connectivity.add(false);
    await tester.pumpAndSettle();
    expect(find.text(wantBefore.bookTitle), findsOneWidget);
    expect(find.text(readingBefore.bookTitle), findsNothing);

    connectivity.add(true);
    await tester.pumpAndSettle();

    expect(find.text(wantBefore.bookTitle), findsOneWidget);
    expect(find.text(wantAfter.bookTitle), findsOneWidget);
    expect(find.text(readingAfter.bookTitle), findsNothing);
    expect(repository.watchLibraryCalls, 2);

    await tester.tap(
      find.byKey(const ValueKey<String>('library-section-reading')),
    );
    await tester.pumpAndSettle();

    expect(find.text(readingAfter.bookTitle), findsOneWidget);
    expect(find.text(readingBefore.bookTitle), findsNothing);
  });

  testWidgets('Mengetuk buku membuka /book/:id', (WidgetTester tester) async {
    final LibraryEntry entry = fakeLibraryEntry(7, title: 'Buku Untuk Detail');
    final _Harness harness = await pumpLibrary(
      tester,
      repository: FakeLibraryRepository(entries: <LibraryEntry>[entry]),
    );

    await tester.tap(
      find.byKey(ValueKey<String>('library-reading-${entry.bookId}')),
    );
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
          final FakeLibraryRepository repository = FakeLibraryRepository(
            entries: <LibraryEntry>[
              fakeLibraryEntry(1, title: 'Buku Sedang'),
              fakeLibraryEntry(
                2,
                title: 'Buku Antrean',
                status: LibraryEntry.statusWant,
              ),
              fakeLibraryEntry(
                3,
                title: 'Buku Tamat',
                status: LibraryEntry.statusFinished,
                finishedAt: DateTime(2026, 3, 12),
              ),
            ],
          );

          await pumpLibrary(
            tester,
            repository: repository,
            viewSize: size.value,
            theme: theme.value,
          );

          expect(find.text(AppStrings.libraryTitle), findsWidgets);
          expect(tester.takeException(), isNull);

          await tester.tap(
            find.byKey(const ValueKey<String>('library-section-want')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Buku Antrean'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(
            find.byKey(const ValueKey<String>('library-section-finished')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Buku Tamat'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(
            find.byKey(const ValueKey<String>('library-section-reading')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Buku Sedang'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

String? _count(WidgetTester tester, LibrarySection section) {
  return tester
      .widget<Text>(
        find.byKey(ValueKey<String>('library-count-${section.name}')),
      )
      .data;
}

class _Harness {
  const _Harness({required this.router});

  final GoRouter router;
}

class _LibraryTestApp extends ConsumerWidget {
  const _LibraryTestApp({required this.theme});

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
