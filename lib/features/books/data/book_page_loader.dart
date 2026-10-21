import 'book_repository.dart';

/// Pemuat halaman buku berpaginasi dengan kursor dan penghitung generasi.
///
/// Dipakai bersama oleh daftar buku admin dan pencarian katalog agar aturan
/// kursor, paginasi, dan pengabaian respons lama tidak ditulis dua kali.
/// Pemanggil tetap memiliki state tampilannya sendiri; kelas ini hanya
/// mengurus kursor halaman dan urutan query.
class BookPageLoader {
  BookCursor? _cursor;
  int _generation = 0;

  /// Generasi query yang sedang aktif.
  int get generation => _generation;

  /// Memulai query baru: membuang kursor lama dan menaikkan generasi.
  ///
  /// Nilai kembalian dikirim ke [loadFirst] atau [loadNext] dan dipakai
  /// pemanggil untuk memeriksa apakah respons masih relevan.
  int begin() {
    _cursor = null;
    return ++_generation;
  }

  /// `true` bila [generation] masih query terbaru.
  bool isCurrent(int generation) => generation == _generation;

  /// Memuat halaman pertama lewat [fetch].
  ///
  /// Kursor hanya diperbarui bila [generation] masih query terbaru, sehingga
  /// respons lama tidak bisa menggeser posisi halaman query baru.
  Future<BookPage> loadFirst(
    int generation,
    Future<BookPage> Function(BookCursor? cursor) fetch,
  ) async {
    final BookPage page = await fetch(null);
    if (isCurrent(generation)) {
      _cursor = page.nextCursor;
    }
    return page;
  }

  /// Memuat halaman berikutnya lewat [fetch] dari kursor terakhir.
  ///
  /// Bila pemanggilan gagal, kursor tetap di posisi sebelumnya agar halaman
  /// yang sama bisa dicoba lagi.
  Future<BookPage> loadNext(
    int generation,
    Future<BookPage> Function(BookCursor? cursor) fetch,
  ) async {
    final BookPage page = await fetch(_cursor);
    if (isCurrent(generation)) {
      _cursor = page.nextCursor;
    }
    return page;
  }
}
