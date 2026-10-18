import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import 'book.dart';

/// Batas jumlah buku per halaman pada daftar berpaginasi.
const int bookPageSize = 20;

/// Batas maksimum jumlah buku per halaman yang diterima repository.
const int bookMaxPageSize = 50;

/// Galat katalog buku dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class BookFailure implements Exception {
  const BookFailure(this.message);

  final String message;

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
  /// sehingga `x` pada ISBN-10 menjadi `X`.
  static String normalizeIsbn(String isbn) =>
      isbn.replaceAll(RegExp(r'[\s-]+'), '').toUpperCase();

  /// Mengambil buku berdasarkan ID dokumen, atau `null` bila tidak ada.
  Future<Book?> getById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _books
        .doc(id)
        .get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return Book.fromMap(snapshot.id, data);
  }

  /// Mengambil buku berdasarkan ISBN, atau `null` bila tidak ada.
  ///
  /// Input dengan spasi, tanda hubung, atau huruf `x` kecil tetap menemukan
  /// buku yang sama karena [normalizeIsbn] diterapkan lebih dulu.
  Future<Book?> findByIsbn(String isbn) async {
    final String normalized = normalizeIsbn(isbn);
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

  /// Mencari buku yang judulnya diawali [prefix], tanpa peka huruf besar
  /// kecil, memakai field turunan `titleLower`.
  ///
  /// Hasil berpaginasi: kirim [BookPage.nextCursor] sebagai [cursor] untuk
  /// melanjutkan pencarian tanpa mengulang item.
  Future<BookPage> searchByTitlePrefix(
    String prefix, {
    int limit = bookPageSize,
    BookCursor? cursor,
  }) {
    return _searchByPrefix('titleLower', prefix, limit: limit, cursor: cursor);
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
  }) {
    return _searchByPrefix('authorLower', prefix, limit: limit, cursor: cursor);
  }

  Future<BookPage> _searchByPrefix(
    String field,
    String prefix, {
    required int limit,
    BookCursor? cursor,
  }) async {
    final String normalized = prefix.trim().toLowerCase();
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
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
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

  /// Menambah buku baru dan mengembalikan ID dokumennya.
  ///
  /// ISBN dinormalisasi lebih dulu; bila sudah dipakai buku lain,
  /// [BookFailure] dilempar sebelum dokumen ditulis. Timestamp diisi server
  /// lewat [buildCreateMap].
  Future<String> createBook(Book book) async {
    await _assertIsbnAvailable(normalizeIsbn(book.isbn));
    final DocumentReference<Map<String, dynamic>> doc = _books.doc();
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
    await _assertIsbnAvailable(normalizeIsbn(book.isbn), exceptId: book.id);
    try {
      await _books.doc(book.id).update(buildUpdateMap(book));
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') {
        throw const BookFailure(AppStrings.bookNotFound);
      }
      rethrow;
    }
  }

  /// Menghapus dokumen buku dari koleksi.
  Future<void> deleteBook(String id) => _books.doc(id).delete();

  Future<void> _assertIsbnAvailable(String isbn, {String? exceptId}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _books
        .where('isbn', isEqualTo: isbn)
        .limit(2)
        .get();
    final bool duplicate = snapshot.docs.any(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id != exceptId,
    );
    if (duplicate) {
      throw const BookFailure(AppStrings.bookIsbnDuplicate);
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
      'isbn': normalizeIsbn(book.isbn),
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
