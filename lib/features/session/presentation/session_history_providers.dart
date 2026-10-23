import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_session.dart';
import '../data/session_repository.dart';

/// Jumlah sesi yang dimuat per halaman pada riwayat sesi.
const int sessionHistoryPageSize = 20;

/// Cakupan riwayat sesi: semua buku atau satu buku tertentu.
///
/// `bookId` bernilai `null` untuk daftar keseluruhan yang dibuka dari
/// Statistik, dan berisi ID buku untuk daftar di Detail Buku.
typedef SessionHistoryScope = ({String? bookId});

/// Data riwayat sesi yang berhasil dimuat.
class SessionHistoryState {
  const SessionHistoryState({
    this.sessions = const <ReadingSession>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<ReadingSession> sessions;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => sessions.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore && !loadMoreFailed;

  SessionHistoryState copyWith({
    List<ReadingSession>? sessions,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return SessionHistoryState(
      sessions: sessions ?? this.sessions,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali riwayat sesi membaca (T-057, FR-S10).
///
/// Sumber data adalah stream Firestore lewat [SessionRepository], sehingga
/// data cache tetap tampil saat offline dan sesi yang baru disimpan langsung
/// muncul tanpa memuat ulang layar. Jumlah sesi dinaikkan bertahap saat
/// pengguna memilih "Muat Lebih Banyak"; data lama dipertahankan selama
/// pemuatan berikutnya dan saat pemuatan gagal.
class SessionHistoryController
    extends Notifier<AsyncValue<SessionHistoryState>> {
  SessionHistoryController(this.scope);

  final SessionHistoryScope scope;

  late SessionRepository _repository;
  StreamSubscription<List<ReadingSession>>? _subscription;
  int _limit = sessionHistoryPageSize;
  int _generation = 0;

  @override
  AsyncValue<SessionHistoryState> build() {
    _repository = ref.watch(sessionRepositoryProvider);
    _limit = sessionHistoryPageSize;
    _generation++;
    _subscription?.cancel();
    ref.onDispose(() {
      _generation++;
      _subscription?.cancel();
    });

    // Dengarkan setelah build selesai agar perubahan state tidak terjadi
    // sebelum provider siap.
    Future<void>.microtask(() {
      if (ref.mounted) {
        _listen();
      }
    });

    return const AsyncLoading<SessionHistoryState>();
  }

  void _listen() {
    final int generation = ++_generation;
    _subscription?.cancel();

    final Stream<List<ReadingSession>> stream = scope.bookId == null
        ? _repository.watchAllSessions(limit: _limit)
        : _repository.watchSessionsForBook(scope.bookId!, limit: _limit);

    _subscription = stream.listen(
      (List<ReadingSession> sessions) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        state = AsyncData<SessionHistoryState>(
          SessionHistoryState(
            sessions: sessions,
            hasMore: sessions.length >= _limit,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        final SessionHistoryState? current = state.value;
        if (current != null && current.sessions.isNotEmpty) {
          state = AsyncData<SessionHistoryState>(
            current.copyWith(isLoadingMore: false, loadMoreFailed: true),
          );
          return;
        }
        state = AsyncError<SessionHistoryState>(error, stackTrace);
      },
    );
  }

  /// Memuat lebih banyak sesi tanpa membuang daftar yang sudah tampil.
  void loadMore() {
    final SessionHistoryState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    _limit += sessionHistoryPageSize;
    state = AsyncData<SessionHistoryState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    _listen();
  }

  /// Memuat ulang daftar dari halaman pertama.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _limit = sessionHistoryPageSize;
    state = const AsyncLoading<SessionHistoryState>();
    _listen();
  }
}

/// Riwayat sesi untuk semua buku atau satu buku.
///
/// Provider dibuang saat tidak ada layar yang mendengarkannya, sehingga
/// membuka riwayat kembali selalu mengambil data terbaru dari cache atau
/// server.
final sessionHistoryProvider = NotifierProvider.autoDispose
    .family<
      SessionHistoryController,
      AsyncValue<SessionHistoryState>,
      SessionHistoryScope
    >(SessionHistoryController.new);
