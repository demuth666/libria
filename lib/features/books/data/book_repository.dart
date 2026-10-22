import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/isbn.dart';
import 'book.dart';

/// Batas jumlah buku per halaman pada daftar berpaginasi.
const int bookPageSize = 20;

/// Batas maksimum jumlah buku per halaman yang diterima repository.
const int bookMaxPageSize = 50;

/// Kode galat katalog buku untuk percabangan yang tidak bergantung pada teks
/// pesan yang tampil ke pengguna.
enum BookFailureCode { duplicateIsbn, notFound }

/// Galat katalog buku dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class BookFailure implements Exception {
  const BookFailure(this.message, {this.code});

  final String message;
  final BookFailureCode? code;

  @override
  String toString() => message;
}

/// Kursor halaman berikutnya pada [BookRepository.fetchPage].
///
/// Sengaja tidak membuka isinya: widget hanya menyimpan nilai ini dan
/// mengirimkannya kembali ke repository, tanpa mengakses Firestore langsung.
class BookCursor {
  const BookCursor._(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;
}

/// Satu halaman daftar buku beserta kursor untuk melanjutkan.
class BookPage {
  const BookPage({required this.books, required this.hasMore, this.nextCursor});

  final List<Book> books;

  /// `true` bila masih ada buku setelah halaman ini.
  final bool hasMore;

  /// Kursor halaman berikutnya, bernilai `null` bila [hasMore] bernilai
  /// `false`.
  final BookCursor? nextCursor;
}

/// Cakupan pencarian katalog yang dipakai bersama daftar buku admin dan
/// pencarian katalog pengguna.
enum BookSearchScope { title, author, isbn }

/// Sumber data untuk pencarian katalog.
///
/// Pencarian biasa memakai server dan cache Firestore. Saat perangkat offline,
/// layar pencarian memakai [cacheOnly] agar hasil yang pernah dimuat tetap
/// tampil tanpa menunggu koneksi dan tanpa loading tanpa akhir.
enum BookSearchSource { serverAndCache, cacheOnly }

/// Menggabungkan halaman berikutnya tanpa ID duplikat dan mempertahankan
/// urutan halaman sebelumnya lebih dulu.
///
/// Aturan ini dipakai bersama oleh daftar buku admin dan pencarian katalog
/// agar paginasi keduanya konsisten.
List<Book> appendUniqueBooks(List<Book> current, Iterable<Book> incoming) {
  final List<Book> merged = List<Book>.of(current);
  final Set<String> ids = merged.map((Book book) => book.id).toSet();
  for (final Book book in incoming) {
    if (ids.add(book.id)) {
      merged.add(book);
    }
  }
  return List<Book>.unmodifiable(merged);
}

/// Akses ke koleksi `books` di Firestore (PRD bagian 8).
///
/// Widget tidak memanggil `FirebaseFirestore` secara langsung untuk data
/// buku; semua akses lewat kelas ini (lihat [bookRepositoryProvider]).
class BookRepository {
  BookRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _books =>
      _firestore.collection(FirestorePaths.books);

  /// Menyeragamkan ISBN agar pencarian dan pemeriksaan duplikat tidak
  /// bergantung pada format penulisan.
  ///
  /// Spasi dan tanda hubung dibuang, lalu semua huruf dijadikan huruf besar
  /// sehingga `x` pada ISBN-10 menjadi `X`. Aturannya ada di [Isbn.normalize]
  /// agar katalog dan log ISBN memakai implementasi yang sama. Method ini
  /// dipertahankan agar pemanggil lama tetap berfungsi.
  static String normalizeIsbn(String isbn) => Isbn.normalize(isbn);

  /// Mengambil buku berdasarkan ID dokumen, atau `null` bila tidak ada.
  ///
  /// [source] dapat diisi [BookSearchSource.cacheOnly] saat perangkat offline
  /// agar buku yang pernah dimuat tetap tampil dari cache Firestore.
  Future<Book?> getById(
    String id, {
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) async {
    final DocumentReference<Map<String, dynamic>> document = _books.doc(id);
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        source == BookSearchSource.cacheOnly
        ? await document.get(const GetOptions(source: Source.cache))
        : await document.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return Book.fromMap(snapshot.id, data);
  }

  /// Mengambil buku berdasarkan ISBN, atau `null` bila tidak ada.
  ///
  /// Input dengan spasi, tanda hubung, atau huruf `x` kecil tetap menemukan
  /// buku yang sama karena [Isbn.normalize] diterapkan lebih dulu.
  Future<Book?> findByIsbn(String isbn) async {
    final String normalized = Isbn.normalize(isbn);
    if (normalized.isEmpty) {
      return null;
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _books
        .where('isbn', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs.first;
    return Book.fromMap(doc.id, doc.data());
  }

  /// Mencari buku sesuai [scope] memakai aturan awalan yang sama untuk daftar
  /// admin dan pencarian katalog pengguna.
  Future<BookPage> search(
    String prefix, {
    required BookSearchScope scope,
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    switch (scope) {
      case BookSearchScope.title:
        return searchByTitlePrefix(
          prefix,
          limit: limit,
          cursor: cursor,
          source: source,
        );
      case BookSearchScope.author:
        return searchByAuthorPrefix(
          prefix,
          limit: limit,
          cursor: cursor,
          source: source,
        );
      case BookSearchScope.isbn:
        return searchByIsbnPrefix(
          prefix,
          limit: limit,
          cursor: cursor,
          source: source,
        );
    }
  }

  /// Mencari buku yang judulnya diawali [prefix], tanpa peka huruf besar
  /// kecil, memakai field turunan `titleLower`.
  ///
  /// Hasil berpaginasi: kirim [BookPage.nextCursor] sebagai [cursor] untuk
  /// melanjutkan pencarian tanpa mengulang item.
  Future<BookPage> searchByTitlePrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    return _searchByPrefix(
      'titleLower',
      prefix,
      limit: limit,
      cursor: cursor,
      source: source,
    );
  }

  /// Mencari buku yang nama penulisnya diawali [prefix], tanpa peka huruf
  /// besar kecil, memakai field turunan `authorLower`.
  ///
  /// Hasil berpaginasi: kirim [BookPage.nextCursor] sebagai [cursor] untuk
  /// melanjutkan pencarian tanpa mengulang item.
  Future<BookPage> searchByAuthorPrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    return _searchByPrefix(
      'authorLower',
      prefix,
      limit: limit,
      cursor: cursor,
      source: source,
    );
  }

  /// Mencari buku yang ISBN-nya diawali [prefix].
  ///
  /// Awalan dinormalisasi lebih dulu dengan [Isbn.normalize], sehingga spasi,
  /// tanda hubung, dan huruf kecil diabaikan. Pencarian memakai field `isbn`
  /// yang tersimpan dalam bentuk ternormalisasi.
  Future<BookPage> searchByIsbnPrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
    BookSearchSource source = BookSearchSource.serverAndCache,
  }) {
    return _searchByNormalizedPrefix(
      'isbn',
      Isbn.normalize(prefix),
      limit: limit,
      cursor: cursor,
      source: source,
    );
  }

  Future<BookPage> _searchByPrefix(
    String field,
    String prefix, {
    required int limit,
    BookCursor? cursor,
    required BookSearchSource source,
  }) {
    return _searchByNormalizedPrefix(
      field,
      prefix.trim().toLowerCase(),
      limit: limit,
      cursor: cursor,
      source: source,
    );
  }

  Future<BookPage> _searchByNormalizedPrefix(
    String field,
    String normalized, {
    required int limit,
    BookCursor? cursor,
    required BookSearchSource source,
  }) async {
    if (normalized.isEmpty) {
      return const BookPage(books: <Book>[], hasMore: false);
    }
    final int pageSize = _resolvePageSize(limit);
    Query<Map<String, dynamic>> query = _books
        .where(field, isGreaterThanOrEqualTo: normalized)
        .where(field, isLessThan: '$normalized\uf8ff')
        .orderBy(field)
        .limit(pageSize + 1);
    if (cursor != null) {
      query = query.startAfterDocument(cursor._snapshot);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        source == BookSearchSource.cacheOnly
        ? await query.get(const GetOptions(source: Source.cache))
        : await query.get();
    return _toPage(snapshot.docs, pageSize);
  }

  /// Daftar buku terbaru yang berpaginasi.
  ///
  /// [limit] dibatasi antara 1 dan [bookMaxPageSize]. Kirim [cursor] dari
  /// [BookPage.nextCursor] untuk melanjutkan, sehingga halaman berikutnya
  /// dimulai setelah item terakhir halaman sebelumnya tanpa mengulangnya.
  Future<BookPage> fetchPage({
    int limit = bookPageSize,
    BookCursor? cursor,
  }) async {
    final int pageSize = _resolvePageSize(limit);
    Query<Map<String, dynamic>> query = _books
        .orderBy('createdAt', descending: true)
        .limit(pageSize + 1);
    if (cursor != null) {
      query = query.startAfterDocument(cursor._snapshot);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return _toPage(snapshot.docs, pageSize);
  }

  /// Jumlah seluruh buku di katalog, dipakai kartu dashboard admin (T-031).
  Future<int> countBooks() async {
    final AggregateQuerySnapshot snapshot = await _books.count().get();
    return snapshot.count ?? 0;
  }

  BookPage _toPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    final bool hasMore = docs.length > pageSize;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs = hasMore
        ? docs.sublist(0, pageSize)
        : docs;
    return BookPage(
      books: pageDocs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                Book.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: hasMore ? BookCursor._(pageDocs.last) : null,
    );
  }

  /// ID dokumen baru tanpa menulis apa pun.
  ///
  /// Dipakai formulir tambah buku agar ID dokumen sudah diketahui sebelum
  /// [createBook] dipanggil.
  String newBookId() => _books.doc().id;

  /// Menambah buku baru dan mengembalikan ID dokumennya.
  ///
  /// Bila [Book.id] terisi, dokumen memakai ID tersebut; bila kosong,
  /// repository membuat ID baru. ISBN dinormalisasi lebih dulu; bila sudah
  /// dipakai buku lain, [BookFailure] dilempar sebelum dokumen ditulis.
  /// Timestamp diisi server lewat [buildCreateMap].
  Future<String> createBook(Book book) async {
    await _assertIsbnAvailable(Isbn.normalize(book.isbn));
    final DocumentReference<Map<String, dynamic>> doc = book.id.isEmpty
        ? _books.doc()
        : _books.doc(book.id);
    await doc.set(buildCreateMap(book));
    return doc.id;
  }

  /// Mengubah data buku tanpa menyentuh rating, pembuat, atau tanggal
  /// pembuatan dokumen.
  ///
  /// Hanya field isi, field turunan, dan `updatedAt` yang ditulis. ISBN
  /// dinormalisasi dan diperiksa ketersediaannya terlebih dahulu, dengan
  /// dokumen [Book.id] sendiri dikecualikan dari pemeriksaan duplikat.
  Future<void> updateBook(Book book) async {
    await _assertIsbnAvailable(Isbn.normalize(book.isbn), exceptId: book.id);
    try {
      await _books.doc(book.id).update(buildUpdateMap(book));
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') {
        throw const BookFailure(
          AppStrings.bookNotFound,
          code: BookFailureCode.notFound,
        );
      }
      rethrow;
    }
  }

  /// Menghapus dokumen buku dari koleksi.
  Future<void> deleteBook(String id) => _books.doc(id).delete();

  /// Memastikan [isbn] belum dipakai buku lain.
  ///
  /// Dipakai formulir sebelum mengunggah sampul agar kegagalan ISBN duplikat
  /// tidak meninggalkan atau menimpa berkas sampul. [exceptId] mengecualikan
  /// buku yang sedang diubah. Pemeriksaan tetap diulang oleh [createBook] dan
  /// [updateBook] sebelum dokumen ditulis.
  Future<void> assertIsbnAvailable(String isbn, {String? exceptId}) {
    return _assertIsbnAvailable(Isbn.normalize(isbn), exceptId: exceptId);
  }

  Future<void> _assertIsbnAvailable(String isbn, {String? exceptId}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _books
        .where('isbn', isEqualTo: isbn)
        .limit(2)
        .get();
    final bool duplicate = snapshot.docs.any(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id != exceptId,
    );
    if (duplicate) {
      throw const BookFailure(
        AppStrings.bookIsbnDuplicate,
        code: BookFailureCode.duplicateIsbn,
      );
    }
  }

  static int _resolvePageSize(int limit) {
    if (limit < 1) {
      return 1;
    }
    if (limit > bookMaxPageSize) {
      return bookMaxPageSize;
    }
    return limit;
  }

  /// Field isi yang boleh ditulis saat membuat maupun mengubah buku.
  ///
  /// ISBN dinormalisasi dan field turunan dihitung ulang dari judul serta
  /// penulis agar pencarian tetap konsisten.
  static Map<String, dynamic> _editableFields(Book book) {
    return <String, dynamic>{
      'title': book.title,
      'author': book.author,
      'isbn': Isbn.normalize(book.isbn),
      'publisher': book.publisher,
      'year': book.year,
      'totalPages': book.totalPages,
      'category': book.category,
      'synopsis': book.synopsis,
      'coverUrl': book.coverUrl,
      'titleLower': book.titleLower,
      'authorLower': book.authorLower,
    };
  }

  /// Peta field untuk membuat dokumen baru.
  ///
  /// Bebas dari akses Firestore sehingga bisa diuji langsung. ISBN ditulis
  /// dalam bentuk ternormalisasi, field turunan dihitung dari judul dan
  /// penulis, dan kedua timestamp memakai `FieldValue.serverTimestamp()`.
  static Map<String, dynamic> buildCreateMap(Book book) {
    return <String, dynamic>{
      ..._editableFields(book),
      'ratingAverage': book.ratingAverage,
      'ratingCount': book.ratingCount,
      'createdBy': book.createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Peta field untuk mengubah buku.
  ///
  /// Sengaja tidak memuat `ratingAverage`, `ratingCount`, `createdBy`, dan
  /// `createdAt` agar nilai yang sudah ada tidak tertimpa. `updatedAt`
  /// diperbarui dengan timestamp server.
  static Map<String, dynamic> buildUpdateMap(Book book) {
    return <String, dynamic>{
      ..._editableFields(book),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Akses [BookRepository] bersama lewat Riverpod.
final Provider<BookRepository> bookRepositoryProvider =
    Provider<BookRepository>((Ref ref) => BookRepository());
