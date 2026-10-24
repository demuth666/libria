import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/data/app_event.dart';
import '../../events/data/event_repository.dart';

/// Data daftar kegiatan admin yang berhasil dimuat.
///
/// Status loading dan galat disimpan oleh [AsyncValue] pada
/// [adminEventsProvider]; kelas ini hanya memuat isi halaman, penanda
/// paginasi, dan kegiatan yang sedang dihapus.
class AdminEventsState {
  const AdminEventsState({
    this.events = const <AppEvent>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.deletingEventIds = const <String>{},
  });

  final List<AppEvent> events;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  /// ID kegiatan yang sedang menunggu penghapusan.
  final Set<String> deletingEventIds;

  bool get isEmpty => events.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  AdminEventsState copyWith({
    List<AppEvent>? events,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    Set<String>? deletingEventIds,
  }) {
    return AdminEventsState(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      deletingEventIds: deletingEventIds ?? this.deletingEventIds,
    );
  }
}

/// Pengendali daftar kegiatan admin pada rute `/admin/events`.
///
/// Semua akses data lewat [EventRepository]. Setiap muat ulang menaikkan
/// penghitung generasi sehingga respons halaman lama yang datang terlambat
/// tidak menimpa hasil terbaru.
class AdminEventsController extends Notifier<AsyncValue<AdminEventsState>> {
  late EventRepository _repository;
  EventCursor? _nextCursor;
  int _generation = 0;
  bool _started = false;

  @override
  AsyncValue<AdminEventsState> build() {
    _repository = ref.watch(eventRepositoryProvider);
    return const AsyncLoading<AdminEventsState>();
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
    final Set<String> deletingEventIds =
        state.value?.deletingEventIds ?? const <String>{};
    _nextCursor = null;
    state = const AsyncLoading<AdminEventsState>();

    try {
      final EventPage page = await _repository.fetchEventsPage(
        limit: eventPageSize,
      );
      if (!ref.mounted || generation != _generation) {
        return;
      }
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminEventsState>(
        AdminEventsState(
          events: page.events,
          hasMore: page.hasMore,
          deletingEventIds: deletingEventIds,
        ),
      );
    } catch (error, stackTrace) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = AsyncError<AdminEventsState>(error, stackTrace);
    }
  }

  /// Memuat halaman berikutnya dan menambahkannya tanpa duplikat.
  Future<void> loadMore() async {
    if (!ref.mounted) {
      return;
    }
    final AdminEventsState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    final int generation = _generation;
    state = AsyncData<AdminEventsState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final EventPage page = await _repository.fetchEventsPage(
        limit: eventPageSize,
        cursor: _nextCursor,
      );
      if (!ref.mounted || generation != _generation) {
        return;
      }
      final AdminEventsState? latest = state.value;
      if (latest == null) {
        return;
      }
      final Set<String> existingIds = latest.events
          .map((AppEvent event) => event.id)
          .toSet();
      final List<AppEvent> appended = page.events
          .where((AppEvent event) => !existingIds.contains(event.id))
          .toList(growable: false);
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminEventsState>(
        latest.copyWith(
          events: <AppEvent>[...latest.events, ...appended],
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      final AdminEventsState? latest = state.value;
      if (latest != null) {
        state = AsyncData<AdminEventsState>(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }

  /// Menghapus kegiatan dari daftar setelah repository berhasil.
  ///
  /// Kegiatan tetap ada di daftar bila repository gagal. Ketukan ganda pada
  /// kegiatan yang sama diabaikan selama penghapusan pertama masih berjalan.
  /// Bila halaman yang terlihat menjadi kosong padahal masih ada halaman lain,
  /// halaman pertama dimuat ulang agar sisa kegiatan tetap terjangkau.
  Future<void> deleteEvent(AppEvent event) async {
    final AdminEventsState? current = state.value;
    if (current == null || current.deletingEventIds.contains(event.id)) {
      return;
    }
    state = AsyncData<AdminEventsState>(
      current.copyWith(
        deletingEventIds: <String>{...current.deletingEventIds, event.id},
      ),
    );

    try {
      await _repository.deleteEvent(event.id);
      final AdminEventsState? latest = state.value;
      if (latest == null) {
        return;
      }
      final AdminEventsState updated = latest.copyWith(
        events: latest.events
            .where((AppEvent item) => item.id != event.id)
            .toList(growable: false),
        deletingEventIds: <String>{...latest.deletingEventIds}
          ..remove(event.id),
      );
      state = AsyncData<AdminEventsState>(updated);

      if (updated.isEmpty && updated.hasMore) {
        await reload();
      }
    } catch (_) {
      final AdminEventsState? latest = state.value;
      if (latest != null && latest.deletingEventIds.contains(event.id)) {
        state = AsyncData<AdminEventsState>(
          latest.copyWith(
            deletingEventIds: <String>{...latest.deletingEventIds}
              ..remove(event.id),
          ),
        );
      }
      rethrow;
    }
  }
}

/// Permintaan memuat ulang daftar kegiatan admin dari luar layar daftar.
///
/// Formulir tambah/ubah menaikkan nilainya setelah simpan berhasil. Bila
/// daftar sedang aktif di bawah formulir, listener layar daftar memuat ulang
/// halaman pertama.
class AdminEventsReloadController extends Notifier<int> {
  @override
  int build() => 0;

  void request() {
    state++;
  }
}

/// Penanda permintaan muat ulang daftar kegiatan admin.
final NotifierProvider<AdminEventsReloadController, int>
adminEventsReloadProvider = NotifierProvider<AdminEventsReloadController, int>(
  AdminEventsReloadController.new,
);

/// Daftar kegiatan admin pada rute `/admin/events`.
///
/// Dibuang saat tidak ada lagi layar yang mendengarkan, sehingga membuka
/// kembali area admin selalu memuat data terbaru.
final NotifierProvider<AdminEventsController, AsyncValue<AdminEventsState>>
adminEventsProvider =
    NotifierProvider.autoDispose<
      AdminEventsController,
      AsyncValue<AdminEventsState>
    >(AdminEventsController.new);

/// Kegiatan yang sedang diubah pada formulir `/admin/events/:id/edit`.
///
/// Bernilai `null` bila dokumen tidak ditemukan, sehingga layar dapat
/// membedakan keadaan "tidak ditemukan" dari galat pemuatan.
final adminEventByIdProvider = FutureProvider.autoDispose
    .family<AppEvent?, String>(
      (Ref ref, String id) => ref.watch(eventRepositoryProvider).getById(id),
    );
