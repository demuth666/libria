import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/data/book.dart';
import '../../books/data/book_repository.dart';

/// Cakupan pencarian daftar buku admin.
enum AdminBookSearchScope { title, author, isbn }

/// Data daftar buku admin yang berhasil dimuat.
///
/// Status loading dan galat disimpan oleh [AsyncValue] pada
/// [adminBooksProvider]; kelas ini hanya memuat isi halaman, penanda paginasi,
/// kata kunci aktif, dan buku yang sedang dihapus.
class AdminBooksState {
  const AdminBooksState({
    this.books = const <Book>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.term = '',
    this.deletingBookIds = const <String>{},
  });

  final List<Book> books;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  /// Kata kunci yang dipakai halaman ini, sudah di-trim.
  final String term;

  /// ID buku yang sedang menunggu penghapusan.
  final Set<String> deletingBookIds;

  bool get isSearchActive => term.isNotEmpty;

  bool get isEmpty => books.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  AdminBooksState copyWith({
    List<Book>? books,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    String? term,
    Set<String>? deletingBookIds,
  }) {
    return AdminBooksState(
      books: books ?? this.books,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      term: term ?? this.term,
      deletingBookIds: deletingBookIds ?? this.deletingBookIds,
    );
  }
}

/// Pengendali daftar buku admin.
///
/// Semua akses data lewat [BookRepository]. Setiap query baru menaikkan
/// penghitung generasi sehingga respons query lama yang datang terlambat tidak
/// menimpa hasil query terbaru.
class AdminBooksController extends Notifier<AsyncValue<AdminBooksState>> {
  late BookRepository _repository;
  BookCursor? _nextCursor;
  int _generation = 0;
  bool _started = false;
  String _term = '';
  AdminBookSearchScope _scope = AdminBookSearchScope.title;

  @override
  AsyncValue<AdminBooksState> build() {
    _repository = ref.watch(bookRepositoryProvider);
    return const AsyncLoading<AdminBooksState>();
  }

  /// Memuat halaman pertama sekali saja saat layar pertama kali dibuka.
  Future<void> ensureLoaded() {
    if (_started) {
      return Future<void>.value();
    }
    _started = true;
    return _loadFirstPage();
  }

  /// Memuat ulang halaman pertama dengan pencarian yang sedang aktif.
  Future<void> reload() {
    _started = true;
    return _loadFirstPage();
  }

  /// Menjalankan pencarian baru dan mereset paginasi.
  ///
  /// Pencarian kosong mengembalikan daftar lengkap terbaru. Bila kata kunci
  /// dan cakupan sama dengan query aktif, tidak ada permintaan baru kecuali
  /// state sedang galat.
  Future<void> search({
    required String term,
    required AdminBookSearchScope scope,
  }) {
    final String normalized = term.trim();
    if (normalized.isEmpty && _term.isEmpty) {
      if (_scope != scope) {
        _scope = scope;
      }
      return Future<void>.value();
    }
    if (normalized == _term && scope == _scope && !state.hasError) {
      return Future<void>.value();
    }
    _term = normalized;
    _scope = scope;
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final int generation = ++_generation;
    final Set<String> deletingBookIds =
        state.value?.deletingBookIds ?? const <String>{};
    _nextCursor = null;
    state = const AsyncLoading<AdminBooksState>();

    try {
      final BookPage page = await _fetchPage(term: _term, scope: _scope);
      if (generation != _generation) {
        return;
      }
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminBooksState>(
        AdminBooksState(
          books: page.books,
          hasMore: page.hasMore,
          term: _term,
          deletingBookIds: deletingBookIds,
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _generation) {
        return;
      }
      state = AsyncError<AdminBooksState>(error, stackTrace);
    }
  }

  /// Memuat halaman berikutnya dan menambahkannya tanpa duplikat.
  Future<void> loadMore() async {
    final AdminBooksState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    final int generation = _generation;
    state = AsyncData<AdminBooksState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final BookPage page = await _fetchPage(
        term: _term,
        scope: _scope,
        cursor: _nextCursor,
      );
      if (generation != _generation) {
        return;
      }
      final AdminBooksState? latest = state.value;
      if (latest == null) {
        return;
      }
      final Set<String> existingIds = latest.books
          .map((Book book) => book.id)
          .toSet();
      final List<Book> appended = page.books
          .where((Book book) => !existingIds.contains(book.id))
          .toList(growable: false);
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminBooksState>(
        latest.copyWith(
          books: <Book>[...latest.books, ...appended],
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (generation != _generation) {
        return;
      }
      final AdminBooksState? latest = state.value;
      if (latest != null) {
        state = AsyncData<AdminBooksState>(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }

  /// Menghapus buku dari katalog dan membuangnya dari daftar.
  ///
  /// Buku tetap ada di daftar bila repository gagal. Ketukan ganda pada buku
  /// yang sama diabaikan selama penghapusan pertama masih berjalan. Bila
  /// halaman yang terlihat menjadi kosong padahal masih ada halaman lain,
  /// halaman pertama dimuat ulang agar sisa katalog tetap bisa dijangkau.
  Future<void> deleteBook(Book book) async {
    final AdminBooksState? current = state.value;
    if (current == null || current.deletingBookIds.contains(book.id)) {
      return;
    }
    state = AsyncData<AdminBooksState>(
      current.copyWith(
        deletingBookIds: <String>{...current.deletingBookIds, book.id},
      ),
    );

    try {
      await _repository.deleteBook(book.id);
      final AdminBooksState? latest = state.value;
      if (latest == null) {
        return;
      }
      final AdminBooksState updated = latest.copyWith(
        books: latest.books
            .where((Book item) => item.id != book.id)
            .toList(growable: false),
        deletingBookIds: <String>{...latest.deletingBookIds}..remove(book.id),
      );
      state = AsyncData<AdminBooksState>(updated);

      if (updated.isEmpty && updated.hasMore) {
        await reload();
      }
    } catch (_) {
      final AdminBooksState? latest = state.value;
      if (latest != null && latest.deletingBookIds.contains(book.id)) {
        state = AsyncData<AdminBooksState>(
          latest.copyWith(
            deletingBookIds: <String>{...latest.deletingBookIds}
              ..remove(book.id),
          ),
        );
      }
      rethrow;
    }
  }

  Future<BookPage> _fetchPage({
    required String term,
    required AdminBookSearchScope scope,
    BookCursor? cursor,
  }) {
    if (term.isEmpty) {
      return _repository.fetchPage(limit: bookPageSize, cursor: cursor);
    }
    switch (scope) {
      case AdminBookSearchScope.title:
        return _repository.searchByTitlePrefix(
          term,
          limit: bookPageSize,
          cursor: cursor,
        );
      case AdminBookSearchScope.author:
        return _repository.searchByAuthorPrefix(
          term,
          limit: bookPageSize,
          cursor: cursor,
        );
      case AdminBookSearchScope.isbn:
        return _repository.searchByIsbnPrefix(
          term,
          limit: bookPageSize,
          cursor: cursor,
        );
    }
  }
}

/// Permintaan memuat ulang daftar buku admin dari luar layar daftar.
///
/// Formulir tambah/ubah menaikkan nilainya setelah simpan berhasil. Bila
/// daftar sedang aktif di bawah formulir, listener layar daftar memuat ulang
/// halaman pertama. Bila daftar belum aktif (misalnya formulir dibuka dari Log
/// ISBN), layar daftar memuat data terbaru saat pertama kali dibuka.
class AdminBooksReloadController extends Notifier<int> {
  @override
  int build() => 0;

  void request() {
    state++;
  }
}

/// Penanda permintaan muat ulang daftar buku admin.
final NotifierProvider<AdminBooksReloadController, int>
adminBooksReloadProvider = NotifierProvider<AdminBooksReloadController, int>(
  AdminBooksReloadController.new,
);

/// Daftar buku admin pada rute `/admin/books`.
///
/// Dibuang saat tidak ada lagi layar yang mendengarkan, sehingga keluar dari
/// area admin lalu masuk kembali selalu memuat data terbaru.
final NotifierProvider<AdminBooksController, AsyncValue<AdminBooksState>>
adminBooksProvider =
    NotifierProvider.autoDispose<
      AdminBooksController,
      AsyncValue<AdminBooksState>
    >(AdminBooksController.new);
