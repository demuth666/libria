import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/data/challenge.dart';
import '../../challenges/data/challenge_repository.dart';

/// Data daftar tantangan admin yang berhasil dimuat.
///
/// Status loading dan galat disimpan oleh [AsyncValue] pada
/// [adminChallengesProvider]; kelas ini hanya memuat isi halaman, penanda
/// paginasi, dan tantangan yang sedang dihapus.
class AdminChallengesState {
  const AdminChallengesState({
    this.challenges = const <Challenge>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.deletingChallengeIds = const <String>{},
  });

  final List<Challenge> challenges;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  /// ID tantangan yang sedang menunggu penghapusan.
  final Set<String> deletingChallengeIds;

  bool get isEmpty => challenges.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  AdminChallengesState copyWith({
    List<Challenge>? challenges,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    Set<String>? deletingChallengeIds,
  }) {
    return AdminChallengesState(
      challenges: challenges ?? this.challenges,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      deletingChallengeIds: deletingChallengeIds ?? this.deletingChallengeIds,
    );
  }
}

/// Pengendali daftar tantangan admin pada rute `/admin/challenges`.
///
/// Semua akses data lewat [ChallengeRepository]. Setiap muat ulang menaikkan
/// penghitung generasi sehingga respons halaman lama yang datang terlambat
/// tidak menimpa hasil terbaru.
class AdminChallengesController
    extends Notifier<AsyncValue<AdminChallengesState>> {
  late ChallengeRepository _repository;
  ChallengeCursor? _nextCursor;
  int _generation = 0;
  bool _started = false;

  @override
  AsyncValue<AdminChallengesState> build() {
    _repository = ref.watch(challengeRepositoryProvider);
    return const AsyncLoading<AdminChallengesState>();
  }

  /// Memuat halaman pertama sekali saja saat layar pertama kali dibuka.
  Future<void> ensureLoaded() {
    if (!ref.mounted || _started) {
      return Future<void>.value();
    }
    _started = true;
    return _loadFirstPage();
  }

  /// Memuat ulang halaman pertama dari awal.
  Future<void> reload() {
    if (!ref.mounted) {
      return Future<void>.value();
    }
    _started = true;
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final int generation = ++_generation;
    final Set<String> deletingChallengeIds =
        state.value?.deletingChallengeIds ?? const <String>{};
    _nextCursor = null;
    state = const AsyncLoading<AdminChallengesState>();

    try {
      final ChallengePage page = await _repository.fetchChallengesPage(
        limit: challengePageSize,
      );
      if (!ref.mounted || generation != _generation) {
        return;
      }
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminChallengesState>(
        AdminChallengesState(
          challenges: page.challenges,
          hasMore: page.hasMore,
          deletingChallengeIds: deletingChallengeIds,
        ),
      );
    } catch (error, stackTrace) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = AsyncError<AdminChallengesState>(error, stackTrace);
    }
  }

  /// Memuat halaman berikutnya dan menambahkannya tanpa duplikat.
  Future<void> loadMore() async {
    if (!ref.mounted) {
      return;
    }
    final AdminChallengesState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    final int generation = _generation;
    state = AsyncData<AdminChallengesState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final ChallengePage page = await _repository.fetchChallengesPage(
        limit: challengePageSize,
        cursor: _nextCursor,
      );
      if (!ref.mounted || generation != _generation) {
        return;
      }
      final AdminChallengesState? latest = state.value;
      if (latest == null) {
        return;
      }
      final Set<String> existingIds = latest.challenges
          .map((Challenge challenge) => challenge.id)
          .toSet();
      final List<Challenge> appended = page.challenges
          .where((Challenge challenge) => !existingIds.contains(challenge.id))
          .toList(growable: false);
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminChallengesState>(
        latest.copyWith(
          challenges: <Challenge>[...latest.challenges, ...appended],
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      final AdminChallengesState? latest = state.value;
      if (latest != null) {
        state = AsyncData<AdminChallengesState>(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }

  /// Menghapus tantangan dari daftar setelah repository berhasil.
  ///
  /// Tantangan tetap ada di daftar bila repository gagal. Ketukan ganda pada
  /// tantangan yang sama diabaikan selama penghapusan pertama masih berjalan.
  /// Bila halaman yang terlihat menjadi kosong padahal masih ada halaman lain,
  /// halaman pertama dimuat ulang agar sisa tantangan tetap terjangkau.
  Future<void> deleteChallenge(Challenge challenge) async {
    final AdminChallengesState? current = state.value;
    if (current == null ||
        current.deletingChallengeIds.contains(challenge.id)) {
      return;
    }
    state = AsyncData<AdminChallengesState>(
      current.copyWith(
        deletingChallengeIds: <String>{
          ...current.deletingChallengeIds,
          challenge.id,
        },
      ),
    );

    try {
      await _repository.deleteChallenge(challenge.id);
      final AdminChallengesState? latest = state.value;
      if (latest == null) {
        return;
      }
      final AdminChallengesState updated = latest.copyWith(
        challenges: latest.challenges
            .where((Challenge item) => item.id != challenge.id)
            .toList(growable: false),
        deletingChallengeIds: <String>{...latest.deletingChallengeIds}
          ..remove(challenge.id),
      );
      state = AsyncData<AdminChallengesState>(updated);

      if (updated.isEmpty && updated.hasMore) {
        await reload();
      }
    } catch (_) {
      final AdminChallengesState? latest = state.value;
      if (latest != null &&
          latest.deletingChallengeIds.contains(challenge.id)) {
        state = AsyncData<AdminChallengesState>(
          latest.copyWith(
            deletingChallengeIds: <String>{...latest.deletingChallengeIds}
              ..remove(challenge.id),
          ),
        );
      }
      rethrow;
    }
  }
}

/// Permintaan memuat ulang daftar tantangan admin dari luar layar daftar.
///
/// Formulir tambah/ubah menaikkan nilainya setelah simpan berhasil. Bila
/// daftar sedang aktif di bawah formulir, listener layar daftar memuat ulang
/// halaman pertama.
class AdminChallengesReloadController extends Notifier<int> {
  @override
  int build() => 0;

  void request() {
    state++;
  }
}

/// Penanda permintaan muat ulang daftar tantangan admin.
final NotifierProvider<AdminChallengesReloadController, int>
adminChallengesReloadProvider =
    NotifierProvider<AdminChallengesReloadController, int>(
      AdminChallengesReloadController.new,
    );

/// Daftar tantangan admin pada rute `/admin/challenges`.
///
/// Dibuang saat tidak ada lagi layar yang mendengarkan, sehingga membuka
/// kembali area admin selalu memuat data terbaru.
final NotifierProvider<
  AdminChallengesController,
  AsyncValue<AdminChallengesState>
>
adminChallengesProvider =
    NotifierProvider.autoDispose<
      AdminChallengesController,
      AsyncValue<AdminChallengesState>
    >(AdminChallengesController.new);

/// Tantangan yang sedang diubah pada formulir `/admin/challenges/:id/edit`.
///
/// Bernilai `null` bila dokumen tidak ditemukan, sehingga layar dapat
/// membedakan keadaan "tidak ditemukan" dari galat pemuatan.
final adminChallengeByIdProvider = FutureProvider.autoDispose
    .family<Challenge?, String>(
      (Ref ref, String id) =>
          ref.watch(challengeRepositoryProvider).getById(id),
    );
