import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_event.dart';
import '../data/event_repository.dart';

/// Data daftar kegiatan mendatang yang berhasil dimuat.
///
/// Status loading dan galat disimpan oleh [AsyncValue] pada
/// [eventsListProvider]; kelas ini hanya memuat isi halaman dan penanda
/// paginasi.
class EventsListState {
  const EventsListState({
    this.events = const <AppEvent>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<AppEvent> events;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => events.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  EventsListState copyWith({
    List<AppEvent>? events,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return EventsListState(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali daftar kegiatan mendatang pada rute `/events` (FR-E2).
///
/// Sumber data adalah stream Firestore lewat [EventRepository]. Jumlah
/// kegiatan yang dimuat dinaikkan bertahap saat pengguna memilih "Muat Lebih
/// Banyak"; daftar lama dipertahankan selama pemuatan berikutnya dan saat
/// pemuatan gagal.
class EventsListController extends Notifier<AsyncValue<EventsListState>> {
  late EventRepository _repository;
  StreamSubscription<List<AppEvent>>? _subscription;
  int _limit = eventPageSize;
  int _generation = 0;

  @override
  AsyncValue<EventsListState> build() {
    _repository = ref.watch(eventRepositoryProvider);
    _limit = eventPageSize;
    _generation++;
    _subscription?.cancel();
    ref.onDispose(() {
      _generation++;
      _subscription?.cancel();
    });

    Future<void>.microtask(() {
      if (ref.mounted) {
        _listen();
      }
    });

    return const AsyncLoading<EventsListState>();
  }

  void _listen() {
    final int generation = ++_generation;
    _subscription?.cancel();

    _subscription = _repository
        .watchUpcomingEvents(limit: _limit)
        .listen(
          (List<AppEvent> events) {
            if (!ref.mounted || generation != _generation) {
              return;
            }
            state = AsyncData<EventsListState>(
              EventsListState(events: events, hasMore: events.length >= _limit),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!ref.mounted || generation != _generation) {
              return;
            }
            final EventsListState? current = state.value;
            if (current != null && current.events.isNotEmpty) {
              state = AsyncData<EventsListState>(
                current.copyWith(isLoadingMore: false, loadMoreFailed: true),
              );
              return;
            }
            state = AsyncError<EventsListState>(error, stackTrace);
          },
        );
  }

  /// Memuat lebih banyak kegiatan tanpa membuang daftar yang sudah tampil.
  ///
  /// Bila pemuatan sebelumnya gagal, percobaan ulang memakai batas yang sama
  /// sehingga jumlah yang diminta tidak bertambah dua kali.
  void loadMore() {
    final EventsListState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    if (!current.loadMoreFailed) {
      _limit += eventPageSize;
    }
    state = AsyncData<EventsListState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    _listen();
  }

  /// Memuat ulang daftar dari halaman pertama.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _limit = eventPageSize;
    state = const AsyncLoading<EventsListState>();
    _listen();
  }
}

/// Daftar kegiatan mendatang pada rute `/events`.
///
/// Dibuang saat tidak ada layar yang mendengarkan, sehingga membuka kembali
/// daftar mengambil jadwal terbaru dari cache atau server.
final NotifierProvider<EventsListController, AsyncValue<EventsListState>>
eventsListProvider =
    NotifierProvider.autoDispose<
      EventsListController,
      AsyncValue<EventsListState>
    >(EventsListController.new);

/// Maksimal dua kegiatan terdekat untuk Beranda (PRD bagian 7).
final StreamProvider<List<AppEvent>> homeUpcomingEventsProvider =
    StreamProvider.autoDispose<List<AppEvent>>((Ref ref) {
      final EventRepository repository = ref.watch(eventRepositoryProvider);
      return repository.watchUpcomingEvents(limit: homeUpcomingEventLimit);
    }, retry: (int retryCount, Object error) => null);

/// Kegiatan yang dibuka pada rute `/events/:id`.
final eventDetailProvider = StreamProvider.autoDispose
    .family<AppEvent?, String>((Ref ref, String eventId) {
      return ref.watch(eventRepositoryProvider).watchEvent(eventId);
    }, retry: (int retryCount, Object error) => null);

/// Status keikutsertaan pengguna pada kegiatan `/events/:id`.
final eventParticipationProvider = StreamProvider.autoDispose
    .family<bool, String>((Ref ref, String eventId) {
      return ref.watch(eventRepositoryProvider).watchIsParticipant(eventId);
    }, retry: (int retryCount, Object error) => null);
