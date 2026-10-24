import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post.dart';
import '../data/post_repository.dart';
import '../data/reply.dart';

/// Data balasan yang berhasil dimuat pada Detail Postingan.
class ReplyListState {
  const ReplyListState({
    this.replies = const <Reply>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Reply> replies;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => replies.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore && !loadMoreFailed;

  ReplyListState copyWith({
    List<Reply>? replies,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return ReplyListState(
      replies: replies ?? this.replies,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali daftar balasan pada rute `/post/:id` (T-082, FR-K3).
///
/// Sumber data adalah stream Firestore lewat [PostRepository], sehingga
/// balasan baru atau terhapus langsung memperbarui daftar tanpa memuat ulang
/// layar. Jumlah balasan yang dimuat dinaikkan bertahap saat pengguna memilih
/// "Muat Balasan Lainnya"; data lama dipertahankan selama pemuatan berikutnya
/// dan saat pemuatan gagal.
class ReplyListController extends Notifier<AsyncValue<ReplyListState>> {
  ReplyListController(this.postId);

  final String postId;

  late PostRepository _repository;
  StreamSubscription<List<Reply>>? _subscription;
  int _limit = replyPageSize;
  int _generation = 0;

  @override
  AsyncValue<ReplyListState> build() {
    _repository = ref.watch(postRepositoryProvider);
    _limit = replyPageSize;
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

    return const AsyncLoading<ReplyListState>();
  }

  void _listen() {
    final int generation = ++_generation;
    _subscription?.cancel();

    final Stream<List<Reply>> stream = _repository.watchReplies(
      postId,
      limit: _limit,
    );
    _subscription = stream.listen(
      (List<Reply> replies) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        state = AsyncData<ReplyListState>(
          ReplyListState(replies: replies, hasMore: replies.length >= _limit),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        final ReplyListState? current = state.value;
        if (current != null && current.replies.isNotEmpty) {
          state = AsyncData<ReplyListState>(
            current.copyWith(isLoadingMore: false, loadMoreFailed: true),
          );
          return;
        }
        state = AsyncError<ReplyListState>(error, stackTrace);
      },
    );
  }

  /// Memuat lebih banyak balasan tanpa membuang daftar yang sudah tampil.
  void loadMore() {
    final ReplyListState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    _limit += replyPageSize;
    state = AsyncData<ReplyListState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    _listen();
  }

  /// Memuat ulang balasan dari halaman pertama.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _limit = replyPageSize;
    state = const AsyncLoading<ReplyListState>();
    _listen();
  }
}

/// Stream postingan yang dibuka pada `/post/:id`.
///
/// Dibuang saat layar ditutup agar pembukaan berikutnya memakai data terbaru.
final postDetailProvider = StreamProvider.autoDispose.family<Post?, String>((
  Ref ref,
  String postId,
) {
  final PostRepository repository = ref.watch(postRepositoryProvider);
  return repository.watchPost(postId);
});

/// Daftar balasan untuk satu postingan.
final replyListProvider = NotifierProvider.autoDispose
    .family<ReplyListController, AsyncValue<ReplyListState>, String>(
      ReplyListController.new,
    );
