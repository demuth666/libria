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

  Future<_Harness> pumpChallenges(
    WidgetTester tester, {
    required FakeChallengeRepository repository,
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
        eventRepositoryProvider.overrideWith(
          (Ref ref) => FakeEventRepository(),
        ),
        challengeRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);
    router.go(AppRoutes.adminChallenges);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _ChallengesTestApp(
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

  testWidgets('Menampilkan keadaan loading saat tantangan dimuat', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[fakeChallenge(1)],
    )..fetchPageGate = Completer<void>();

    await pumpChallenges(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.adminChallengesLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.adminChallengesEmptyTitle), findsNothing);

    repository.fetchPageGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adminChallengesLoading), findsNothing);
    expect(find.text(AppStrings.adminChallengesEmptyTitle), findsNothing);
  });

  testWidgets('Menampilkan judul, jenis, target, periode, dan peserta', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Baca 10 Buku',
      description: 'Tantangan membaca sepanjang November.',
      type: Challenge.typeBooks,
      targetValue: 10,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 30),
      participantCount: 12,
    );
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
    );

    await pumpChallenges(tester, repository: repository);

    expect(find.text(AppStrings.adminChallengesTitle), findsOneWidget);
    expect(find.text(AppStrings.adminChallengesSubtitle), findsOneWidget);
    expect(find.text('Baca 10 Buku'), findsOneWidget);
    expect(find.text(AppStrings.adminChallengeTypeBooks), findsOneWidget);
    expect(
      find.text(
        AppStrings.challengesDateRange(
          AppDateFormatter.date(challenge.startDate!),
          AppDateFormatter.date(challenge.endDate!),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Target 10 buku'), findsOneWidget);
    expect(
      find.text(AppStrings.challengesParticipantCount(12)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.adminChallengesAdd), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('Menampilkan jenis menit pada tantangan menit membaca', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Baca 300 Menit',
      type: Challenge.typeMinutes,
      targetValue: 300,
    );

    await pumpChallenges(
      tester,
      repository: FakeChallengeRepository(challenges: <Challenge>[challenge]),
    );

    expect(find.text(AppStrings.adminChallengeTypeMinutes), findsOneWidget);
    expect(find.text('Target 300 menit'), findsOneWidget);
  });

  testWidgets('Menampilkan keadaan kosong dengan ajakan menambah', (
    WidgetTester tester,
  ) async {
    await pumpChallenges(tester, repository: FakeChallengeRepository());

    expect(find.text(AppStrings.adminChallengesEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.adminChallengesEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.adminChallengesAdd), findsNWidgets(2));
  });

  testWidgets('Galat menampilkan pesan ramah dan Coba Lagi memuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[fakeChallenge(1)],
    )..fetchPageFailuresRemaining = 1;

    await pumpChallenges(tester, repository: repository);

    expect(find.text(AppStrings.adminChallengesLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text('Tantangan 1'), findsNothing);

    await tester.ensureVisible(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminChallengesLoadError), findsNothing);
    expect(find.text('Tantangan 1'), findsOneWidget);
  });

  testWidgets('Tombol tambah membuka formulir tantangan baru', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpChallenges(
      tester,
      repository: FakeChallengeRepository(),
    );

    await tester.tap(find.text(AppStrings.adminChallengesAdd).first);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.adminChallengeNew);
    expect(find.text(AppStrings.adminChallengeNewTitle), findsOneWidget);
    expect(find.text(AppStrings.adminChallengeFormTitleLabel), findsOneWidget);
  });

  testWidgets('Ketuk kartu membuka formulir ubah dengan data terisi', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Baca 10 Buku',
      description: 'Tantangan membaca sepanjang November.',
      targetValue: 10,
    );
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
    );
    final _Harness harness = await pumpChallenges(
      tester,
      repository: repository,
    );

    await tester.tap(find.text('Baca 10 Buku'));
    await tester.pumpAndSettle();

    expect(
      harness.router.state.uri.path,
      AppRoutes.adminChallengeEditPath(challenge.id),
    );
    expect(find.text(AppStrings.adminChallengeEditTitle), findsOneWidget);
    expect(find.text('Baca 10 Buku'), findsOneWidget);
    expect(find.text('Tantangan membaca sepanjang November.'), findsOneWidget);
    expect(repository.getByIdCalls, 1);
  });

  testWidgets('Batal menghapus tidak mengubah daftar', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[fakeChallenge(1, title: 'Baca 10 Buku')],
    );
    await pumpChallenges(tester, repository: repository);

    await tester.tap(
      find.byTooltip(AppStrings.adminChallengesDeleteTooltip('Baca 10 Buku')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.adminChallengesDeleteDialogTitle),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(find.text('Baca 10 Buku'), findsOneWidget);
  });

  testWidgets('Konfirmasi menghapus tantangan dan menampilkan pesan', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[fakeChallenge(1, title: 'Baca 10 Buku')],
    );
    await pumpChallenges(tester, repository: repository);

    await tester.tap(
      find.byTooltip(AppStrings.adminChallengesDeleteTooltip('Baca 10 Buku')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adminChallengesDeleteConfirm));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.lastDeletedId, 'challenge-1');
    expect(find.text('Baca 10 Buku'), findsNothing);
    expect(find.text(AppStrings.adminChallengesDeleteSuccess), findsOneWidget);
    expect(find.text(AppStrings.adminChallengesEmptyTitle), findsOneWidget);
  });

  testWidgets(
    'Kegagalan hapus mempertahankan tantangan dan menampilkan pesan',
    (WidgetTester tester) async {
      final FakeChallengeRepository repository = FakeChallengeRepository(
        challenges: <Challenge>[fakeChallenge(1, title: 'Baca 10 Buku')],
      )..deleteError = const ChallengeFailure('Tantangan gagal dihapus.');
      await pumpChallenges(tester, repository: repository);

      await tester.tap(
        find.byTooltip(AppStrings.adminChallengesDeleteTooltip('Baca 10 Buku')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.adminChallengesDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text('Baca 10 Buku'), findsOneWidget);
      expect(find.text('Tantangan gagal dihapus.'), findsOneWidget);
      expect(find.text(AppStrings.adminChallengesEmptyTitle), findsNothing);
    },
  );

  testWidgets('Muat Lebih Banyak menambah halaman tanpa duplikat', (
    WidgetTester tester,
  ) async {
    final List<Challenge> firstPage = List<Challenge>.generate(
      challengePageSize,
      (int index) => fakeChallenge(index + 1),
    );
    final List<Challenge> secondPage = <Challenge>[
      firstPage.last,
      fakeChallenge(21, title: 'Tantangan halaman kedua'),
    ];
    final FakeChallengeRepository repository = FakeChallengeRepository()
      ..pages = <List<Challenge>>[firstPage, secondPage];

    await pumpChallenges(tester, repository: repository);

    final Finder listScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.adminChallengesLoadMore),
      400,
      scrollable: listScrollable,
    );

    expect(repository.fetchPageCalls, 1);
    await tester.tap(find.text(AppStrings.adminChallengesLoadMore));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, 2);
    expect(find.text(AppStrings.adminChallengesLoadMore), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Tantangan halaman kedua'),
      400,
      scrollable: listScrollable,
    );
    expect(find.text('Tantangan halaman kedua'), findsOneWidget);
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
      'Daftar tantangan muat pada ${layout.size.width.toInt()}x${layout.size.height.toInt()} skala ${layout.textScale}',
      (WidgetTester tester) async {
        final FakeChallengeRepository repository = FakeChallengeRepository(
          challenges: <Challenge>[
            fakeChallenge(
              1,
              title:
                  'Tantangan Membaca yang Judulnya Cukup Panjang untuk Uji '
                  'Tata Letak',
              description:
                  'Deskripsi panjang untuk menguji pembungkusan teks pada '
                  'kartu tantangan admin.',
              type: Challenge.typeMinutes,
              targetValue: 1200,
              participantCount: 120,
            ),
            fakeChallenge(2, title: 'Baca 10 Buku'),
          ],
        );

        await pumpChallenges(
          tester,
          repository: repository,
          viewSize: layout.size,
          theme: layout.theme,
          textScale: layout.textScale,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.adminChallengesTitle), findsOneWidget);
        expect(find.text(AppStrings.adminChallengesSubtitle), findsOneWidget);
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
  final FakeChallengeRepository repository;
}

class _ChallengesTestApp extends ConsumerWidget {
  const _ChallengesTestApp({required this.theme, required this.textScale});

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
