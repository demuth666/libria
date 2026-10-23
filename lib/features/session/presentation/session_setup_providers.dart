import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/data/book.dart';
import '../../books/data/book_page_loader.dart';
import '../../books/data/book_repository.dart';

/// Data katalog yang berhasil dimuat pada layar pengaturan sesi.
///
/// Status loading dan galat disimpan oleh [AsyncValue] pada
/// [sessionCatalogProvider]; kelas ini hanya memuat isi halaman dan penanda
/// paginasi.
class SessionCatalogData {
  const SessionCatalogData({
    this.books = const <Book>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Book> books;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get isEmpty => books.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  SessionCatalogData copyWith({
    List<Book>? books,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return SessionCatalogData(
      books: books ?? this.books,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Pengendali daftar katalog pada layar pengaturan sesi.
///
/// Semua akses data lewat [BookRepository]. Halaman pertama dimuat sekali saat
/// layar dibuka, lalu [loadMore] menambahkan halaman berikutnya tanpa duplikat.
/// Respons dari query lama diabaikan lewat [BookPageLoader] bila pengguna
/// memuat ulang daftar saat permintaan sebelumnya masih berjalan.
class SessionCatalogController
    extends Notifier<AsyncValue<SessionCatalogData>> {
  late BookRepository _repository;
  final BookPageLoader _pageLoader = BookPageLoader();
  bool _started = false;

  @override
  AsyncValue<SessionCatalogData> build() {
    _repository = ref.watch(bookRepositoryProvider);
    return const AsyncLoading<SessionCatalogData>();
  }

  /// Memuat halaman pertama sekali saja saat layar pertama kali dibuka.
  Future<void> ensureLoaded() {
    if (!ref.mounted || _started) {
      return Future<void>.value();
    }
    _started = true;
    return _loadFirstPage();
  }

  /// Memuat ulang halaman pertama setelah galat atau dari aksi Coba Lagi.
  Future<void> retry() {
    if (!ref.mounted) {
      return Future<void>.value();
    }
    _started = true;
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final int generation = _pageLoader.begin();
    state = const AsyncLoading<SessionCatalogData>();

    try {
      final BookPage page = await _pageLoader.loadFirst(
        generation,
        (BookCursor? cursor) => _repository.fetchPage(cursor: cursor),
      );
      if (!ref.mounted || !_pageLoader.isCurrent(generation)) {
        return;
      }
      state = AsyncData<SessionCatalogData>(
        SessionCatalogData(books: page.books, hasMore: page.hasMore),
      );
    } catch (error, stackTrace) {
      if (!ref.mounted || !_pageLoader.isCurrent(generation)) {
        return;
      }
      state = AsyncError<SessionCatalogData>(error, stackTrace);
    }
  }

  /// Memuat halaman berikutnya dan menambahkannya tanpa duplikat.
  Future<void> loadMore() async {
    if (!ref.mounted) {
      return;
    }
    final SessionCatalogData? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }

    final int generation = _pageLoader.generation;
    state = AsyncData<SessionCatalogData>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final BookPage page = await _pageLoader.loadNext(
        generation,
        (BookCursor? cursor) => _repository.fetchPage(cursor: cursor),
      );
      if (!ref.mounted || !_pageLoader.isCurrent(generation)) {
        return;
      }
      final SessionCatalogData? latest = state.value;
      if (latest == null) {
        return;
      }
      state = AsyncData<SessionCatalogData>(
        latest.copyWith(
          books: appendUniqueBooks(latest.books, page.books),
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted || !_pageLoader.isCurrent(generation)) {
        return;
      }
      final SessionCatalogData? latest = state.value;
      if (latest != null) {
        state = AsyncData<SessionCatalogData>(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }
}

/// Katalog buku untuk pemilihan buku pada rute `/session/setup` (T-052).
///
/// Dibuang saat layar pengaturan sesi ditutup, sehingga membuka kembali layar
/// selalu mengambil halaman pertama terbaru.
final NotifierProvider<SessionCatalogController, AsyncValue<SessionCatalogData>>
sessionCatalogProvider =
    NotifierProvider.autoDispose<
      SessionCatalogController,
      AsyncValue<SessionCatalogData>
    >(SessionCatalogController.new);
