import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/connectivity_service.dart';
import '../data/book.dart';
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
    this.scope = BookSearchScope.title,
  });

  final List<Book> books;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  /// Kata kunci aktif, sudah di-trim.
  final String term;

  /// Cakupan pencarian aktif.
  final BookSearchScope scope;

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
    BookSearchScope? scope,
  }) {
    return CatalogSearchState(
      books: books ?? this.books,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      term: term ?? this.term,
      scope: scope ?? this.scope,
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
  BookCursor? _nextCursor;
  int _generation = 0;
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

    return AsyncData<CatalogSearchState>(CatalogSearchState(scope: _scope));
  }

  /// Menjalankan pencarian baru dan mereset paginasi.
  ///
  /// Kata kunci kosong atau hanya spasi tidak menjalankan query; layar
  /// kembali ke petunjuk awal. Kata kunci dan cakupan yang sama dengan query
  /// aktif tidak memicu permintaan baru, kecuali state sedang galat.
  Future<void> search({required String term, required BookSearchScope scope}) {
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
    if (_term.isEmpty) {
      return Future<void>.value();
    }
    return _loadFirstPage();
  }

  /// Mengosongkan hasil dan kembali ke petunjuk awal.
  ///
  /// Penghitung generasi dinaikkan agar respons query yang masih berjalan
  /// tidak muncul setelah pencarian dihapus.
  void clear() {
    _generation++;
    _nextCursor = null;
    _term = '';
    state = AsyncData<CatalogSearchState>(CatalogSearchState(scope: _scope));
  }

  Future<void> _loadFirstPage() async {
    final int generation = ++_generation;
    final String term = _term;
    final BookSearchScope scope = _scope;
    _nextCursor = null;
    state = const AsyncLoading<CatalogSearchState>();

    try {
      final BookPage page = await _fetchPage(
        term: term,
        scope: scope,
        cacheOnly: _isOffline,
      );
      if (generation != _generation) {
        return;
      }
      _nextCursor = page.nextCursor;
      state = AsyncData<CatalogSearchState>(
        CatalogSearchState(
          books: page.books,
          hasMore: page.hasMore,
          term: term,
          scope: scope,
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _generation) {
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
    final CatalogSearchState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    final int generation = _generation;
    state = AsyncData<CatalogSearchState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final BookPage page = await _fetchPage(
        term: _term,
        scope: _scope,
        cursor: _nextCursor,
        cacheOnly: _isOffline,
      );
      if (generation != _generation) {
        return;
      }
      final CatalogSearchState? latest = state.value;
      if (latest == null) {
        return;
      }
      _nextCursor = page.nextCursor;
      state = AsyncData<CatalogSearchState>(
        latest.copyWith(
          books: appendUniqueBooks(latest.books, page.books),
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (generation != _generation) {
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
  }) {
    return _repository.search(
      term,
      scope: scope,
      limit: bookPageSize,
      cursor: cursor,
      source: cacheOnly
          ? BookSearchSource.cacheOnly
          : BookSearchSource.serverAndCache,
    );
  }

  CatalogSearchFailure _toFailure(Object error) {
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
