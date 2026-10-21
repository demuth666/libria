import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../isbn_logs/data/isbn_log.dart';
import '../../isbn_logs/data/isbn_log_repository.dart';

/// Data antrean log ISBN yang berhasil dimuat.
///
/// Status loading dan galat disimpan oleh [AsyncValue] pada
/// [adminIsbnLogsProvider]; kelas ini hanya memuat isi halaman dan penanda
/// paginasi.
class AdminIsbnLogsState {
  const AdminIsbnLogsState({
    this.logs = const <IsbnLog>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<IsbnLog> logs;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => logs.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  AdminIsbnLogsState copyWith({
    List<IsbnLog>? logs,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return AdminIsbnLogsState(
      logs: logs ?? this.logs,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali antrean log ISBN yang belum ditangani.
///
/// Semua akses data lewat [IsbnLogRepository]. Setiap muat ulang menaikkan
/// penghitung generasi sehingga respons halaman lama yang datang terlambat
/// tidak menimpa hasil terbaru.
class AdminIsbnLogsController extends Notifier<AsyncValue<AdminIsbnLogsState>> {
  late IsbnLogRepository _repository;
  IsbnLogCursor? _nextCursor;
  int _generation = 0;
  bool _started = false;

  @override
  AsyncValue<AdminIsbnLogsState> build() {
    _repository = ref.watch(isbnLogRepositoryProvider);
    return const AsyncLoading<AdminIsbnLogsState>();
  }

  /// Memuat halaman pertama sekali saja saat layar pertama kali dibuka.
  Future<void> ensureLoaded() {
    if (_started) {
      return Future<void>.value();
    }
    _started = true;
    return _loadFirstPage();
  }

  /// Memuat ulang halaman pertama dari awal.
  Future<void> reload() {
    _started = true;
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final int generation = ++_generation;
    _nextCursor = null;
    state = const AsyncLoading<AdminIsbnLogsState>();

    try {
      final IsbnLogPage page = await _repository.fetchUnhandledPage(
        limit: isbnLogPageSize,
      );
      if (generation != _generation) {
        return;
      }
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminIsbnLogsState>(
        AdminIsbnLogsState(logs: page.logs, hasMore: page.hasMore),
      );
    } catch (error, stackTrace) {
      if (generation != _generation) {
        return;
      }
      state = AsyncError<AdminIsbnLogsState>(error, stackTrace);
    }
  }

  /// Memuat halaman berikutnya dan menambahkannya tanpa duplikat.
  Future<void> loadMore() async {
    final AdminIsbnLogsState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    final int generation = _generation;
    state = AsyncData<AdminIsbnLogsState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final IsbnLogPage page = await _repository.fetchUnhandledPage(
        limit: isbnLogPageSize,
        cursor: _nextCursor,
      );
      if (generation != _generation) {
        return;
      }
      final AdminIsbnLogsState? latest = state.value;
      if (latest == null) {
        return;
      }
      final Set<String> existingIsbns = latest.logs
          .map((IsbnLog log) => log.isbn)
          .toSet();
      final List<IsbnLog> appended = page.logs
          .where((IsbnLog log) => !existingIsbns.contains(log.isbn))
          .toList(growable: false);
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminIsbnLogsState>(
        latest.copyWith(
          logs: <IsbnLog>[...latest.logs, ...appended],
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (generation != _generation) {
        return;
      }
      final AdminIsbnLogsState? latest = state.value;
      if (latest != null) {
        state = AsyncData<AdminIsbnLogsState>(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }
}

/// Antrean log ISBN pada rute `/admin/isbn-logs`.
///
/// Dibuang saat tidak ada lagi layar yang mendengarkan, sehingga membuka
/// kembali layar admin selalu memuat antrean terbaru.
final NotifierProvider<AdminIsbnLogsController, AsyncValue<AdminIsbnLogsState>>
adminIsbnLogsProvider =
    NotifierProvider.autoDispose<
      AdminIsbnLogsController,
      AsyncValue<AdminIsbnLogsState>
    >(AdminIsbnLogsController.new);
