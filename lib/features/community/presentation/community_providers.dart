import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post.dart';
import '../data/post_repository.dart';

/// Data feed Komunitas yang berhasil dimuat.
class CommunityFeedState {
  const CommunityFeedState({
    this.posts = const <Post>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Post> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => posts.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore && !loadMoreFailed;

  CommunityFeedState copyWith({
    List<Post>? posts,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return CommunityFeedState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali feed Komunitas pada tab `/home/community` (T-080, FR-K1).
///
/// Sumber data adalah stream Firestore lewat [PostRepository], sehingga data
/// cache tetap tampil saat offline dan postingan baru atau terhapus langsung
/// memperbarui daftar. Jumlah postingan yang dimuat dinaikkan bertahap saat
/// pengguna memilih "Muat Lebih Banyak"; data lama dipertahankan selama
/// pemuatan berikutnya dan saat pemuatan gagal.
class CommunityFeedController extends Notifier<AsyncValue<CommunityFeedState>> {
  late PostRepository _repository;
  StreamSubscription<List<Post>>? _subscription;
  int _limit = postPageSize;
  int _generation = 0;

  @override
  AsyncValue<CommunityFeedState> build() {
    _repository = ref.watch(postRepositoryProvider);
    _limit = postPageSize;
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

    return const AsyncLoading<CommunityFeedState>();
  }

  void _listen() {
    final int generation = ++_generation;
    _subscription?.cancel();

    final Stream<List<Post>> stream = _repository.watchFeed(limit: _limit);
    _subscription = stream.listen(
      (List<Post> posts) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        state = AsyncData<CommunityFeedState>(
          CommunityFeedState(posts: posts, hasMore: posts.length >= _limit),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        final CommunityFeedState? current = state.value;
        if (current != null && current.posts.isNotEmpty) {
          state = AsyncData<CommunityFeedState>(
            current.copyWith(isLoadingMore: false, loadMoreFailed: true),
          );
          return;
        }
        state = AsyncError<CommunityFeedState>(error, stackTrace);
      },
    );
  }

  /// Memuat lebih banyak postingan tanpa membuang daftar yang sudah tampil.
  void loadMore() {
    final CommunityFeedState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    _limit += postPageSize;
    state = AsyncData<CommunityFeedState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    _listen();
  }

  /// Memuat ulang feed dari halaman pertama.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _limit = postPageSize;
    state = const AsyncLoading<CommunityFeedState>();
    _listen();
  }
}

/// Feed Komunitas terbaru.
///
/// Dibuang saat tidak ada layar yang mendengarkan, sehingga membuka kembali
/// tab Komunitas selalu mengambil data terbaru dari cache atau server.
final communityFeedProvider =
    NotifierProvider.autoDispose<
      CommunityFeedController,
      AsyncValue<CommunityFeedState>
    >(CommunityFeedController.new);
