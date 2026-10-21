import '../data/library_entry.dart';

/// Segmen rak pengguna pada layar Koleksi.
enum LibrarySection { reading, want, finished }

/// Rak pengguna yang sudah dikelompokkan per segmen.
///
/// Layar hanya membaca satu stream rak lalu menghitung kelompok, jumlah, dan
/// filter di memori. Status yang tidak dikenal diabaikan agar data lama atau
/// rusak tidak membuat seluruh layar gagal (T-041).
class LibraryShelves {
  LibraryShelves.fromEntries(Iterable<LibraryEntry> entries) {
    final List<LibraryEntry> reading = <LibraryEntry>[];
    final List<LibraryEntry> want = <LibraryEntry>[];
    final List<LibraryEntry> finished = <LibraryEntry>[];

    for (final LibraryEntry entry in entries) {
      switch (entry.status) {
        case LibraryEntry.statusReading:
          reading.add(entry);
          break;
        case LibraryEntry.statusWant:
          want.add(entry);
          break;
        case LibraryEntry.statusFinished:
          finished.add(entry);
          break;
        default:
          // Status tak dikenal tidak masuk segmen mana pun.
          break;
      }
    }

    _entries = <LibrarySection, List<LibraryEntry>>{
      LibrarySection.reading: List<LibraryEntry>.unmodifiable(reading),
      LibrarySection.want: List<LibraryEntry>.unmodifiable(want),
      LibrarySection.finished: List<LibraryEntry>.unmodifiable(finished),
    };
  }

  late final Map<LibrarySection, List<LibraryEntry>> _entries;

  /// Entri pada [section] dengan urutan yang sama seperti stream rak.
  List<LibraryEntry> entriesFor(LibrarySection section) {
    return _entries[section]!;
  }

  /// Jumlah entri berstatus [section].
  int countFor(LibrarySection section) => _entries[section]!.length;

  /// Jumlah seluruh entri dengan status yang dikenal.
  int get total => _entries.values.fold<int>(
    0,
    (int sum, List<LibraryEntry> entries) => sum + entries.length,
  );

  /// `true` bila tidak ada satu pun entri dengan status yang dikenal.
  bool get isEmpty => total == 0;
}

/// Rasio progres baca dalam rentang 0..1.
///
/// Total halaman nol atau negatif menghasilkan 0 agar tidak terjadi pembagian
/// dengan nol. Halaman yang melewati total dibatasi ke 1.
double libraryProgressRatio(LibraryEntry entry) {
  if (entry.bookTotalPages <= 0) {
    return 0;
  }
  return (entry.currentPage / entry.bookTotalPages).clamp(0.0, 1.0);
}

/// Persentase progres baca yang dibulatkan, dalam rentang 0..100.
int libraryProgressPercent(LibraryEntry entry) {
  return (libraryProgressRatio(entry) * 100).round();
}
