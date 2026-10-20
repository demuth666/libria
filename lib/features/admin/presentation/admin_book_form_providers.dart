import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/data/book.dart';
import '../../books/data/book_repository.dart';

/// Buku yang sedang diubah pada formulir `/admin/books/:id/edit`.
///
/// Bernilai `null` bila dokumen buku tidak ditemukan, sehingga layar dapat
/// membedakan keadaan "tidak ditemukan" dari galat pemuatan.
final adminBookByIdProvider = FutureProvider.autoDispose.family<Book?, String>((
  Ref ref,
  String id,
) {
  return ref.watch(bookRepositoryProvider).getById(id);
});
