import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/presentation/library_shelves.dart';

import 'support/fake_library_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('LibraryShelves', () {
    test('mengelompokkan entri sesuai status dan mempertahankan urutan', () {
      final LibraryEntry reading = fakeLibraryEntry(
        1,
        status: LibraryEntry.statusReading,
      );
      final LibraryEntry want = fakeLibraryEntry(
        2,
        status: LibraryEntry.statusWant,
      );
      final LibraryEntry finished = fakeLibraryEntry(
        3,
        status: LibraryEntry.statusFinished,
      );
      final LibraryEntry readingOlder = fakeLibraryEntry(
        4,
        status: LibraryEntry.statusReading,
      );

      final LibraryShelves shelves = LibraryShelves.fromEntries(<LibraryEntry>[
        reading,
        want,
        finished,
        readingOlder,
      ]);

      expect(shelves.entriesFor(LibrarySection.reading), <LibraryEntry>[
        reading,
        readingOlder,
      ]);
      expect(shelves.entriesFor(LibrarySection.want), <LibraryEntry>[want]);
      expect(shelves.entriesFor(LibrarySection.finished), <LibraryEntry>[
        finished,
      ]);
      expect(shelves.countFor(LibrarySection.reading), 2);
      expect(shelves.countFor(LibrarySection.want), 1);
      expect(shelves.countFor(LibrarySection.finished), 1);
      expect(shelves.total, 4);
      expect(shelves.isEmpty, isFalse);
    });

    test('mengabaikan status tak dikenal dari segmen dan hitungan', () {
      final LibraryShelves shelves = LibraryShelves.fromEntries(<LibraryEntry>[
        fakeLibraryEntry(1, status: LibraryEntry.statusReading),
        fakeLibraryEntry(2, status: 'paused'),
        fakeLibraryEntry(3, status: ''),
        fakeLibraryEntry(4, status: LibraryEntry.statusWant),
      ]);

      expect(shelves.total, 2);
      expect(shelves.countFor(LibrarySection.reading), 1);
      expect(shelves.countFor(LibrarySection.want), 1);
      expect(shelves.countFor(LibrarySection.finished), 0);
    });

    test('rak kosong menghasilkan seluruh segmen kosong', () {
      final LibraryShelves shelves = LibraryShelves.fromEntries(
        const <LibraryEntry>[],
      );

      expect(shelves.isEmpty, isTrue);
      expect(shelves.total, 0);
      for (final LibrarySection section in LibrarySection.values) {
        expect(shelves.entriesFor(section), isEmpty);
        expect(shelves.countFor(section), 0);
      }
    });
  });

  group('Progres baca', () {
    test('menghitung rasio dan persentase dari halaman terakhir', () {
      final LibraryEntry entry = fakeLibraryEntry(
        1,
        currentPage: 75,
        totalPages: 100,
      );

      expect(libraryProgressRatio(entry), 0.75);
      expect(libraryProgressPercent(entry), 75);
    });

    test('total halaman nol menghasilkan progres nol', () {
      final LibraryEntry entry = fakeLibraryEntry(
        1,
        currentPage: 12,
        totalPages: 0,
      );

      expect(libraryProgressRatio(entry), 0);
      expect(libraryProgressPercent(entry), 0);
    });

    test('halaman melewati total dibatasi ke seratus persen', () {
      final LibraryEntry entry = fakeLibraryEntry(
        1,
        currentPage: 150,
        totalPages: 100,
      );

      expect(libraryProgressRatio(entry), 1);
      expect(libraryProgressPercent(entry), 100);
    });

    test('halaman negatif dibatasi ke nol', () {
      final LibraryEntry entry = fakeLibraryEntry(
        1,
        currentPage: -5,
        totalPages: 100,
      );

      expect(libraryProgressRatio(entry), 0);
      expect(libraryProgressPercent(entry), 0);
    });
  });

  group('AppDateFormatter.date', () {
    test('memformat tanggal selesai dengan locale id_ID', () {
      expect(AppDateFormatter.date(DateTime(2026, 3, 12)), '12 Maret 2026');
    });
  });
}
