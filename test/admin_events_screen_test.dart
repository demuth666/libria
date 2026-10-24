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
import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/core/widgets/app_bottom_nav_bar.dart';
import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/events/data/app_event.dart';
import 'package:libria/features/events/data/event_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';
import 'package:libria/features/reports/data/report_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_event_repository.dart';
import 'support/fake_isbn_log_repository.dart';
import 'support/fake_report_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpEvents(
    WidgetTester tester, {
    required FakeEventRepository repository,
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
        adminDashboardRepositoryProvider.overrideWith(
          (Ref ref) => _FakeAdminDashboardRepository(),
        ),
        bookRepositoryProvider.overrideWith((Ref ref) => FakeBookRepository()),
        isbnLogRepositoryProvider.overrideWith(
          (Ref ref) => FakeIsbnLogRepository(),
        ),
        reportRepositoryProvider.overrideWith(
          (Ref ref) => FakeReportRepository(),
        ),
        eventRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    router.go(AppRoutes.adminEvents);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _EventsTestApp(
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

  testWidgets('Menampilkan keadaan loading saat kegiatan dimuat', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[fakeEvent(1)],
    )..fetchPageGate = Completer<void>();

    await pumpEvents(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.adminEventsLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.adminEventsEmptyTitle), findsNothing);

    repository.fetchPageGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminEventsLoading), findsNothing);
    expect(find.text(AppStrings.adminEventsEmptyTitle), findsNothing);
  });

  testWidgets('Menampilkan judul, jadwal, lokasi, dan jumlah peserta', (
    WidgetTester tester,
  ) async {
    final AppEvent event = fakeEvent(
      1,
      title: 'Bedah Buku Sejarah',
      description: 'Diskusi terbuka mengenai buku sejarah Indonesia.',
      location: 'Ruang Baca Utama',
      participantCount: 12,
      startAt: DateTime(2026, 11, 5, 19, 30),
    );
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[event],
    );

    await pumpEvents(tester, repository: repository);

    expect(find.text(AppStrings.adminEventsTitle), findsOneWidget);
    expect(find.text(AppStrings.adminEventsSubtitle), findsOneWidget);
    expect(find.text('Bedah Buku Sejarah'), findsOneWidget);
    expect(
      find.text(AppDateFormatter.dateTime(event.startAt!)),
      findsOneWidget,
    );
    expect(find.text('Ruang Baca Utama'), findsOneWidget);
    expect(find.text(AppStrings.eventsParticipantCount(12)), findsOneWidget);
    expect(find.text(AppStrings.adminEventsAdd), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('Menampilkan keadaan kosong dengan ajakan menambah', (
    WidgetTester tester,
  ) async {
    await pumpEvents(tester, repository: FakeEventRepository());

    expect(find.text(AppStrings.adminEventsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.adminEventsEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.adminEventsAdd), findsNWidgets(2));
  });

  testWidgets('Galat menampilkan pesan ramah dan Coba Lagi memuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[fakeEvent(1)],
    )..fetchPageFailuresRemaining = 1;

    await pumpEvents(tester, repository: repository);

    expect(find.text(AppStrings.adminEventsLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text('Kegiatan 1'), findsNothing);

    await tester.ensureVisible(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminEventsLoadError), findsNothing);
    expect(find.text('Kegiatan 1'), findsOneWidget);
  });

  testWidgets('Tombol tambah membuka formulir kegiatan baru', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpEvents(
      tester,
      repository: FakeEventRepository(),
    );

    await tester.tap(find.text(AppStrings.adminEventsAdd).first);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminEventNew);
    expect(find.text(AppStrings.adminEventNewTitle), findsOneWidget);
    expect(find.text(AppStrings.adminEventFormTitleLabel), findsOneWidget);
  });

  testWidgets('Ketuk kartu membuka formulir ubah dengan data terisi', (
    WidgetTester tester,
  ) async {
    final AppEvent event = fakeEvent(
      1,
      title: 'Pameran Buku',
      description: 'Pameran buku tahunan.',
      location: 'Aula Utama',
    );
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[event],
    );
    final _Harness harness = await pumpEvents(tester, repository: repository);

    await tester.tap(find.text('Pameran Buku'));
    await tester.pumpAndSettle();

    expect(
      harness.router.state.uri.path,
      AppRoutes.adminEventEditPath(event.id),
    );
    expect(find.text(AppStrings.adminEventEditTitle), findsOneWidget);
    expect(find.text('Pameran Buku'), findsOneWidget);
    expect(find.text('Pameran buku tahunan.'), findsOneWidget);
    expect(find.text('Aula Utama'), findsOneWidget);
    expect(repository.getByIdCalls, 1);
  });

  testWidgets('Batal menghapus tidak mengubah daftar', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[fakeEvent(1, title: 'Pameran Buku')],
    );
    await pumpEvents(tester, repository: repository);

    await tester.tap(
      find.byTooltip(AppStrings.adminEventsDeleteTooltip('Pameran Buku')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminEventsDeleteDialogTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(find.text('Pameran Buku'), findsOneWidget);
  });

  testWidgets('Konfirmasi menghapus kegiatan dan menampilkan pesan', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[fakeEvent(1, title: 'Pameran Buku')],
    );
    await pumpEvents(tester, repository: repository);

    await tester.tap(
      find.byTooltip(AppStrings.adminEventsDeleteTooltip('Pameran Buku')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adminEventsDeleteConfirm));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.lastDeletedId, 'event-1');
    expect(find.text('Pameran Buku'), findsNothing);
    expect(find.text(AppStrings.adminEventsDeleteSuccess), findsOneWidget);
    expect(find.text(AppStrings.adminEventsEmptyTitle), findsOneWidget);
  });

  testWidgets('Kegagalan hapus mempertahankan kegiatan dan menampilkan pesan', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[fakeEvent(1, title: 'Pameran Buku')],
    )..deleteError = const EventFailure('Kegiatan gagal dihapus.');
    await pumpEvents(tester, repository: repository);

    await tester.tap(
      find.byTooltip(AppStrings.adminEventsDeleteTooltip('Pameran Buku')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adminEventsDeleteConfirm));
    await tester.pumpAndSettle();

    expect(find.text('Pameran Buku'), findsOneWidget);
    expect(find.text('Kegiatan gagal dihapus.'), findsOneWidget);
    expect(find.text(AppStrings.adminEventsEmptyTitle), findsNothing);
  });

  testWidgets('Muat Lebih Banyak menambah halaman tanpa duplikat', (
    WidgetTester tester,
  ) async {
    final List<AppEvent> firstPage = List<AppEvent>.generate(
      eventPageSize,
      (int index) => fakeEvent(index + 1),
    );
    final List<AppEvent> secondPage = <AppEvent>[
      firstPage.last,
      fakeEvent(21, title: 'Kegiatan halaman kedua'),
    ];
    final FakeEventRepository repository = FakeEventRepository()
      ..pages = <List<AppEvent>>[firstPage, secondPage];

    await pumpEvents(tester, repository: repository);

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminEventsLoadMore),
      400,
      scrollable: listScrollable,
    );

    expect(repository.fetchPageCalls, 1);
    await tester.tap(find.text(AppStrings.adminEventsLoadMore));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminEventsLoadMore), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Kegiatan halaman kedua'),
      400,
      scrollable: listScrollable,
    );
    expect(find.text('Kegiatan halaman kedua'), findsOneWidget);
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
      'Daftar kegiatan muat pada ${layout.size.width.toInt()}x${layout.size.height.toInt()} skala ${layout.textScale}',
      (WidgetTester tester) async {
        final FakeEventRepository repository = FakeEventRepository(
          events: <AppEvent>[
            fakeEvent(
              1,
              title:
                  'Diskusi Buku yang Judulnya Cukup Panjang untuk Uji Tata '
                  'Letak',
              description:
                  'Deskripsi panjang untuk menguji pembungkusan teks pada '
                  'kartu kegiatan admin.',
              location: 'Ruang Baca Utama Lantai Dua',
              participantCount: 120,
            ),
            fakeEvent(2, title: 'Pameran Buku'),
          ],
        );

        await pumpEvents(
          tester,
          repository: repository,
          viewSize: layout.size,
          theme: layout.theme,
          textScale: layout.textScale,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.adminEventsTitle), findsOneWidget);
        expect(find.text(AppStrings.adminEventsSubtitle), findsOneWidget);
        expect(find.byType(AppBottomNavBar), findsOneWidget);
        expect(find.byTooltip(AppStrings.adminLogoutLabel), findsOneWidget);
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
  final FakeEventRepository repository;
}

class _EventsTestApp extends ConsumerWidget {
  const _EventsTestApp({required this.theme, required this.textScale});

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
