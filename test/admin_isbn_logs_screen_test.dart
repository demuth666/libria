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
          (Ref ref) => _FakeAdminDashboardRepository(),
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
          findsNWidgets(2),
        );
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
