import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/challenge.dart';
import '../data/challenge_participant.dart';
import '../data/challenge_repository.dart';

/// Daftar tantangan aktif pada rute `/challenges` (FR-C2).
///
/// Dibiarkan sebagai stream Firestore agar pencapaian target dan jumlah peserta
/// langsung tampil tanpa memuat ulang layar. Snapshot cache tetap dipakai saat
/// offline sesuai PRD bagian 6.
final StreamProvider<List<Challenge>> activeChallengesProvider =
    StreamProvider.autoDispose<List<Challenge>>((Ref ref) {
      final ChallengeRepository repository = ref.watch(
        challengeRepositoryProvider,
      );
      return repository.watchActiveChallenges();
    }, retry: (int retryCount, Object error) => null);

/// Maksimal dua tantangan aktif untuk Beranda (PRD bagian 7).
final StreamProvider<List<Challenge>> homeActiveChallengesProvider =
    StreamProvider.autoDispose<List<Challenge>>((Ref ref) {
      final ChallengeRepository repository = ref.watch(
        challengeRepositoryProvider,
      );
      return repository.watchActiveChallenges().map(
        (List<Challenge> challenges) =>
            challenges.take(homeActiveChallengeLimit).toList(growable: false),
      );
    }, retry: (int retryCount, Object error) => null);

/// Tantangan yang dibuka pada rute `/challenges/:id`.
final challengeDetailProvider = StreamProvider.autoDispose
    .family<Challenge?, String>((Ref ref, String challengeId) {
      return ref.watch(challengeRepositoryProvider).watchChallenge(challengeId);
    }, retry: (int retryCount, Object error) => null);

/// Dokumen peserta pengguna pada `/challenges/:id`, `null` bila belum bergabung.
final challengeParticipationProvider = StreamProvider.autoDispose
    .family<ChallengeParticipant?, String>((Ref ref, String challengeId) {
      return ref
          .watch(challengeRepositoryProvider)
          .watchParticipation(challengeId);
    }, retry: (int retryCount, Object error) => null);

/// Papan peringkat sepuluh teratas pada `/challenges/:id` (FR-C4).
final challengeLeaderboardProvider = StreamProvider.autoDispose
    .family<List<ChallengeParticipant>, String>((Ref ref, String challengeId) {
      return ref
          .watch(challengeRepositoryProvider)
          .watchLeaderboard(challengeId);
    }, retry: (int retryCount, Object error) => null);
