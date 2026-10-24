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
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';
import 'package:libria/features/reports/data/report.dart';
import 'package:libria/features/reports/data/report_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_isbn_log_repository.dart';
import 'support/fake_report_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpReports(
    WidgetTester tester, {
    required FakeReportRepository repository,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1,
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
        reportRepositoryProvider.overrideWith((Ref ref) => repository),
        adminDashboardRepositoryProvider.overrideWith(
          (Ref ref) => _FakeAdminDashboardRepository(),
        ),
        bookRepositoryProvider.overrideWith((Ref ref) => FakeBookRepository()),
        isbnLogRepositoryProvider.overrideWith(
          (Ref ref) => FakeIsbnLogRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    router.go(AppRoutes.adminReports);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _ReportsTestApp(
          theme: theme ?? AppTheme.light,
          textScale: textScale,
        ),
      ),
    );

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _Harness(router: router, repository: repository);
  }

  testWidgets('Menampilkan keadaan loading saat laporan dimuat', (
    WidgetTester tester,
  ) async {
    final FakeReportRepository repository = FakeReportRepository(
      reports: <Report>[fakeReport(1)],
    )..fetchPageGate = Completer<void>();

    await pumpReports(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.adminReportsLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.adminReportsEmptyTitle), findsNothing);

    repository.fetchPageGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminReportsLoading), findsNothing);
    expect(find.text(AppStrings.adminReportsEmptyTitle), findsNothing);
  });

  testWidgets('Menampilkan isi konten, alasan, jenis, dan aksi moderasi', (
    WidgetTester tester,
  ) async {
    final Report postReport = fakeReport(
      1,
      reason: Report.reasonAbusive,
      targetPreview: 'Postingan yang melanggar aturan komunitas.',
    );
    final Report replyReport = fakeReport(
      2,
      targetType: Report.targetReply,
      postId: 'post-9',
      replyId: 'reply-9',
      reason: Report.reasonInappropriate,
      targetPreview: 'Balasan yang tidak pantas.',
    );
    final FakeReportRepository repository = FakeReportRepository(
      reports: <Report>[postReport, replyReport],
    );

    await pumpReports(tester, repository: repository);

    expect(find.text(AppStrings.adminReportsTitle), findsOneWidget);
    expect(find.text(AppStrings.adminReportsSubtitle), findsOneWidget);
    expect(find.text(AppStrings.adminReportsTargetPost), findsOneWidget);
    expect(find.text(AppStrings.adminReportsTargetReply), findsOneWidget);
    expect(
      find.text(AppStrings.adminReportsReason(Report.reasonAbusive)),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.adminReportsReason(Report.reasonInappropriate)),
      findsOneWidget,
    );
    expect(find.text(postReport.targetPreview), findsOneWidget);
    expect(find.text(replyReport.targetPreview), findsOneWidget);
    expect(find.textContaining('Dilaporkan'), findsNWidgets(2));
    expect(find.text(AppStrings.adminReportsDeleteContent), findsNWidgets(2));
    expect(find.text(AppStrings.adminReportsDismiss), findsNWidgets(2));
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('Daftar kosong menampilkan pesan bahasa Indonesia', (
    WidgetTester tester,
  ) async {
    await pumpReports(tester, repository: FakeReportRepository());

    expect(find.text(AppStrings.adminReportsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.adminReportsEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.adminReportsLoadMore), findsNothing);
  });

  testWidgets('Galat menampilkan pesan ramah dan Coba Lagi memuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeReportRepository repository = FakeReportRepository(
      reports: <Report>[fakeReport(1)],
    )..fetchPageFailuresRemaining = 1;

    await pumpReports(tester, repository: repository);

    expect(find.text(AppStrings.adminReportsLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.adminReportsEmptyTitle), findsNothing);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminReportsLoadError), findsNothing);
    expect(find.text(AppStrings.adminReportsEmptyTitle), findsNothing);
  });

  testWidgets('Galat izin menampilkan pesan ramah dari repository', (
    WidgetTester tester,
  ) async {
    final FakeReportRepository repository = FakeReportRepository()
      ..fetchError = const ReportFailure(
        AppStrings.adminReportsLoadPermissionDenied,
      );

    await pumpReports(tester, repository: repository);

    expect(
      find.text(AppStrings.adminReportsLoadPermissionDenied),
      findsOneWidget,
    );
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets(
    'Hapus Konten meminta konfirmasi, menampilkan progres, lalu membuang baris',
    (WidgetTester tester) async {
      final Report report = fakeReport(
        1,
        targetPreview: 'Konten yang akan dihapus.',
      );
      final FakeReportRepository repository = FakeReportRepository(
        reports: <Report>[report],
      );
      await pumpReports(tester, repository: repository);

      await tester.tap(
        find.byKey(const ValueKey<String>('admin-report-delete-report-1')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(AppStrings.adminReportsDeleteDialogTitle),
        findsOneWidget,
      );

      final Completer<void> gate = Completer<void>();
      repository.deleteGate = gate;
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(AppStrings.adminReportsDeleteConfirm),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(repository.deleteContentCalls, 1);
      expect(find.text(AppStrings.adminReportsDeletingContent), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.lastDeletedReport?.id, report.id);
      expect(find.text(AppStrings.adminReportsDeleteSuccess), findsOneWidget);
      expect(find.text(report.targetPreview), findsNothing);
      expect(find.text(AppStrings.adminReportsEmptyTitle), findsOneWidget);
    },
  );

  testWidgets('Batal pada dialog tidak menghapus konten', (
    WidgetTester tester,
  ) async {
    final Report report = fakeReport(1);
    final FakeReportRepository repository = FakeReportRepository(
      reports: <Report>[report],
    );
    await pumpReports(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-report-delete-report-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(AppStrings.cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteContentCalls, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(report.targetPreview), findsOneWidget);
  });

  testWidgets('Abaikan menutup laporan tanpa menghapus konten', (
    WidgetTester tester,
  ) async {
    final Report report = fakeReport(1);
    final FakeReportRepository repository = FakeReportRepository(
      reports: <Report>[report],
    );
    await pumpReports(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-report-dismiss-report-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.dismissCalls, 1);
    expect(repository.lastDismissedReport?.id, report.id);
    expect(find.text(AppStrings.adminReportsDismissSuccess), findsOneWidget);
    expect(find.text(report.targetPreview), findsNothing);
    expect(find.text(AppStrings.adminReportsEmptyTitle), findsOneWidget);
  });

  testWidgets('Kegagalan aksi mempertahankan baris dan pesan ramah', (
    WidgetTester tester,
  ) async {
    final Report report = fakeReport(
      1,
      targetPreview: 'Konten yang gagal dihapus.',
    );
    final FakeReportRepository repository =
        FakeReportRepository(reports: <Report>[report])
          ..deleteError = const ReportFailure(
            AppStrings.adminReportsActionNetworkError,
          );
    await pumpReports(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-report-delete-report-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(AppStrings.adminReportsDeleteConfirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.adminReportsActionNetworkError),
      findsOneWidget,
    );
    expect(find.text(report.targetPreview), findsOneWidget);
    expect(find.text(AppStrings.adminReportsDeleteContent), findsOneWidget);
    expect(find.text(AppStrings.adminReportsEmptyTitle), findsNothing);
  });

  testWidgets('Muat Lebih Banyak menambah halaman tanpa duplikat', (
    WidgetTester tester,
  ) async {
    final List<Report> firstPage = List<Report>.generate(
      reportPageSize,
      (int index) => fakeReport(index + 1),
    );
    final List<Report> secondPage = <Report>[
      firstPage.last,
      ...List<Report>.generate(3, (int index) => fakeReport(index + 21)),
    ];
    final FakeReportRepository repository = FakeReportRepository()
      ..pages = <List<Report>>[firstPage, secondPage];

    await pumpReports(tester, repository: repository);

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminReportsLoadMore),
      400,
      scrollable: listScrollable,
    );

    expect(find.text(AppStrings.adminReportsLoadMore), findsOneWidget);
    expect(repository.fetchPageCalls, 1);

    await tester.tap(find.text(AppStrings.adminReportsLoadMore));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminReportsLoadMore), findsNothing);

    await tester.scrollUntilVisible(
      find.text(secondPage.last.targetPreview),
      400,
      scrollable: listScrollable,
    );
    expect(find.text(secondPage.last.targetPreview), findsOneWidget);
  });

  testWidgets('Gagal memuat halaman berikutnya bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final List<Report> firstPage = List<Report>.generate(
      reportPageSize,
      (int index) => fakeReport(index + 1),
    );
    final List<Report> secondPage = <Report>[
      fakeReport(21, targetPreview: 'Laporan halaman kedua.'),
    ];
    final FakeReportRepository repository = FakeReportRepository()
      ..pages = <List<Report>>[firstPage, secondPage];

    await pumpReports(tester, repository: repository);
    repository.fetchPageFailuresRemaining = 1;

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminReportsLoadMore),
      400,
      scrollable: listScrollable,
    );
    await tester.tap(find.text(AppStrings.adminReportsLoadMore));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminReportsLoadMoreError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    await tester.drag(listScrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminReportsLoadMoreError), findsNothing);
    expect(find.text(AppStrings.adminReportsLoadMore), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Laporan halaman kedua.'),
      400,
      scrollable: listScrollable,
    );
    expect(find.text('Laporan halaman kedua.'), findsOneWidget);
  });

  final List<({Size size, ThemeData theme, double textScale})> layouts =
      <({Size size, ThemeData theme, double textScale})>[
        (size: const Size(360, 800), theme: AppTheme.light, textScale: 1.5),
        (size: const Size(640, 360), theme: AppTheme.light, textScale: 1),
        (size: const Size(800, 1280), theme: AppTheme.dark, textScale: 1),
        (size: const Size(1280, 800), theme: AppTheme.dark, textScale: 1.3),
      ];

  for (final ({Size size, ThemeData theme, double textScale}) layout
      in layouts) {
    testWidgets(
      'Moderasi laporan muat pada ${layout.size.width.toInt()}x${layout.size.height.toInt()} skala ${layout.textScale}',
      (WidgetTester tester) async {
        final FakeReportRepository repository = FakeReportRepository(
          reports: <Report>[
            fakeReport(
              1,
              reason: Report.reasonAbusive,
              targetPreview:
                  'Konten yang cukup panjang untuk menguji pembungkusan teks '
                  'pada kartu moderasi laporan.',
            ),
            fakeReport(
              2,
              targetType: Report.targetReply,
              replyId: 'reply-2',
              reason: Report.reasonOther,
            ),
          ],
        );

        await pumpReports(
          tester,
          repository: repository,
          viewSize: layout.size,
          theme: layout.theme,
          textScale: layout.textScale,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.adminReportsTitle), findsOneWidget);
        expect(find.text(AppStrings.adminReportsSubtitle), findsOneWidget);
        expect(find.text(AppStrings.adminReportsDeleteContent), findsWidgets);
        expect(find.text(AppStrings.adminReportsDismiss), findsWidgets);
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
  final FakeReportRepository repository;
}

class _ReportsTestApp extends ConsumerWidget {
  const _ReportsTestApp({required this.theme, required this.textScale});

  final ThemeData theme;
  final double textScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(
      theme: theme,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
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
