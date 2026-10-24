import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/admin/presentation/admin_challenges_providers.dart';
import 'package:libria/features/challenges/data/challenge.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';

import 'support/fake_challenge_repository.dart';

void main() {
  ProviderContainer createContainer(FakeChallengeRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        challengeRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    // Provider autoDispose dibuang tanpa pendengar; uji ini perlu
    // mempertahankan state di antara beberapa pembacaan.
    container.listen<AsyncValue<AdminChallengesState>>(
      adminChallengesProvider,
      (
        AsyncValue<AdminChallengesState>? previous,
        AsyncValue<AdminChallengesState> next,
      ) {},
    );
    return container;
  }

  test('memuat halaman pertama lalu menambahkan halaman berikutnya', () async {
    final List<Challenge> firstPage = List<Challenge>.generate(
      challengePageSize,
      (int index) => fakeChallenge(index),
    );
    final List<Challenge> secondPage = <Challenge>[
      // Sengaja mengulang tantangan terakhir halaman pertama untuk memastikan
      // penggabungan tidak menghasilkan duplikat.
      firstPage.last,
      ...List<Challenge>.generate(3, (int index) => fakeChallenge(index + 20)),
    ];
    final FakeChallengeRepository repository = FakeChallengeRepository()
      ..pages = <List<Challenge>>[firstPage, secondPage];
    final ProviderContainer container = createContainer(repository);
    final AdminChallengesController controller = container.read(
      adminChallengesProvider.notifier,
    );

    await controller.ensureLoaded();

    AdminChallengesState state = container
        .read(adminChallengesProvider)
        .requireValue;
    expect(state.challenges, hasLength(challengePageSize));
    expect(state.hasMore, isTrue);

    await controller.loadMore();

    state = container.read(adminChallengesProvider).requireValue;
    expect(state.challenges, hasLength(challengePageSize + 3));
    expect(
      state.challenges.map((Challenge challenge) => challenge.id).toSet(),
      hasLength(challengePageSize + 3),
    );
    expect(state.hasMore, isFalse);
    expect(repository.fetchPageCalls, 2);
  });

  test('galat awal dapat dipulihkan lewat muat ulang', () async {
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[fakeChallenge(1)],
    )..fetchPageFailuresRemaining = 1;
    final ProviderContainer container = createContainer(repository);
    final AdminChallengesController controller = container.read(
      adminChallengesProvider.notifier,
    );

    await controller.ensureLoaded();

    expect(container.read(adminChallengesProvider).hasError, isTrue);

    await controller.reload();

    expect(container.read(adminChallengesProvider).hasError, isFalse);
    expect(
      container.read(adminChallengesProvider).requireValue.challenges.single.id,
      'challenge-1',
    );
  });

  test('menghapus tantangan dari daftar setelah repository berhasil', () async {
    final Challenge first = fakeChallenge(1);
    final Challenge second = fakeChallenge(2);
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[first, second],
    );
    final ProviderContainer container = createContainer(repository);
    final AdminChallengesController controller = container.read(
      adminChallengesProvider.notifier,
    );
    await controller.ensureLoaded();

    await controller.deleteChallenge(first);

    final AdminChallengesState state = container
        .read(adminChallengesProvider)
        .requireValue;
    expect(state.challenges, <Challenge>[second]);
    expect(repository.lastDeletedId, first.id);
  });

  test('tantangan tetap ada bila penghapusan gagal', () async {
    final Challenge challenge = fakeChallenge(1);
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
    )..deleteError = const ChallengeFailure('Gagal menghapus.');
    final ProviderContainer container = createContainer(repository);
    final AdminChallengesController controller = container.read(
      adminChallengesProvider.notifier,
    );
    await controller.ensureLoaded();

    await expectLater(
      controller.deleteChallenge(challenge),
      throwsA(isA<ChallengeFailure>()),
    );

    final AdminChallengesState state = container
        .read(adminChallengesProvider)
        .requireValue;
    expect(state.challenges, <Challenge>[challenge]);
    expect(state.deletingChallengeIds, isEmpty);
  });

  test('menahan ketukan hapus ganda selama proses berjalan', () async {
    final Challenge challenge = fakeChallenge(1);
    final Completer<void> gate = Completer<void>();
    final FakeChallengeRepository repository = FakeChallengeRepository(
      challenges: <Challenge>[challenge],
    )..deleteGate = gate;
    final ProviderContainer container = createContainer(repository);
    final AdminChallengesController controller = container.read(
      adminChallengesProvider.notifier,
    );
    await controller.ensureLoaded();

    final Future<void> first = controller.deleteChallenge(challenge);
    await controller.deleteChallenge(challenge);

    expect(repository.deleteCalls, 1);
    expect(
      container.read(adminChallengesProvider).requireValue.deletingChallengeIds,
      <String>{challenge.id},
    );

    gate.complete();
    await first;

    expect(
      container.read(adminChallengesProvider).requireValue.challenges,
      isEmpty,
    );
  });
}
