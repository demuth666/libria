import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';

/// Membuat entri rak contoh untuk uji layar Koleksi.
LibraryEntry fakeLibraryEntry(
  int index, {
  String? title,
  String? author,
  String? status,
  int currentPage = 0,
  int totalPages = 100,
  DateTime? finishedAt,
  String? coverUrl,
}) {
  return LibraryEntry(
    bookId: 'book-$index',
    status: status ?? LibraryEntry.statusReading,
    currentPage: currentPage,
    bookTitle: title ?? 'Buku $index',
    bookAuthor: author ?? 'Penulis $index',
    bookCoverUrl: coverUrl,
    bookTotalPages: totalPages,
    addedAt: DateTime(2026, 1, index),
    finishedAt: finishedAt,
  );
}

/// Repository perpustakaan palsu tanpa Firestore atau Auth.
///
/// [watchLibraryFactory] dipakai bila uji perlu mengatur urutan stream untuk
/// percobaan ulang atau pemulihan koneksi. Bila tidak diisi, setiap pemanggilan
/// [watchLibrary] mengemit [entries] satu kali.
class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository({List<LibraryEntry>? entries})
    : entries = entries ?? <LibraryEntry>[];

  List<LibraryEntry> entries;
  int watchLibraryCalls = 0;
  Stream<List<LibraryEntry>> Function()? watchLibraryFactory;

  @override
  Stream<List<LibraryEntry>> watchLibrary() {
    watchLibraryCalls++;
    final Stream<List<LibraryEntry>> Function()? factory = watchLibraryFactory;
    if (factory != null) {
      return factory();
    }
    return Stream<List<LibraryEntry>>.value(
      List<LibraryEntry>.unmodifiable(entries),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
