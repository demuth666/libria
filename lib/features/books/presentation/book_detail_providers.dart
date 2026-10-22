import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/connectivity_service.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../data/book.dart';
import '../data/book_repository.dart';

/// Jenis kegagalan pemuatan detail buku.
///
/// Layar memakai kode ini untuk membedakan buku yang memang tidak ada,
/// perangkat offline tanpa cache, dan galat umum yang bisa dicoba lagi.
enum BookDetailFailureCode { notFound, offline, load }

/// Galat detail buku dengan pesan ramah pengguna dalam bahasa Indonesia.
class BookDetailFailure implements Exception {
  const BookDetailFailure(this.message, {required this.code});

  final String message;
  final BookDetailFailureCode code;

  bool get isNotFound => code == BookDetailFailureCode.notFound;

  bool get isOffline => code == BookDetailFailureCode.offline;

  @override
  String toString() => message;
}

/// Buku untuk layar detail pada rute `/book/:id` (T-043a).
///
/// Semua akses data lewat [BookRepository]. Saat perangkat offline, pembacaan
/// memakai cache Firestore sehingga buku yang pernah dimuat tetap tampil.
/// Status koneksi di-watch; perubahannya memicu muat ulang, dan layar
/// mempertahankan data terakhir selama muat ulang lewat `skipLoadingOnReload`.
final bookDetailProvider = FutureProvider.autoDispose.family<Book, String>((
  Ref ref,
  String bookId,
) {
  return _loadBook(ref, bookId);
}, retry: (int retryCount, Object error) => null);

Future<Book> _loadBook(Ref ref, String bookId) async {
  final BookRepository repository = ref.watch(bookRepositoryProvider);
  final bool isOffline = ref.watch(connectivityProvider).value == false;

  try {
    final Book? book = await repository.getById(
      bookId,
      source: isOffline
          ? BookSearchSource.cacheOnly
          : BookSearchSource.serverAndCache,
    );
    if (book != null) {
      return book;
    }
    if (isOffline) {
      throw _offlineFailure();
    }
    throw _notFoundFailure();
  } on BookDetailFailure {
    rethrow;
  } on BookFailure catch (failure) {
    if (failure.code == BookFailureCode.notFound) {
      throw _notFoundFailure();
    }
    throw _loadFailure(isOffline: isOffline, message: failure.message);
  } catch (_) {
    throw _loadFailure(isOffline: isOffline);
  }
}

BookDetailFailure _notFoundFailure() {
  return const BookDetailFailure(
    AppStrings.bookDetailNotFoundMessage,
    code: BookDetailFailureCode.notFound,
  );
}

BookDetailFailure _offlineFailure() {
  return const BookDetailFailure(
    AppStrings.bookDetailOfflineMessage,
    code: BookDetailFailureCode.offline,
  );
}

BookDetailFailure _loadFailure({required bool isOffline, String? message}) {
  if (isOffline) {
    return _offlineFailure();
  }
  return BookDetailFailure(
    message ?? AppStrings.bookDetailLoadError,
    code: BookDetailFailureCode.load,
  );
}

/// Entri rak pengguna untuk satu buku, atau `null` bila belum ditambahkan.
///
/// Stream default Firestore membuat data cache tetap tampil saat offline dan
/// pembaruan dari aksi tulis langsung terlihat pada layar detail.
final libraryEntryProvider = StreamProvider.autoDispose
    .family<LibraryEntry?, String>((Ref ref, String bookId) {
      return ref.watch(libraryRepositoryProvider).watchEntry(bookId);
    }, retry: (int retryCount, Object error) => null);
