import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journal.dart';
import '../data/journal_repository.dart';

/// Jumlah jurnal yang dimuat per halaman pada daftar Jurnal.
const int journalPageSize = 20;

/// Cakupan daftar jurnal: seluruh buku atau satu buku tertentu.
///
/// `bookId` bernilai `null` untuk daftar "Semua Buku" dan berisi ID buku saat
/// pengguna memilih filter satu buku (FR-J2).
typedef JournalListScope = ({String? bookId});

/// Data daftar jurnal yang berhasil dimuat.
class JournalListState {
  const JournalListState({
    this.journals = const <Journal>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Journal> journals;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => journals.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore && !loadMoreFailed;

  JournalListState copyWith({
    List<Journal>? journals,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return JournalListState(
      journals: journals ?? this.journals,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali daftar jurnal pada rute `/journal` (T-060, FR-J2).
///
/// Sumber data adalah stream Firestore lewat [JournalRepository], sehingga
/// data cache tetap tampil saat offline dan jurnal yang baru disimpan atau
/// dihapus langsung muncul tanpa memuat ulang layar. Jumlah jurnal dinaikkan
/// bertahap saat pengguna memilih "Muat Lebih Banyak"; data lama dipertahankan
/// selama pemuatan berikutnya dan saat pemuatan gagal.
class JournalListController extends Notifier<AsyncValue<JournalListState>> {
  JournalListController(this.scope);

  final JournalListScope scope;

  late JournalRepository _repository;
  StreamSubscription<List<Journal>>? _subscription;
  int _limit = journalPageSize;
  int _generation = 0;

  @override
  AsyncValue<JournalListState> build() {
    _repository = ref.watch(journalRepositoryProvider);
    _limit = journalPageSize;
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

    return const AsyncLoading<JournalListState>();
  }

  void _listen() {
    final int generation = ++_generation;
    _subscription?.cancel();

    final Stream<List<Journal>> stream = _repository.watchJournals(
      bookId: scope.bookId,
      limit: _limit,
    );

    _subscription = stream.listen(
      (List<Journal> journals) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        state = AsyncData<JournalListState>(
          JournalListState(
            journals: journals,
            hasMore: journals.length >= _limit,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        final JournalListState? current = state.value;
        if (current != null && current.journals.isNotEmpty) {
          state = AsyncData<JournalListState>(
            current.copyWith(isLoadingMore: false, loadMoreFailed: true),
          );
          return;
        }
        state = AsyncError<JournalListState>(error, stackTrace);
      },
    );
  }

  /// Memuat lebih banyak jurnal tanpa membuang daftar yang sudah tampil.
  void loadMore() {
    final JournalListState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    _limit += journalPageSize;
    state = AsyncData<JournalListState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    _listen();
  }

  /// Memuat ulang daftar dari halaman pertama.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _limit = journalPageSize;
    state = const AsyncLoading<JournalListState>();
    _listen();
  }
}

/// Daftar jurnal untuk semua buku atau satu buku.
///
/// Dibuang saat tidak ada layar yang mendengarkan, sehingga membuka kembali
/// layar Jurnal selalu mengambil data terbaru dari cache atau server.
final journalListProvider = NotifierProvider.autoDispose
    .family<
      JournalListController,
      AsyncValue<JournalListState>,
      JournalListScope
    >(JournalListController.new);

/// Stream satu entri jurnal untuk formulir ubah.
///
/// Dibuang saat formulir ditutup agar pembukaan berikutnya selalu memakai
/// data terbaru.
final journalProvider = StreamProvider.autoDispose.family<Journal?, String>((
  Ref ref,
  String journalId,
) {
  final JournalRepository repository = ref.watch(journalRepositoryProvider);
  return repository.watchJournal(journalId);
});
