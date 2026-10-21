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
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';
import 'package:libria/core/widgets/app_text_field.dart';
import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_isbn_log_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpIsbnLogs(
    WidgetTester tester, {
    required FakeIsbnLogRepository repository,
    AdminDashboardRepository? dashboardRepository,
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
        isbnLogRepositoryProvider.overrideWith((Ref ref) => repository),
        bookRepositoryProvider.overrideWith((Ref ref) => FakeBookRepository()),
        adminDashboardRepositoryProvider.overrideWith(
          (Ref ref) => dashboardRepository ?? _FakeAdminDashboardRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _IsbnLogsTestApp(theme: theme ?? AppTheme.light),
      ),
    );
    router.go(AppRoutes.adminIsbnLogs);

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _Harness(router: router, repository: repository);
  }

  testWidgets('Menampilkan keadaan loading saat antrean dimuat', (
    WidgetTester tester,
  ) async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[fakeIsbnLog(1)],
    );
    repository.fetchPageGate = Completer<void>();

    await pumpIsbnLogs(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.adminIsbnLogsLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsNothing);

    repository.fetchPageGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminIsbnLogsLoading), findsNothing);
    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsNothing);
  });

  testWidgets(
    'Menampilkan ISBN, jumlah pemindaian, waktu terakhir, dan status',
    (WidgetTester tester) async {
      final IsbnLog first = fakeIsbnLog(
        1,
        isbn: '978-979-973-123-4',
        scanCount: 3,
        lastScannedAt: DateTime(2026, 10, 21, 14, 5),
      );
      final IsbnLog second = fakeIsbnLog(
        2,
        isbn: '9786020331951',
        scanCount: 1,
        lastScannedAt: DateTime(2026, 10, 20, 9, 30),
      );
      final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
        logs: <IsbnLog>[first, second],
      );

      await pumpIsbnLogs(tester, repository: repository);

      expect(find.text(AppStrings.adminIsbnLogsTitle), findsOneWidget);
      expect(find.text(AppStrings.adminIsbnLogsSubtitle), findsOneWidget);
      expect(find.text(AppStrings.isbnLabel(first.isbn)), findsOneWidget);
      expect(
        find.text(AppStrings.adminIsbnLogsScanCount(first.scanCount)),
        findsOneWidget,
      );
      expect(
        find.text(
          AppStrings.adminIsbnLogsLastScanned('21 Oktober 2026, 14.05'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.adminIsbnLogsStatusUnhandled),
        findsNWidgets(2),
      );
      expect(find.text(AppStrings.isbnLabel(second.isbn)), findsOneWidget);
      expect(find.byType(AppBottomNavBar), findsOneWidget);
    },
  );

  testWidgets('Muat Lebih Banyak menambah halaman tanpa duplikat', (
    WidgetTester tester,
  ) async {
    final List<IsbnLog> firstPage = List<IsbnLog>.generate(
      isbnLogPageSize,
      (int index) => fakeIsbnLog(index + 1),
    );
    final List<IsbnLog> secondPage = <IsbnLog>[
      firstPage.last,
      ...List<IsbnLog>.generate(4, (int index) => fakeIsbnLog(index + 21)),
    ];
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
      ..pages = <List<IsbnLog>>[firstPage, secondPage];

    await pumpIsbnLogs(tester, repository: repository);

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminIsbnLogsLoadMore),
      400,
      scrollable: listScrollable,
    );

    expect(find.text(AppStrings.adminIsbnLogsLoadMore), findsOneWidget);
    expect(repository.fetchPageCalls, 1);

    await tester.tap(find.text(AppStrings.adminIsbnLogsLoadMore));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminIsbnLogsLoadMore), findsNothing);

    await tester.scrollUntilVisible(
      find.text(AppStrings.isbnLabel(secondPage.last.isbn)),
      400,
      scrollable: listScrollable,
    );
    expect(
      find.text(AppStrings.isbnLabel(secondPage.last.isbn)),
      findsOneWidget,
    );
  });

  testWidgets('Antrean kosong menampilkan pesan bahasa Indonesia', (
    WidgetTester tester,
  ) async {
    await pumpIsbnLogs(tester, repository: FakeIsbnLogRepository());

    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsLoadMore), findsNothing);
  });

  testWidgets('Galat menampilkan pesan ramah dan Coba Lagi memuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[fakeIsbnLog(1)],
    )..fetchPageFailuresRemaining = 1;

    await pumpIsbnLogs(tester, repository: repository);

    expect(find.text(AppStrings.adminIsbnLogsLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsNothing);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminIsbnLogsLoadError), findsNothing);
    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsNothing);
  });

  testWidgets('Galat izin menampilkan pesan ramah dari repository', (
    WidgetTester tester,
  ) async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
      ..fetchError = const IsbnLogFailure(
        AppStrings.isbnLogListPermissionDenied,
      );

    await pumpIsbnLogs(tester, repository: repository);

    expect(find.text(AppStrings.isbnLogListPermissionDenied), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets('Gagal memuat halaman berikutnya bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final List<IsbnLog> firstPage = List<IsbnLog>.generate(
      isbnLogPageSize,
      (int index) => fakeIsbnLog(index + 1),
    );
    final List<IsbnLog> secondPage = List<IsbnLog>.generate(
      2,
      (int index) => fakeIsbnLog(index + 21),
    );
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
      ..pages = <List<IsbnLog>>[firstPage, secondPage];

    await pumpIsbnLogs(tester, repository: repository);
    repository.fetchPageFailuresRemaining = 1;

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminIsbnLogsLoadMore),
      400,
      scrollable: listScrollable,
    );
    await tester.tap(find.text(AppStrings.adminIsbnLogsLoadMore));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminIsbnLogsLoadMoreError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    // Geser sedikit lagi agar tombol di bawah pesan galat tidak tertutup
    // bilah navigasi bawah.
    await tester.drag(listScrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminIsbnLogsLoadMoreError), findsNothing);
    expect(find.text(AppStrings.adminIsbnLogsLoadMore), findsNothing);
    await tester.scrollUntilVisible(
      find.text(AppStrings.isbnLabel(secondPage.last.isbn)),
      400,
      scrollable: listScrollable,
    );
    expect(
      find.text(AppStrings.isbnLabel(secondPage.last.isbn)),
      findsOneWidget,
    );
  });

  testWidgets('Setiap log menampilkan aksi tambah buku dan tandai ditangani', (
    WidgetTester tester,
  ) async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[fakeIsbnLog(1), fakeIsbnLog(2)],
    );

    await pumpIsbnLogs(tester, repository: repository);

    expect(find.text(AppStrings.adminIsbnLogsAddBook), findsNWidgets(2));
    expect(find.text(AppStrings.adminIsbnLogsMarkHandled), findsNWidgets(2));
  });

  testWidgets(
    'Menandai log menampilkan progres, mengabaikan klik ganda, lalu membuang baris',
    (WidgetTester tester) async {
      final IsbnLog first = fakeIsbnLog(1);
      final IsbnLog second = fakeIsbnLog(2);
      final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
        logs: <IsbnLog>[first, second],
      );
      await pumpIsbnLogs(tester, repository: repository);

      final Completer<void> gate = Completer<void>();
      repository.markHandledGate = gate;
      final Finder markButton = find
          .text(AppStrings.adminIsbnLogsMarkHandled)
          .first;

      // Dua ketukan sebelum bingkai berikutnya tetap ditangani satu kali.
      await tester.tap(markButton);
      await tester.tap(markButton);
      await tester.pump();

      expect(repository.markHandledCalls, 1);
      expect(find.text(AppStrings.adminIsbnLogsMarkingHandled), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final Finder firstCard = find.byType(Card).first;
      final OutlinedButton addAction = tester.widget<OutlinedButton>(
        find.descendant(
          of: firstCard,
          matching: find.widgetWithText(
            OutlinedButton,
            AppStrings.adminIsbnLogsAddBook,
          ),
        ),
      );
      final OutlinedButton markAction = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text(AppStrings.adminIsbnLogsMarkingHandled),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(addAction.onPressed, isNull);
      expect(markAction.onPressed, isNull);
      expect(
        find.text(AppStrings.adminIsbnLogsMarkHandledSuccess),
        findsNothing,
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.markHandledCalls, 1);
      expect(find.text(AppStrings.isbnLabel(first.isbn)), findsNothing);
      expect(find.text(AppStrings.isbnLabel(second.isbn)), findsOneWidget);
      expect(
        find.text(AppStrings.adminIsbnLogsMarkHandledSuccess),
        findsOneWidget,
      );
      expect(repository.fetchPageCalls, 1);
    },
  );

  testWidgets('Kegagalan menandai mempertahankan baris dan pesan ramah', (
    WidgetTester tester,
  ) async {
    final IsbnLog log = fakeIsbnLog(1);
    final FakeIsbnLogRepository repository =
        FakeIsbnLogRepository(logs: <IsbnLog>[log])
          ..markHandledError = const IsbnLogFailure(
            AppStrings.isbnLogHandleNetworkError,
          );
    await pumpIsbnLogs(tester, repository: repository);

    await tester.tap(find.text(AppStrings.adminIsbnLogsMarkHandled));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.isbnLogHandleNetworkError), findsOneWidget);
    expect(find.text(AppStrings.isbnLabel(log.isbn)), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsMarkHandled), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsNothing);
  });

  testWidgets('Menandai baris terakhir menampilkan keadaan kosong', (
    WidgetTester tester,
  ) async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[fakeIsbnLog(1)],
    );
    await pumpIsbnLogs(tester, repository: repository);

    await tester.tap(find.text(AppStrings.adminIsbnLogsMarkHandled));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminIsbnLogsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsMarkHandled), findsNothing);
  });

  testWidgets('Tambah buku membuka formulir dengan ISBN log terisi', (
    WidgetTester tester,
  ) async {
    final IsbnLog log = fakeIsbnLog(1, isbn: '978-979-973-123-4');
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[log],
    );
    final _Harness harness = await pumpIsbnLogs(tester, repository: repository);

    await tester.tap(find.text(AppStrings.adminIsbnLogsAddBook));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminBookNew);
    expect(harness.router.state.uri.queryParameters['isbn'], log.isbn);
    expect(find.text(AppStrings.adminBookNewTitle), findsOneWidget);
    final TextField isbnField = tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(
          AppTextField,
          AppStrings.adminBookFormIsbnLabel,
        ),
        matching: find.byType(TextField),
      ),
    );
    expect(isbnField.controller!.text, log.isbn);
    expect(repository.markHandledCalls, 0);
  });

  testWidgets('Angka log dashboard turun setelah log ditandai', (
    WidgetTester tester,
  ) async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[fakeIsbnLog(1), fakeIsbnLog(2)],
    );
    final _CountingDashboardRepository dashboard = _CountingDashboardRepository(
      repository,
    );
    final _Harness harness = await pumpIsbnLogs(
      tester,
      repository: repository,
      dashboardRepository: dashboard,
    );

    await tester.tap(find.text(AppStrings.adminNavDashboard));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, AppRoutes.admin);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text(AppStrings.adminNavIsbnLogs));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adminIsbnLogsMarkHandled).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.adminNavDashboard));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(dashboard.fetchCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('Simpan dari log kembali ke Kelola Buku tanpa menandai log', (
    WidgetTester tester,
  ) async {
    final IsbnLog log = fakeIsbnLog(1, isbn: '9789799731234');
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[log],
    );
    final _Harness harness = await pumpIsbnLogs(tester, repository: repository);

    await tester.tap(find.text(AppStrings.adminIsbnLogsAddBook));
    await tester.pumpAndSettle();

    await tester.enterText(
      _formField(AppStrings.adminBookFormTitleLabel),
      'Bumi Manusia',
    );
    await tester.enterText(
      _formField(AppStrings.adminBookFormAuthorLabel),
      'Pramoedya Ananta Toer',
    );
    await tester.enterText(
      _formField(AppStrings.adminBookFormPagesLabel),
      '535',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final Finder formScrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminBookFormSave),
      300,
      scrollable: formScrollable,
    );
    await tester.tap(find.text(AppStrings.adminBookFormSave));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminBooks);
    expect(repository.markHandledCalls, 0);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNavBar),
        matching: find.text(AppStrings.adminNavIsbnLogs),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.isbnLabel(log.isbn)), findsOneWidget);
    expect(find.text(AppStrings.adminIsbnLogsMarkHandled), findsOneWidget);
  });

  final List<Size> responsiveSizes = <Size>[
    const Size(360, 800),
    const Size(640, 360),
    const Size(800, 1280),
    const Size(1280, 800),
  ];

  for (final Size size in responsiveSizes) {
    testWidgets(
      'Antrean log ISBN muat pada ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
          logs: <IsbnLog>[
            fakeIsbnLog(1, scanCount: 2),
            fakeIsbnLog(2, scanCount: 1),
          ],
        );

        await pumpIsbnLogs(
          tester,
          repository: repository,
          viewSize: size,
          theme: size.width >= 600 ? AppTheme.dark : AppTheme.light,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.adminIsbnLogsTitle), findsOneWidget);
        expect(find.text(AppStrings.adminIsbnLogsSubtitle), findsOneWidget);
        expect(
          find.text(AppStrings.adminIsbnLogsStatusUnhandled),
          findsWidgets,
        );
        expect(find.text(AppStrings.adminIsbnLogsAddBook), findsWidgets);
        expect(find.text(AppStrings.adminIsbnLogsMarkHandled), findsWidgets);
        expect(find.byType(AppBottomNavBar), findsOneWidget);
      },
    );
  }
}

Finder _formField(String label) {
  return find.descendant(
    of: find.widgetWithText(AppTextField, label),
    matching: find.byType(TextField),
  );
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
  final FakeIsbnLogRepository repository;
}

class _IsbnLogsTestApp extends ConsumerWidget {
  const _IsbnLogsTestApp({required this.theme});

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

/// Angka dashboard yang mengikuti isi antrean log ISBN palsu.
class _CountingDashboardRepository implements AdminDashboardRepository {
  _CountingDashboardRepository(this.logs);

  final FakeIsbnLogRepository logs;
  int fetchCalls = 0;

  @override
  Future<AdminDashboardStats> fetchStats() async {
    fetchCalls++;
    return AdminDashboardStats(
      totalBooks: 0,
      openReports: 0,
      unhandledIsbnLogs: await logs.countUnhandledIsbnLogs(),
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
