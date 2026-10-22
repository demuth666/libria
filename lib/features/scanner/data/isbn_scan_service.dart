import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/isbn.dart';
import '../../books/data/book.dart';
import '../../books/data/book_repository.dart';
import '../../books/data/book_validators.dart';
import '../../isbn_logs/data/isbn_log_repository.dart';

/// Hasil satu pemindaian ISBN (FR-L5, T-044).
enum IsbnScanStatus {
  /// Buku dengan ISBN tersebut ada di katalog.
  found,

  /// ISBN valid tetapi belum ada di katalog; pemindaian sudah dicatat.
  notFound,

  /// Barcode terbaca, tetapi nilainya bukan ISBN yang valid.
  invalid,

  /// Pencarian gagal, misalnya karena koneksi atau izin Firestore.
  failure,
}

/// Hasil pemindaian yang siap dipakai layar pemindai.
class IsbnScanResult {
  const IsbnScanResult._({
    required this.status,
    required this.isbn,
    this.book,
    this.message,
    this.logError,
  });

  /// Buku ditemukan dan layar boleh membuka detail buku.
  const IsbnScanResult.found({required String isbn, required Book book})
    : this._(status: IsbnScanStatus.found, isbn: isbn, book: book);

  /// ISBN valid tetapi tidak ada di katalog. [logError] berisi pesan ramah
  /// bila pencatatan log ISBN gagal; pesan tidak ditemukan tetap ditampilkan.
  const IsbnScanResult.notFound({
    required String isbn,
    required String message,
    String? logError,
  }) : this._(
         status: IsbnScanStatus.notFound,
         isbn: isbn,
         message: message,
         logError: logError,
       );

  /// Barcode bukan ISBN yang valid; tidak ada log yang dicatat.
  const IsbnScanResult.invalid({required String message})
    : this._(status: IsbnScanStatus.invalid, isbn: '', message: message);

  /// Pencarian buku gagal dan dapat dicoba lagi.
  const IsbnScanResult.failure({required String message})
    : this._(status: IsbnScanStatus.failure, isbn: '', message: message);

  final IsbnScanStatus status;

  /// ISBN ternormalisasi, kosong bila nilainya tidak valid.
  final String isbn;

  /// Buku yang ditemukan; hanya terisi saat [status] adalah
  /// [IsbnScanStatus.found].
  final Book? book;

  /// Pesan ramah untuk ditampilkan pada status selain [IsbnScanStatus.found].
  final String? message;

  /// Pesan ramah bila pencatatan log ISBN gagal, tetapi buku tetap tidak
  /// ditemukan.
  final String? logError;

  bool get isFound => status == IsbnScanStatus.found;

  bool get isNotFound => status == IsbnScanStatus.notFound;
}

/// Logika pemindaian ISBN: validasi, pencarian katalog, dan pencatatan log.
///
/// Widget pemindai tidak mengakses Firestore secara langsung. Saat ISBN tidak
/// ditemukan, [scan] tetap mencatat log lewat [IsbnLogRepository.record]
/// (FR-L5) dan mengembalikan hasil tidak ditemukan meskipun pencatatan log
/// gagal, supaya pesan utama tetap sampai ke pengguna.
class IsbnScanService {
  IsbnScanService({
    required this.bookRepository,
    required this.isbnLogRepository,
  });

  final BookRepository bookRepository;
  final IsbnLogRepository isbnLogRepository;

  Future<IsbnScanResult> scan(String rawIsbn) async {
    final String isbn = Isbn.normalize(rawIsbn);
    if (!BookValidators.isValidIsbn(isbn)) {
      return const IsbnScanResult.invalid(
        message: AppStrings.isbnScanInvalidMessage,
      );
    }

    final Book? book;
    try {
      book = await bookRepository.findByIsbn(isbn);
    } on BookFailure catch (failure) {
      return IsbnScanResult.failure(message: failure.message);
    } on FirebaseException catch (error) {
      return IsbnScanResult.failure(message: _mapLookupError(error));
    } catch (_) {
      return const IsbnScanResult.failure(
        message: AppStrings.isbnScanLookupError,
      );
    }

    if (book != null) {
      return IsbnScanResult.found(isbn: isbn, book: book);
    }

    String? logError;
    try {
      await isbnLogRepository.record(isbn);
    } on IsbnLogFailure catch (failure) {
      logError = failure.message;
    } catch (_) {
      logError = AppStrings.isbnScanLogError;
    }

    return IsbnScanResult.notFound(
      isbn: isbn,
      message: AppStrings.isbnScanNotFoundMessage(isbn),
      logError: logError,
    );
  }

  static String _mapLookupError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.isbnScanLookupNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.isbnScanLookupPermissionDenied;
      default:
        return AppStrings.isbnScanLookupError;
    }
  }
}

/// Akses [IsbnScanService] bersama lewat Riverpod.
final Provider<IsbnScanService> isbnScanServiceProvider =
    Provider<IsbnScanService>(
      (Ref ref) => IsbnScanService(
        bookRepository: ref.watch(bookRepositoryProvider),
        isbnLogRepository: ref.watch(isbnLogRepositoryProvider),
      ),
    );
