import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_router.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_text_field.dart';
import 'package:libria/core/widgets/app_button.dart';
import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/books/data/book_cover_service.dart';
import 'package:libria/features/books/data/book_repository.dart';

import 'support/fake_book_repository.dart';

/// PNG 1x1 transparan untuk pratinjau sampul di widget test.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
  'z8BQDwAFgwJ/lK3Q6wAAAABJRU5ErkJggg==',
);

void main() {
  Future<_Harness> pumpAdminBooks(
    WidgetTester tester, {
    FakeBookRepository? repository,
    FakeBookCoverService? coverService,
    FakeBookCoverPicker? coverPicker,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final _FakeAuthRepository auth = _FakeAuthRepository();
    addTearDown(auth.dispose);

    final FakeBookRepository bookRepository =
        repository ?? FakeBookRepository();
    final FakeBookCoverService covers = coverService ?? FakeBookCoverService();
    final FakeBookCoverPicker picker = coverPicker ?? FakeBookCoverPicker();

    final ProviderContainer container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((Ref ref) => auth),
        authStateProvider.overrideWith((Ref ref) => auth.authStateChanges),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(_adminUser),
        ),
        bookRepositoryProvider.overrideWith((Ref ref) => bookRepository),
        adminDashboardRepositoryProvider.overrideWith(
          (Ref ref) => _FakeAdminDashboardRepository(),
        ),
        bookCoverServiceProvider.overrideWith((Ref ref) => covers),
        bookCoverPickerProvider.overrideWith((Ref ref) => picker),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _FormTestApp(theme: theme ?? AppTheme.light),
      ),
    );
    router.go(AppRoutes.adminBooks);
    await tester.pumpAndSettle();

    return _Harness(
      router: router,
      repository: bookRepository,
      coverService: covers,
      coverPicker: picker,
    );
  }

  Future<void> openNewForm(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.adminBooksAdd));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.adminBookNewTitle), findsOneWidget);
  }

  Future<void> openEditForm(WidgetTester tester, Book book) async {
    await tester.tap(find.text(book.title));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.adminBookEditTitle), findsOneWidget);
  }

  Finder field(String label) {
    return find.descendant(
      of: find.widgetWithText(AppTextField, label),
      matching: find.byType(TextField),
    );
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final Finder finder = field(label);
    expect(finder, findsOneWidget);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await enter(tester, AppStrings.adminBookFormTitleLabel, 'Bumi Manusia');
    await enter(
      tester,
      AppStrings.adminBookFormAuthorLabel,
      'Pramoedya Ananta Toer',
    );
    await enter(tester, AppStrings.adminBookFormIsbnLabel, '978-979-973-123-4');
    await enter(
      tester,
      AppStrings.adminBookFormPublisherLabel,
      'Lentera Dipantara',
    );
    await enter(tester, AppStrings.adminBookFormYearLabel, '1980');
    await enter(tester, AppStrings.adminBookFormPagesLabel, '535');
    await enter(tester, AppStrings.adminBookFormCategoryLabel, 'Fiksi');
    await enter(
      tester,
      AppStrings.adminBookFormSynopsisLabel,
      'Kisah Minke dan perjalanan hidupnya.',
    );
  }

  Future<void> scrollFormTo(WidgetTester tester, Finder finder) async {
    final Finder scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final Finder button = find.widgetWithText(
      PrimaryButton,
      AppStrings.adminBookFormSave,
    );
    expect(button, findsOneWidget);
    await scrollFormTo(tester, button);
    await tester.tap(button);
  }

  Future<void> tapChooseCover(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final Finder button = find.text(AppStrings.adminBookFormCoverChoose);
    expect(button, findsOneWidget);
    await scrollFormTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Formulir tambah menampilkan seluruh field FR-B1', (
    WidgetTester tester,
  ) async {
    await pumpAdminBooks(tester);
    await openNewForm(tester);

    for (final String label in <String>[
      AppStrings.adminBookFormTitleLabel,
      AppStrings.adminBookFormAuthorLabel,
      AppStrings.adminBookFormIsbnLabel,
      AppStrings.adminBookFormPublisherLabel,
      AppStrings.adminBookFormYearLabel,
      AppStrings.adminBookFormPagesLabel,
      AppStrings.adminBookFormCategoryLabel,
      AppStrings.adminBookFormSynopsisLabel,
    ]) {
      expect(field(label), findsOneWidget);
    }
    expect(find.text(AppStrings.adminBookFormSectionCover), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormCoverChoose), findsOneWidget);
    expect(field(AppStrings.adminBookFormCoverUrlLabel), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormSave), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormCoverEmpty), findsOneWidget);
  });

  testWidgets('ISBN awal dari query mengisi kolom ISBN', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpAdminBooks(tester);

    harness.router.push('${AppRoutes.adminBookNew}?isbn=978-979-973-123-4');
    await tester.pumpAndSettle();

    final TextField isbnField = tester.widget<TextField>(
      field(AppStrings.adminBookFormIsbnLabel),
    );
    expect(isbnField.controller!.text, '978-979-973-123-4');
  });

  testWidgets('Validasi menampilkan pesan per kolom', (
    WidgetTester tester,
  ) async {
    await pumpAdminBooks(tester);
    await openNewForm(tester);

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminBookFormTitleRequired), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormAuthorRequired), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormIsbnRequired), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormPagesRequired), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormYearInvalid), findsNothing);

    await enter(tester, AppStrings.adminBookFormTitleLabel, 'Bumi Manusia');
    await enter(
      tester,
      AppStrings.adminBookFormAuthorLabel,
      'Pramoedya Ananta Toer',
    );
    await enter(tester, AppStrings.adminBookFormIsbnLabel, '12345');
    await enter(tester, AppStrings.adminBookFormYearLabel, 'dua ribu');
    await enter(tester, AppStrings.adminBookFormPagesLabel, '0');

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminBookFormIsbnInvalid), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormYearInvalid), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormPagesInvalid), findsOneWidget);
  });

  testWidgets('Simpan tambah membuat buku, kembali, dan memuat ulang daftar', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpAdminBooks(tester);
    expect(harness.repository.fetchPageCalls, 1);

    await openNewForm(tester);
    await fillValidForm(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(harness.repository.createCalls, 1);
    final Book created = harness.repository.lastCreatedBook!;
    expect(created.title, 'Bumi Manusia');
    expect(created.author, 'Pramoedya Ananta Toer');
    expect(created.isbn, '9789799731234');
    expect(created.publisher, 'Lentera Dipantara');
    expect(created.year, 1980);
    expect(created.totalPages, 535);
    expect(created.category, 'Fiksi');
    expect(created.createdBy, 'admin-1');
    expect(harness.router.state.uri.path, AppRoutes.adminBooks);
    expect(harness.repository.fetchPageCalls, 2);
    expect(find.text('Bumi Manusia'), findsOneWidget);
  });

  testWidgets('Tombol simpan mencegah klik ganda selama penyimpanan', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpAdminBooks(tester);
    await openNewForm(tester);
    await fillValidForm(tester);

    final Completer<void> gate = Completer<void>();
    harness.repository.createGate = gate;
    await tapSave(tester);
    await tester.pump();

    expect(find.text(AppStrings.adminBookFormSaving), findsOneWidget);
    expect(harness.repository.createCalls, 1);

    await tester.tap(find.text(AppStrings.adminBookFormSaving));
    await tester.pump();
    expect(harness.repository.createCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(harness.repository.createCalls, 1);
  });

  testWidgets('ISBN duplikat ditolak dan isian tidak hilang', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository();
    repository.createError = const BookFailure(
      AppStrings.bookIsbnDuplicate,
      code: BookFailureCode.duplicateIsbn,
    );
    final _Harness harness = await pumpAdminBooks(
      tester,
      repository: repository,
    );

    await openNewForm(tester);
    await fillValidForm(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(harness.repository.createCalls, 1);
    expect(find.text(AppStrings.bookIsbnDuplicate), findsWidgets);
    expect(harness.router.state.uri.path, AppRoutes.adminBookNew);
    expect(
      tester
          .widget<TextField>(field(AppStrings.adminBookFormTitleLabel))
          .controller!
          .text,
      'Bumi Manusia',
    );
  });

  testWidgets(
    'Formulir ubah terisi data dan memperbarui tanpa menyentuh rating',
    (WidgetTester tester) async {
      final DateTime createdAt = DateTime(2024, 1, 2);
      final Book book = fakeBook(
        1,
        title: 'Bumi Manusia',
        ratingAverage: 4.5,
        ratingCount: 12,
        createdAt: createdAt,
      );
      final _Harness harness = await pumpAdminBooks(
        tester,
        repository: FakeBookRepository(books: <Book>[book]),
      );

      await openEditForm(tester, book);
      expect(
        tester
            .widget<TextField>(field(AppStrings.adminBookFormTitleLabel))
            .controller!
            .text,
        book.title,
      );
      expect(
        tester
            .widget<TextField>(field(AppStrings.adminBookFormPagesLabel))
            .controller!
            .text,
        '${book.totalPages}',
      );

      await enter(
        tester,
        AppStrings.adminBookFormTitleLabel,
        'Bumi Manusia Edisi Baru',
      );
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(harness.repository.updateCalls, 1);
      final Book updated = harness.repository.lastUpdatedBook!;
      expect(updated.id, book.id);
      expect(updated.title, 'Bumi Manusia Edisi Baru');
      expect(updated.ratingAverage, 4.5);
      expect(updated.ratingCount, 12);
      expect(updated.createdBy, 'admin-1');
      expect(updated.createdAt, createdAt);
      expect(harness.router.state.uri.path, AppRoutes.adminBooks);
      expect(harness.repository.fetchPageCalls, 2);
      expect(find.text('Bumi Manusia Edisi Baru'), findsOneWidget);
    },
  );

  testWidgets('Ubah tanpa sampul baru mempertahankan sampul lama', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(
      1,
      title: 'Bumi Manusia',
      coverUrl: 'https://contoh.com/sampul-lama.jpg',
    );
    final _Harness harness = await pumpAdminBooks(
      tester,
      repository: FakeBookRepository(books: <Book>[book]),
    );

    await openEditForm(tester, book);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(harness.coverService.uploadCalls, 0);
    expect(
      harness.repository.lastUpdatedBook!.coverUrl,
      'https://contoh.com/sampul-lama.jpg',
    );
  });

  testWidgets('Sampul dari galeri dipratinjau dan diunggah saat simpan', (
    WidgetTester tester,
  ) async {
    final FakeBookCoverService covers = FakeBookCoverService();
    final FakeBookCoverPicker picker = FakeBookCoverPicker(
      result: PickedCover(path: '/tmp/cover.png', bytes: _tinyPng),
    );
    final _Harness harness = await pumpAdminBooks(
      tester,
      coverService: covers,
      coverPicker: picker,
    );

    await openNewForm(tester);
    await fillValidForm(tester);
    await tapChooseCover(tester);

    expect(picker.calls, 1);
    expect(find.text(AppStrings.adminBookFormCoverChange), findsOneWidget);

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(covers.uploadCalls, 1);
    expect(covers.lastPath, '/tmp/cover.png');
    expect(harness.repository.assertIsbnCalls, 1);
    expect(
      harness.repository.lastCreatedBook!.coverUrl,
      FakeBookCoverService.secureUrl,
    );
  });

  testWidgets('URL sampul manual disimpan tanpa mengunggah gambar', (
    WidgetTester tester,
  ) async {
    final FakeBookCoverService covers = FakeBookCoverService();
    final _Harness harness = await pumpAdminBooks(tester, coverService: covers);

    await openNewForm(tester);
    await fillValidForm(tester);
    await enter(
      tester,
      AppStrings.adminBookFormCoverUrlLabel,
      'https://contoh.com/sampul-manual.jpg',
    );
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(covers.uploadCalls, 0);
    expect(
      harness.repository.lastCreatedBook!.coverUrl,
      'https://contoh.com/sampul-manual.jpg',
    );
  });

  testWidgets('Mengosongkan URL sampul menyimpan buku tanpa sampul', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(
      1,
      title: 'Bumi Manusia',
      coverUrl: 'https://contoh.com/sampul-lama.jpg',
    );
    final _Harness harness = await pumpAdminBooks(
      tester,
      repository: FakeBookRepository(books: <Book>[book]),
    );

    await openEditForm(tester, book);
    await enter(tester, AppStrings.adminBookFormCoverUrlLabel, '');
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(harness.repository.lastUpdatedBook!.coverUrl, isNull);
  });

  testWidgets('ISBN duplikat ditolak sebelum sampul diunggah', (
    WidgetTester tester,
  ) async {
    final FakeBookRepository repository = FakeBookRepository()
      ..assertIsbnError = const BookFailure(
        AppStrings.bookIsbnDuplicate,
        code: BookFailureCode.duplicateIsbn,
      );
    final FakeBookCoverService covers = FakeBookCoverService();
    final FakeBookCoverPicker picker = FakeBookCoverPicker(
      result: PickedCover(path: '/tmp/cover.png', bytes: _tinyPng),
    );
    final _Harness harness = await pumpAdminBooks(
      tester,
      repository: repository,
      coverService: covers,
      coverPicker: picker,
    );

    await openNewForm(tester);
    await fillValidForm(tester);
    await tapChooseCover(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.assertIsbnCalls, 1);
    expect(covers.uploadCalls, 0);
    expect(repository.createCalls, 0);
    expect(find.text(AppStrings.bookIsbnDuplicate), findsWidgets);
    expect(harness.router.state.uri.path, AppRoutes.adminBookNew);
  });

  testWidgets('Kegagalan unggah sampul mempertahankan isian formulir', (
    WidgetTester tester,
  ) async {
    final FakeBookCoverService covers = FakeBookCoverService()
      ..error = const BookCoverFailure(AppStrings.bookCoverUploadError);
    final FakeBookCoverPicker picker = FakeBookCoverPicker(
      result: PickedCover(path: '/tmp/cover.png', bytes: _tinyPng),
    );
    final _Harness harness = await pumpAdminBooks(
      tester,
      coverService: covers,
      coverPicker: picker,
    );

    await openNewForm(tester);
    await fillValidForm(tester);
    await tapChooseCover(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(covers.uploadCalls, 1);
    expect(harness.repository.createCalls, 0);
    expect(find.text(AppStrings.bookCoverUploadError), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.adminBookNew);
    expect(
      tester
          .widget<TextField>(field(AppStrings.adminBookFormTitleLabel))
          .controller!
          .text,
      'Bumi Manusia',
    );
  });

  testWidgets('Membatalkan galeri tidak mengubah sampul atau pesan', (
    WidgetTester tester,
  ) async {
    final FakeBookCoverPicker picker = FakeBookCoverPicker();
    await pumpAdminBooks(tester, coverPicker: picker);

    await openNewForm(tester);
    await tapChooseCover(tester);

    expect(picker.calls, 1);
    expect(find.text(AppStrings.adminBookFormCoverEmpty), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormCoverChange), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Pesan offline ditampilkan saat unggah tanpa koneksi', (
    WidgetTester tester,
  ) async {
    final FakeBookCoverService covers = FakeBookCoverService()
      ..error = const BookCoverFailure(AppStrings.bookCoverOffline);
    final FakeBookCoverPicker picker = FakeBookCoverPicker(
      result: PickedCover(path: '/tmp/cover.png', bytes: _tinyPng),
    );
    final _Harness harness = await pumpAdminBooks(
      tester,
      coverService: covers,
      coverPicker: picker,
    );

    await openNewForm(tester);
    await fillValidForm(tester);
    await tapChooseCover(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.bookCoverOffline), findsOneWidget);
    expect(harness.repository.createCalls, 0);
    expect(harness.router.state.uri.path, AppRoutes.adminBookNew);
  });

  testWidgets('Langsung membuka formulir dan simpan tetap menuju daftar buku', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpAdminBooks(tester);
    expect(harness.repository.fetchPageCalls, 1);

    harness.router.go('${AppRoutes.adminBookNew}?isbn=978-979-973-123-4');
    await tester.pumpAndSettle();
    await enter(tester, AppStrings.adminBookFormTitleLabel, 'Bumi Manusia');
    await enter(
      tester,
      AppStrings.adminBookFormAuthorLabel,
      'Pramoedya Ananta Toer',
    );
    await enter(tester, AppStrings.adminBookFormPagesLabel, '535');
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(harness.repository.createCalls, 1);
    expect(harness.router.state.uri.path, AppRoutes.adminBooks);
    expect(find.text('Bumi Manusia'), findsOneWidget);
  });

  testWidgets('Buku yang diubah tidak ditemukan menampilkan pesan ramah', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpAdminBooks(tester);

    harness.router.push(AppRoutes.adminBookEditPath('tidak-ada'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.bookNotFound), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormNotFoundMessage), findsOneWidget);
    expect(find.text(AppStrings.adminBookFormBackToList), findsOneWidget);
  });

  testWidgets('Keadaan memuat dan galat saat mengambil buku ditangani', (
    WidgetTester tester,
  ) async {
    final Book book = fakeBook(1, title: 'Bumi Manusia');
    final FakeBookRepository repository = FakeBookRepository(
      books: <Book>[book],
    );
    repository.getByIdFailuresRemaining = 1;
    final Completer<void> gate = Completer<void>();
    repository.getByIdGate = gate;
    final _Harness harness = await pumpAdminBooks(
      tester,
      repository: repository,
    );

    harness.router.push(AppRoutes.adminBookEditPath(book.id));
    await tester.pump();
    await tester.pump();
    expect(find.text(AppStrings.adminBookFormLoading), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminBookFormLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    repository.getByIdGate = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.getByIdCalls, 2);
    expect(find.text(AppStrings.adminBookFormLoadError), findsNothing);
    expect(field(AppStrings.adminBookFormTitleLabel), findsOneWidget);
  });

  final List<Size> responsiveSizes = <Size>[
    const Size(360, 800),
    const Size(640, 360),
    const Size(800, 1280),
    const Size(1280, 800),
  ];

  for (final Size size in responsiveSizes) {
    testWidgets(
      'Formulir muat pada ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        await pumpAdminBooks(
          tester,
          viewSize: size,
          theme: size.width >= 600 ? AppTheme.dark : AppTheme.light,
        );
        await openNewForm(tester);

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppStrings.adminBookFormSectionDetails),
          findsOneWidget,
        );
        expect(find.text(AppStrings.adminBookFormSectionCover), findsOneWidget);
        expect(find.text(AppStrings.adminBookFormSave), findsOneWidget);
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
  const _Harness({
    required this.router,
    required this.repository,
    required this.coverService,
    required this.coverPicker,
  });

  final GoRouter router;
  final FakeBookRepository repository;
  final FakeBookCoverService coverService;
  final FakeBookCoverPicker coverPicker;
}

class FakeBookCoverService implements BookCoverService {
  static const String secureUrl =
      'https://res.cloudinary.com/ofl9voii/image/upload/v1/libria/covers/'
      'cover-1.png';

  int uploadCalls = 0;
  String? lastPath;
  Object? error;
  Completer<void>? uploadGate;

  @override
  Future<String> uploadCover(File file) async {
    uploadCalls++;
    lastPath = file.path;
    if (uploadGate != null) {
      await uploadGate!.future;
    }
    if (error != null) {
      throw error!;
    }
    return secureUrl;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBookCoverPicker implements BookCoverPicker {
  FakeBookCoverPicker({this.result});

  PickedCover? result;
  Object? error;
  int calls = 0;

  @override
  Future<PickedCover?> pickFromGallery() async {
    calls++;
    if (error != null) {
      throw error!;
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FormTestApp extends ConsumerWidget {
  const _FormTestApp({required this.theme});

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
