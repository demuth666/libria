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

  Future<_Harness> pumpForm(
    WidgetTester tester, {
    required FakeEventRepository repository,
    String? eventId,
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
    router.go(
      eventId == null
          ? AppRoutes.adminEventNew
          : AppRoutes.adminEventEditPath(eventId),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _FormTestApp(
          theme: theme ?? AppTheme.light,
          textScale: textScale,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return _Harness(router: router, repository: repository);
  }

  testWidgets('Formulir kosong menampilkan pesan wajib isi', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository();
    await pumpForm(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('admin-event-save')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminEventFormTitleRequired), findsOneWidget);
    expect(
      find.text(AppStrings.adminEventFormDescriptionRequired),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.adminEventFormLocationRequired),
      findsOneWidget,
    );
    expect(repository.createCalls, 0);
  });

  testWidgets('Pemilih tanggal mengubah tanggal kegiatan', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository();
    await pumpForm(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-event-date-field')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminEventDatePickerTitle), findsOneWidget);

    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final DateTime selected = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day == 15 ? 16 : 15,
    );
    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'admin-event-day-${selected.year}-${selected.month}-${selected.day}',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('admin-event-date-picker-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppDateFormatter.date(selected)), findsOneWidget);
  });

  testWidgets('Pemilih jam menampilkan nilai awal dan dapat disimpan', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester, repository: FakeEventRepository());

    expect(find.text('19.00'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-event-time-field')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminEventTimePickerTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('admin-event-hour-dropdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('admin-event-minute-dropdown')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-event-time-picker-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('19.00'), findsOneWidget);
  });

  testWidgets('Menyimpan kegiatan baru memakai isian yang dipangkas', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository();
    final _Harness harness = await pumpForm(tester, repository: repository);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminEventFormTitleLabel),
      '  Bedah Buku  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminEventFormDescriptionLabel),
      '  Diskusi terbuka.  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminEventFormLocationLabel),
      '  Ruang Baca  ',
    );
    await tester.tap(find.byKey(const ValueKey<String>('admin-event-save')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastCreatedTitle, '  Bedah Buku  ');
    expect(repository.lastCreatedDescription, '  Diskusi terbuka.  ');
    expect(repository.lastCreatedLocation, '  Ruang Baca  ');
    expect(repository.lastCreatedStartAt, isNotNull);
    expect(harness.router.state.uri.path, AppRoutes.adminEvents);
    expect(find.text('Bedah Buku'), findsOneWidget);
  });

  testWidgets('Formulir ubah memuat data lalu menyimpannya', (
    WidgetTester tester,
  ) async {
    final AppEvent event = fakeEvent(
      1,
      title: 'Pameran Buku',
      description: 'Pameran tahunan.',
      location: 'Aula',
      startAt: DateTime(2026, 11, 5, 9, 30),
    );
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[event],
    );
    final _Harness harness = await pumpForm(
      tester,
      repository: repository,
      eventId: event.id,
    );

    expect(find.text('Pameran Buku'), findsOneWidget);
    expect(find.text('Pameran tahunan.'), findsOneWidget);
    expect(find.text('Aula'), findsOneWidget);
    expect(find.text('09.30'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminEventFormTitleLabel),
      'Pameran Buku Baru',
    );
    await tester.tap(find.byKey(const ValueKey<String>('admin-event-save')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.lastUpdatedId, event.id);
    expect(repository.lastUpdatedTitle, 'Pameran Buku Baru');
    expect(harness.router.state.uri.path, AppRoutes.adminEvents);
    expect(find.text('Pameran Buku Baru'), findsOneWidget);
  });

  testWidgets('Kegiatan yang tidak ditemukan menampilkan jalan kembali', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpForm(
      tester,
      repository: FakeEventRepository(),
      eventId: 'event-hilang',
    );

    expect(find.text(AppStrings.eventsNotFound), findsOneWidget);
    expect(find.text(AppStrings.adminEventFormNotFoundMessage), findsOneWidget);

    await tester.tap(find.text(AppStrings.adminEventFormBackToList));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminEvents);
  });

  testWidgets('Kegagalan simpan menampilkan pesan dan tetap di formulir', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository()
      ..createError = const EventFailure('Kegiatan gagal disimpan.');
    final _Harness harness = await pumpForm(tester, repository: repository);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminEventFormTitleLabel),
      'Bedah Buku',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminEventFormDescriptionLabel),
      'Diskusi terbuka.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminEventFormLocationLabel),
      'Ruang Baca',
    );
    await tester.tap(find.byKey(const ValueKey<String>('admin-event-save')));
    await tester.pumpAndSettle();

    expect(find.text('Kegiatan gagal disimpan.'), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.adminEventNew);
    expect(find.text(AppStrings.adminEventFormSave), findsOneWidget);
  });

  testWidgets('Formulir kegiatan muat pada layar sempit mode gelap 1,5x', (
    WidgetTester tester,
  ) async {
    final AppEvent event = fakeEvent(
      1,
      title: 'Diskusi Buku dengan Judul Panjang untuk Uji Tata Letak',
      description:
          'Deskripsi panjang untuk memastikan formulir tetap dapat digulir '
          'pada layar sempit dengan teks diperbesar.',
      location: 'Ruang Baca Utama Lantai Dua',
    );
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[event],
    );

    await pumpForm(
      tester,
      repository: repository,
      eventId: event.id,
      viewSize: const Size(360, 800),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.adminEventFormSectionDetails), findsOneWidget);
    expect(find.text(AppStrings.adminEventFormSectionSchedule), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('admin-event-save')),
      findsOneWidget,
    );
  });
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

class _FormTestApp extends ConsumerWidget {
  const _FormTestApp({required this.theme, required this.textScale});

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
