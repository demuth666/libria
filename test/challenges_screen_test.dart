import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/challenges/data/challenge.dart';
import 'package:libria/features/challenges/data/challenge_participant.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';
import 'package:libria/features/challenges/presentation/challenge_detail_screen.dart';
import 'package:libria/features/challenges/presentation/challenges_screen.dart';

import 'support/fake_challenge_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<void> pumpChallenges(
    WidgetTester tester, {
    required FakeChallengeRepository repository,
    String location = '/challenges',
    ThemeData? theme,
    Size viewSize = const Size(390, 844),
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
        challengeRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: location,
      routes: <RouteBase>[
        GoRoute(
          path: '/challenges',
          builder: (BuildContext context, GoRouterState state) =>
              const ChallengesScreen(),
        ),
        GoRoute(
          path: '/challenges/:id',
          builder: (BuildContext context, GoRouterState state) =>
              ChallengeDetailScreen(
                challengeId: state.pathParameters['id'] ?? '',
              ),
        ),
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-test'))),
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
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Daftar menampilkan tantangan, periode, target, dan progres', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Baca 10 Buku',
      type: Challenge.typeBooks,
      targetValue: 10,
      participantCount: 3,
    );
    final FakeChallengeRepository repository =
        FakeChallengeRepository(
            challenges: <Challenge>[challenge],
            activeChallenges: <Challenge>[challenge],
          )
          ..participations[challenge.id] = const ChallengeParticipant(
            userId: 'user-1',
            userName: 'Siti',
            progress: 4,
          );

    await pumpChallenges(tester, repository: repository);

    expect(find.text(AppStrings.challengesSubtitle), findsOneWidget);
    expect(find.text('Baca 10 Buku'), findsOneWidget);
    expect(find.text(AppStrings.adminChallengeTypeBooks), findsOneWidget);
    expect(
      find.text(
        AppStrings.challengeProgressOfTarget(
          4,
          10,
          AppStrings.adminChallengeUnitBooks,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('challenge-card-${challenge.id}')),
      findsOneWidget,
    );
  });

  testWidgets('Daftar kosong menampilkan keadaan kosong', (
    WidgetTester tester,
  ) async {
    await pumpChallenges(tester, repository: FakeChallengeRepository());

    expect(find.text(AppStrings.challengesEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.challengesEmptyMessage), findsOneWidget);
  });

  testWidgets('Daftar galat menampilkan Coba Lagi dan memuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeChallengeRepository repository = FakeChallengeRepository()
      ..watchActiveError = const ChallengeFailure(
        AppStrings.challengesLoadError,
      );

    await pumpChallenges(tester, repository: repository);

    expect(find.text(AppStrings.challengesLoadError), findsOneWidget);

    repository.watchActiveError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.challengesEmptyTitle), findsOneWidget);
  });

  testWidgets('Ketuk kartu membuka detail tantangan', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(1);
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
      activeChallenges: <Challenge>[challenge],
    );

    await pumpChallenges(tester, repository: repository);
    await tester.tap(
      find.byKey(ValueKey<String>('challenge-card-${challenge.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tantangan 1'), findsOneWidget);
    expect(
      find.text(AppStrings.challengeDetailLeaderboardTitle),
      findsOneWidget,
    );
  });

  testWidgets('Detail menampilkan papan peringkat sepuluh teratas', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      targetValue: 10,
      participantCount: 2,
    );
    final FakeChallengeRepository repository =
        FakeChallengeRepository(challenges: <Challenge>[challenge])
          ..leaderboards[challenge.id] = <ChallengeParticipant>[
            const ChallengeParticipant(
              userId: 'user-1',
              userName: 'Siti',
              progress: 8,
            ),
            const ChallengeParticipant(
              userId: 'user-2',
              userName: 'Budi',
              progress: 3,
            ),
          ];

    await pumpChallenges(
      tester,
      repository: repository,
      location: '/challenges/${challenge.id}',
    );

    expect(
      find.text(AppStrings.challengeDetailLeaderboardTitle),
      findsOneWidget,
    );
    expect(find.text('Siti'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(
      find.text(
        AppStrings.challengeLeaderboardProgress(
          8,
          AppStrings.adminChallengeUnitBooks,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Tombol Gabung menyimpan keikutsertaan dan memperbarui tampilan',
    (WidgetTester tester) async {
      final Challenge challenge = fakeChallenge(1, participantCount: 2);
      final FakeChallengeRepository repository = FakeChallengeRepository(
        challenges: <Challenge>[challenge],
      );

      await pumpChallenges(
        tester,
        repository: repository,
        location: '/challenges/${challenge.id}',
      );

      expect(
        find.byKey(const ValueKey<String>('challenge-join-button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('challenge-join-button')),
      );
      await tester.pumpAndSettle();

      expect(repository.joinCalls, 1);
      expect(repository.lastJoinedId, challenge.id);
      expect(find.text(AppStrings.challengeJoinSuccess), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('challenge-joined-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Kegagalan bergabung menampilkan pesan ramah', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(1);
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
    )..joinError = const ChallengeFailure(AppStrings.challengeJoinError);

    await pumpChallenges(
      tester,
      repository: repository,
      location: '/challenges/${challenge.id}',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('challenge-join-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.challengeJoinError), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('challenge-join-button')),
      findsOneWidget,
    );
  });

  testWidgets('Detail tantangan yang hilang menampilkan jalan kembali', (
    WidgetTester tester,
  ) async {
    await pumpChallenges(
      tester,
      repository: FakeChallengeRepository(),
      location: '/challenges/missing',
    );

    expect(find.text(AppStrings.challengeDetailNotFoundTitle), findsOneWidget);
    expect(find.text(AppStrings.challengeDetailBackToList), findsOneWidget);
  });

  testWidgets('Layar tantangan rapi pada mode gelap dan teks 1,5x', (
    WidgetTester tester,
  ) async {
    final Challenge challenge = fakeChallenge(
      1,
      title: 'Tantangan Membaca yang Judulnya Cukup Panjang',
      participantCount: 15,
    );
    final FakeChallengeRepository repository =
        FakeChallengeRepository(
            challenges: <Challenge>[challenge],
            activeChallenges: <Challenge>[challenge],
          )
          ..participations[challenge.id] = const ChallengeParticipant(
            userId: 'user-1',
            userName: 'Siti',
            progress: 3,
          );

    await pumpChallenges(
      tester,
      repository: repository,
      theme: AppTheme.dark,
      textScale: 1.5,
      viewSize: const Size(360, 800),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.challengesTitle), findsOneWidget);
  });
}
