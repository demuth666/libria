import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_notification.dart';
import '../data/notification_repository.dart';

/// Data notifikasi yang berhasil dimuat.
class NotificationListState {
  const NotificationListState({
    this.notifications = const <AppNotification>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<AppNotification> notifications;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => notifications.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore && !loadMoreFailed;

  NotificationListState copyWith({
    List<AppNotification>? notifications,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali daftar notifikasi pada rute `/notifications` (T-086).
///
/// Sumber data adalah stream Firestore lewat [NotificationRepository],
/// sehingga notifikasi baru dan perubahan status baca langsung tampil.
/// Jumlah yang dimuat dinaikkan bertahap saat pengguna memilih "Muat Lebih
/// Banyak"; data lama dipertahankan selama pemuatan berikutnya dan saat
/// pemuatan gagal.
class NotificationListController
    extends Notifier<AsyncValue<NotificationListState>> {
  late NotificationRepository _repository;
  StreamSubscription<List<AppNotification>>? _subscription;
  int _limit = notificationPageSize;
  int _generation = 0;

  @override
  AsyncValue<NotificationListState> build() {
    _repository = ref.watch(notificationRepositoryProvider);
    _limit = notificationPageSize;
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

    return const AsyncLoading<NotificationListState>();
  }

  void _listen() {
    final int generation = ++_generation;
    _subscription?.cancel();

    final Stream<List<AppNotification>> stream = _repository.watchNotifications(
      limit: _limit,
    );
    _subscription = stream.listen(
      (List<AppNotification> notifications) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        state = AsyncData<NotificationListState>(
          NotificationListState(
            notifications: notifications,
            hasMore: notifications.length >= _limit,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        final NotificationListState? current = state.value;
        if (current != null && current.notifications.isNotEmpty) {
          state = AsyncData<NotificationListState>(
            current.copyWith(isLoadingMore: false, loadMoreFailed: true),
          );
          return;
        }
        state = AsyncError<NotificationListState>(error, stackTrace);
      },
    );
  }

  /// Memuat lebih banyak notifikasi tanpa membuang daftar yang sudah tampil.
  void loadMore() {
    final NotificationListState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    _limit += notificationPageSize;
    state = AsyncData<NotificationListState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    _listen();
  }

  /// Memuat ulang notifikasi dari halaman pertama.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _limit = notificationPageSize;
    state = const AsyncLoading<NotificationListState>();
    _listen();
  }
}

/// Daftar notifikasi pengguna yang sedang masuk.
///
/// Dibuang saat layar tidak lagi mendengarkan agar pembukaan berikutnya
/// memakai data terbaru dari cache atau server.
final notificationListProvider =
    NotifierProvider.autoDispose<
      NotificationListController,
      AsyncValue<NotificationListState>
    >(NotificationListController.new);

/// Jumlah notifikasi belum dibaca untuk lencana Beranda.
///
/// Retry otomatis dimatikan agar kegagalan baca tidak berulang tanpa henti;
/// lencana disembunyikan saat jumlahnya belum tersedia.
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((
  Ref ref,
) {
  final NotificationRepository repository = ref.watch(
    notificationRepositoryProvider,
  );
  return repository.watchUnreadCount();
}, retry: (int retryCount, Object error) => null);
