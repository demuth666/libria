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
import 'package:libria/features/challenges/data/challenge.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';
import 'package:libria/features/events/data/event_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';
import 'package:libria/features/reports/data/report_repository.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_challenge_repository.dart';
import 'support/fake_event_repository.dart';
import 'support/fake_isbn_log_repository.dart';
import 'support/fake_report_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpForm(
    WidgetTester tester, {
    required FakeChallengeRepository repository,
    String? challengeId,
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
        eventRepositoryProvider.overrideWith(
          (Ref ref) => FakeEventRepository(),
        ),
        challengeRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    router.go(
      challengeId == null
          ? AppRoutes.adminChallengeNew
          : AppRoutes.adminChallengeEditPath(challengeId),
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

  Future<void> scrollToBottom(WidgetTester tester) async {
    // Lepaskan fokus kolom teks agar gulir tidak ditarik kembali ke kolom
    // yang sedang aktif, lalu mulai gerakan dari tepi kiri.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.dragFrom(const Offset(8, 760), const Offset(0, -1200));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await scrollToBottom(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('admin-challenge-save')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Formulir kosong menampilkan pesan wajib isi', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository();
    await pumpForm(tester, repository: repository);

    await tapSave(tester);

    expect(
      find.text(AppStrings.adminChallengeFormTitleRequired),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.adminChallengeFormDescriptionRequired),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.adminChallengeFormTargetRequired),
      findsOneWidget,
    );
    expect(repository.createCalls, 0);
  });

  testWidgets('Target bukan angka ditolak dengan pesan yang jelas', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository();
    await pumpForm(tester, repository: repository);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTitleLabel),
      'Baca 10 Buku',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        AppStrings.adminChallengeFormDescriptionLabel,
      ),
      'Tantangan bulanan.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTargetLabel),
      'sepuluh',
    );
    await tapSave(tester);

    expect(
      find.text(AppStrings.adminChallengeFormTargetInvalid),
      findsOneWidget,
    );
    expect(repository.createCalls, 0);
  });

  testWidgets('Pemilih jenis tantangan mengubah target dan menyimpan menit', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository();
    final _Harness harness = await pumpForm(tester, repository: repository);

    expect(
      find.text(AppStrings.adminChallengeFormTargetHintBooks),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-challenge-type-minutes')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.adminChallengeFormTargetHintMinutes),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTitleLabel),
      'Baca 300 Menit',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        AppStrings.adminChallengeFormDescriptionLabel,
      ),
      'Tantangan menit membaca.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTargetLabel),
      '300',
    );
    await tapSave(tester);

    expect(repository.createCalls, 1);
    expect(repository.lastCreatedType, Challenge.typeMinutes);
    expect(repository.lastCreatedTargetValue, 300);
    expect(harness.router.state.uri.path, AppRoutes.adminChallenges);
    expect(find.text('Baca 300 Menit'), findsOneWidget);
  });

  testWidgets('Pemilih tanggal mengubah tanggal mulai tantangan', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository();
    await pumpForm(tester, repository: repository);
    await scrollToBottom(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('admin-challenge-start-date-field')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.adminChallengeStartDatePickerTitle),
      findsOneWidget,
    );

    final DateTime today = DateTime.now();
    final int selectedDay = today.day == 15 ? 16 : 15;
    final DateTime selected = DateTime(today.year, today.month, selectedDay);
    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'admin-challenge-start-day-${selected.year}-${selected.month}-${selected.day}',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('admin-challenge-start-date-picker-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppDateFormatter.date(selected)), findsOneWidget);
  });

  testWidgets('Tanggal selesai harus setelah tanggal mulai', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository();
    await pumpForm(tester, repository: repository);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTitleLabel),
      'Baca 10 Buku',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        AppStrings.adminChallengeFormDescriptionLabel,
      ),
      'Tantangan bulanan.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTargetLabel),
      '10',
    );

    await scrollToBottom(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('admin-challenge-end-date-field')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.adminChallengeEndDatePickerTitle),
      findsOneWidget,
    );

    // Tanggal mulai bawaan adalah hari ini, sehingga memilih hari ini juga
    // menghasilkan tanggal selesai yang tidak setelah tanggal mulai.
    final DateTime today = DateTime.now();
    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'admin-challenge-end-day-${today.year}-${today.month}-${today.day}',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('admin-challenge-end-date-picker-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(
      find.text(AppStrings.adminChallengeFormEndDateInvalid),
      findsOneWidget,
    );
    expect(repository.createCalls, 0);
  });

  testWidgets('Menyimpan tantangan baru memakai isian yang dipangkas', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository();
    final _Harness harness = await pumpForm(tester, repository: repository);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTitleLabel),
      '  Baca 10 Buku  ',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        AppStrings.adminChallengeFormDescriptionLabel,
      ),
      '  Tantangan bulanan.  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTargetLabel),
      '10',
    );
    await tapSave(tester);

    expect(repository.createCalls, 1);
    expect(repository.lastCreatedTitle, '  Baca 10 Buku  ');
    expect(repository.lastCreatedDescription, '  Tantangan bulanan.  ');
    expect(repository.lastCreatedType, Challenge.typeBooks);
    expect(repository.lastCreatedTargetValue, 10);
    expect(repository.lastCreatedStartDate, isNotNull);
    expect(repository.lastCreatedEndDate, isNotNull);
    expect(
      repository.lastCreatedEndDate!.isAfter(repository.lastCreatedStartDate!),
      isTrue,
    );
    expect(harness.router.state.uri.path, AppRoutes.adminChallenges);
    expect(find.text('Baca 10 Buku'), findsOneWidget);
  });

  testWidgets('Formulir ubah memuat data lalu menyimpannya', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Baca 10 Buku',
      description: 'Tantangan bulanan.',
      type: Challenge.typeMinutes,
      targetValue: 300,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 30),
    );
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
    );
    final _Harness harness = await pumpForm(
      tester,
      repository: repository,
      challengeId: challenge.id,
    );

    expect(find.text('Baca 10 Buku'), findsOneWidget);
    expect(find.text('Tantangan bulanan.'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('1 November 2026'), findsOneWidget);
    expect(find.text('30 November 2026'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTitleLabel),
      'Baca 12 Buku',
    );
    await tapSave(tester);

    expect(repository.updateCalls, 1);
    expect(repository.lastUpdatedId, challenge.id);
    expect(repository.lastUpdatedTitle, 'Baca 12 Buku');
    expect(repository.lastUpdatedType, Challenge.typeMinutes);
    expect(repository.lastUpdatedTargetValue, 300);
    expect(harness.router.state.uri.path, AppRoutes.adminChallenges);
    expect(find.text('Baca 12 Buku'), findsOneWidget);
  });

  testWidgets('Tantangan yang tidak ditemukan menampilkan jalan kembali', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpForm(
      tester,
      repository: FakeChallengeRepository(),
      challengeId: 'challenge-hilang',
    );

    expect(find.text(AppStrings.challengeNotFound), findsOneWidget);
    expect(
      find.text(AppStrings.adminChallengeFormNotFoundMessage),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.adminChallengeFormBackToList));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminChallenges);
  });

  testWidgets('Kegagalan simpan menampilkan pesan dan tetap di formulir', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository()
      ..createError = const ChallengeFailure('Tantangan gagal disimpan.');
    final _Harness harness = await pumpForm(tester, repository: repository);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTitleLabel),
      'Baca 10 Buku',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        AppStrings.adminChallengeFormDescriptionLabel,
      ),
      'Tantangan bulanan.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adminChallengeFormTargetLabel),
      '10',
    );
    await tapSave(tester);

    expect(find.text('Tantangan gagal disimpan.'), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.adminChallengeNew);
    expect(find.text(AppStrings.adminChallengeFormSave), findsOneWidget);
  });

  testWidgets('Formulir tantangan muat pada layar sempit mode gelap 1,5x', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Tantangan Membaca dengan Judul Panjang untuk Uji Tata Letak',
      description:
          'Deskripsi panjang untuk memastikan formulir tetap dapat digulir '
          'pada layar sempit dengan teks diperbesar.',
      type: Challenge.typeMinutes,
      targetValue: 1200,
    );
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
    );

    await pumpForm(
      tester,
      repository: repository,
      challengeId: challenge.id,
      viewSize: const Size(360, 800),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text(AppStrings.adminChallengeFormSectionDetails),
      findsOneWidget,
    );
    expect(find.text(AppStrings.adminChallengeFormSectionGoal), findsOneWidget);
    expect(
      find.text(AppStrings.adminChallengeFormSectionPeriod),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('admin-challenge-save')),
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
  final FakeChallengeRepository repository;
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
