import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/review.dart';
import '../data/review_repository.dart';

/// Data daftar ulasan yang berhasil dimuat.
class ReviewListState {
  const ReviewListState({
    this.reviews = const <Review>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Review> reviews;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => reviews.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore && !loadMoreFailed;

  ReviewListState copyWith({
    List<Review>? reviews,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return ReviewListState(
      reviews: reviews ?? this.reviews,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali daftar ulasan pada Detail Buku (T-062, FR-R2).
///
/// Sumber data adalah stream Firestore lewat [ReviewRepository], sehingga
/// ulasan baru langsung tampil dan data cache tetap terbaca saat offline.
/// Jumlah ulasan dinaikkan bertahap saat pengguna memilih "Muat Lebih
/// Banyak"; data lama dipertahankan selama pemuatan berikutnya dan saat
/// pemuatan gagal.
class ReviewListController extends Notifier<AsyncValue<ReviewListState>> {
  ReviewListController(this.bookId);

  final String bookId;

  late ReviewRepository _repository;
  StreamSubscription<List<Review>>? _subscription;
  int _limit = reviewPageSize;
  int _generation = 0;

  @override
  AsyncValue<ReviewListState> build() {
    _repository = ref.watch(reviewRepositoryProvider);
    _limit = reviewPageSize;
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

    return const AsyncLoading<ReviewListState>();
  }

  void _listen() {
    final int generation = ++_generation;
    _subscription?.cancel();

    final Stream<List<Review>> stream = _repository.watchReviews(
      bookId,
      limit: _limit,
    );

    _subscription = stream.listen(
      (List<Review> reviews) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        state = AsyncData<ReviewListState>(
          ReviewListState(reviews: reviews, hasMore: reviews.length >= _limit),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ref.mounted || generation != _generation) {
          return;
        }
        final ReviewListState? current = state.value;
        if (current != null && current.reviews.isNotEmpty) {
          state = AsyncData<ReviewListState>(
            current.copyWith(isLoadingMore: false, loadMoreFailed: true),
          );
          return;
        }
        state = AsyncError<ReviewListState>(error, stackTrace);
      },
    );
  }

  /// Memuat lebih banyak ulasan tanpa membuang daftar yang sudah tampil.
  void loadMore() {
    final ReviewListState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    _limit += reviewPageSize;
    state = AsyncData<ReviewListState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    _listen();
  }

  /// Memuat ulang daftar dari halaman pertama.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _limit = reviewPageSize;
    state = const AsyncLoading<ReviewListState>();
    _listen();
  }
}

/// Daftar ulasan untuk satu buku.
///
/// Dibuang saat tidak ada layar yang mendengarkan, sehingga membuka kembali
/// Detail Buku selalu mengambil data terbaru dari cache atau server.
final reviewListProvider = NotifierProvider.autoDispose
    .family<ReviewListController, AsyncValue<ReviewListState>, String>(
      ReviewListController.new,
    );

/// Stream ulasan milik pengguna saat ini untuk satu buku.
///
/// Dipakai formulir ulasan agar isian lama langsung tersedia dan dapat diubah.
final myReviewProvider = StreamProvider.autoDispose.family<Review?, String>((
  Ref ref,
  String bookId,
) {
  return ref.watch(reviewRepositoryProvider).watchMyReview(bookId);
}, retry: (int retryCount, Object error) => null);
