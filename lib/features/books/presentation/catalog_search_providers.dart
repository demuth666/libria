import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/connectivity_service.dart';
import '../data/book.dart';
import '../data/book_page_loader.dart';
import '../data/book_repository.dart';

/// Galat pencarian katalog dengan pesan ramah pengguna.
///
/// [isOffline] membedakan kegagalan karena perangkat tanpa koneksi dan cache
/// kosong dari kegagalan umum, supaya layar bisa menampilkan pesan offline
/// yang sesuai.
class CatalogSearchFailure implements Exception {
  const CatalogSearchFailure(this.message, {this.isOffline = false});

  final String message;
  final bool isOffline;

  @override
  String toString() => message;
}

/// Data hasil pencarian katalog yang berhasil dimuat.
class CatalogSearchState {
  const CatalogSearchState({
    this.books = const <Book>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.term = '',
  });

  final List<Book> books;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  /// Kata kunci aktif, sudah di-trim.
  final String term;

  /// `true` bila layar harus menampilkan hasil, bukan petunjuk awal.
  bool get isSearchActive => term.isNotEmpty;

  bool get isEmpty => books.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  CatalogSearchState copyWith({
    List<Book>? books,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    String? term,
  }) {
    return CatalogSearchState(
      books: books ?? this.books,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      term: term ?? this.term,
    );
  }
}

/// Pengendali pencarian katalog pada layar Cari Katalog (T-042).
///
/// Semua akses data lewat [BookRepository]. Setiap query baru menaikkan
/// penghitung generasi sehingga respons query lama yang datang terlambat tidak
/// menimpa hasil kata kunci atau cakupan terbaru. Saat perangkat offline,
/// pencarian memakai cache Firestore agar hasil yang pernah dimuat tetap
/// tampil.
class CatalogSearchController extends Notifier<AsyncValue<CatalogSearchState>> {
  late BookRepository _repository;
  final BookPageLoader _pageLoader = BookPageLoader();
  bool _isOffline = false;
  String _term = '';
  BookSearchScope _scope = BookSearchScope.title;

  @override
  AsyncValue<CatalogSearchState> build() {
    _repository = ref.watch(bookRepositoryProvider);
    _isOffline = ref.read(connectivityProvider).value == false;

    ref.listen<AsyncValue<bool>>(connectivityProvider, (
      AsyncValue<bool>? previous,
      AsyncValue<bool> next,
    ) {
      final bool? online = next.value;
      if (online != null) {
        _isOffline = !online;
      }
    });

    return const AsyncData<CatalogSearchState>(CatalogSearchState());
  }

  /// Menjalankan pencarian baru dan mereset paginasi.
  ///
  /// Kata kunci kosong atau hanya spasi tidak menjalankan query; layar
  /// kembali ke petunjuk awal. Kata kunci dan cakupan yang sama dengan query
  /// aktif tidak memicu permintaan baru, kecuali state sedang galat.
  Future<void> search({required String term, required BookSearchScope scope}) {
    if (!ref.mounted) {
      return Future<void>.value();
    }
    final String normalized = term.trim();
    if (normalized.isEmpty) {
      _scope = scope;
      clear();
      return Future<void>.value();
    }
    if (normalized == _term && scope == _scope && !state.hasError) {
      return Future<void>.value();
    }
    _term = normalized;
    _scope = scope;
    return _loadFirstPage();
  }

  /// Memuat ulang halaman pertama dengan kata kunci dan cakupan aktif.
  Future<void> retry() {
    if (!ref.mounted || _term.isEmpty) {
      return Future<void>.value();
    }
    return _loadFirstPage();
  }

  /// Mengosongkan hasil dan kembali ke petunjuk awal.
  ///
  /// Penghitung generasi dinaikkan agar respons query yang masih berjalan
  /// tidak muncul setelah pencarian dihapus.
  void clear() {
    if (!ref.mounted) {
      return;
    }
    _pageLoader.begin();
    _term = '';
    state = const AsyncData<CatalogSearchState>(CatalogSearchState());
  }

  Future<void> _loadFirstPage() async {
    final int generation = _pageLoader.begin();
    final String term = _term;
    final BookSearchScope scope = _scope;
    state = const AsyncLoading<CatalogSearchState>();

    try {
      final BookPage page = await _pageLoader.loadFirst(
        generation,
        (BookCursor? cursor) => _fetchPage(
          term: term,
          scope: scope,
          cursor: cursor,
          cacheOnly: _isOffline,
        ),
      );
      if (!ref.mounted || !_pageLoader.isCurrent(generation)) {
        return;
      }
      state = AsyncData<CatalogSearchState>(
        CatalogSearchState(
          books: page.books,
          hasMore: page.hasMore,
          term: term,
        ),
      );
    } catch (error, stackTrace) {
      if (!ref.mounted || !_pageLoader.isCurrent(generation)) {
        return;
      }
      state = AsyncError<CatalogSearchState>(_toFailure(error), stackTrace);
    }
  }

  /// Memuat halaman berikutnya dan menambahkannya tanpa duplikat.
  ///
  /// Bila pemuatan gagal, hasil yang sudah tampil dipertahankan dan
  /// [CatalogSearchState.loadMoreFailed] diisi agar layar bisa menawarkan
  /// percobaan ulang.
  Future<void> loadMore() async {
    if (!ref.mounted) {
      return;
    }
    final CatalogSearchState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    final int generation = _pageLoader.generation;
    state = AsyncData<CatalogSearchState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final BookPage page = await _pageLoader.loadNext(
        generation,
        (BookCursor? cursor) => _fetchPage(
          term: _term,
          scope: _scope,
          cursor: cursor,
          cacheOnly: _isOffline,
        ),
      );
      if (!ref.mounted || !_pageLoader.isCurrent(generation)) {
        return;
      }
      final CatalogSearchState? latest = state.value;
      if (latest == null) {
        return;
      }
      state = AsyncData<CatalogSearchState>(
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
      final CatalogSearchState? latest = state.value;
      if (latest != null) {
        state = AsyncData<CatalogSearchState>(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }

  Future<BookPage> _fetchPage({
    required String term,
    required BookSearchScope scope,
    BookCursor? cursor,
    required bool cacheOnly,
  }) async {
    final BookPage page = await _repository.search(
      term,
      scope: scope,
      limit: bookPageSize,
      cursor: cursor,
      source: cacheOnly
          ? BookSearchSource.cacheOnly
          : BookSearchSource.serverAndCache,
    );
    if (cacheOnly && page.books.isEmpty) {
      // Source.cache mengembalikan snapshot kosong bila query belum pernah
      // tersimpan di cache. Perlakukan sebagai cache kosong agar layar
      // menampilkan pesan offline, bukan "tidak ada buku yang cocok".
      throw const CatalogSearchFailure(
        AppStrings.catalogSearchOfflineMessage,
        isOffline: true,
      );
    }
    return page;
  }

  CatalogSearchFailure _toFailure(Object error) {
    if (error is CatalogSearchFailure) {
      return error;
    }
    if (error is BookFailure) {
      return CatalogSearchFailure(error.message);
    }
    if (_isOffline) {
      return const CatalogSearchFailure(
        AppStrings.catalogSearchOfflineMessage,
        isOffline: true,
      );
    }
    return const CatalogSearchFailure(AppStrings.catalogSearchError);
  }
}

/// Pencarian katalog pada rute `/home/library/search`.
///
/// Dibuang saat layar tidak lagi mendengarkan, sehingga membuka pencarian
/// kembali selalu mulai dari petunjuk awal.
final NotifierProvider<CatalogSearchController, AsyncValue<CatalogSearchState>>
catalogSearchProvider =
    NotifierProvider.autoDispose<
      CatalogSearchController,
      AsyncValue<CatalogSearchState>
    >(CatalogSearchController.new);
