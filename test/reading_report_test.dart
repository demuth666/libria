import 'package:flutter_test/flutter_test.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/reports/data/reading_report.dart';
import 'package:libria/features/session/data/reading_session.dart';

void main() {
  ReadingSession session({
    required String id,
    required String bookId,
    required String bookTitle,
    DateTime? startedAt,
    DateTime? endedAt,
    bool dated = true,
    int durationSeconds = 600,
    int startPage = 0,
    int endPage = 10,
  }) {
    final DateTime? start = dated
        ? (startedAt ?? DateTime(2026, 10, 5, 9))
        : null;
    final DateTime? end = dated
        ? (endedAt ?? startedAt ?? DateTime(2026, 10, 5, 9, 30))
        : null;
    return ReadingSession(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      startedAt: start,
      endedAt: end,
      durationSeconds: durationSeconds,
      targetSeconds: 1800,
      startPage: startPage,
      endPage: endPage,
    );
  }

  LibraryEntry entry({
    required String bookId,
    required String bookTitle,
    String bookAuthor = 'Penulis',
    String status = LibraryEntry.statusReading,
    DateTime? finishedAt,
  }) {
    return LibraryEntry(
      bookId: bookId,
      status: status,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      bookTotalPages: 200,
      finishedAt: finishedAt,
    );
  }

  ReadingReport buildReport(
    Iterable<ReadingSession> sessions, {
    Iterable<LibraryEntry> libraryEntries = const <LibraryEntry>[],
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ReadingReport.fromSessions(
      userName: 'Ayu Lestari',
      startDate: startDate ?? DateTime(2026, 10, 1),
      endDate: endDate ?? DateTime(2026, 10, 31),
      sessions: sessions,
      libraryEntries: libraryEntries,
    );
  }

  group('Ringkasan laporan', () {
    test('menghasilkan laporan kosong bila belum ada sesi', () {
      final ReadingReport report = buildReport(const <ReadingSession>[]);

      expect(report.userName, 'Ayu Lestari');
      expect(report.sessionCount, 0);
      expect(report.totalMinutes, 0);
      expect(report.totalPages, 0);
      expect(report.finishedBookCount, 0);
      expect(report.books, isEmpty);
      expect(report.days, isEmpty);
      expect(report.isEmpty, isTrue);
      expect(report.startDate, DateTime(2026, 10, 1));
      expect(report.endDate, DateTime(2026, 10, 31));
    });

    test('menghitung satu sesi pada buku, hari, dan ringkasan', () {
      final ReadingReport report = buildReport(
        <ReadingSession>[
          session(
            id: 'sesi-1',
            bookId: 'buku-1',
            bookTitle: 'Bumi Manusia',
            startedAt: DateTime(2026, 10, 5, 9, 15),
            durationSeconds: 1500,
            startPage: 10,
            endPage: 24,
          ),
        ],
        libraryEntries: <LibraryEntry>[
          entry(
            bookId: 'buku-1',
            bookTitle: 'Bumi Manusia',
            bookAuthor: 'Pramoedya Ananta Toer',
          ),
        ],
      );

      expect(report.sessionCount, 1);
      expect(report.totalMinutes, 25);
      expect(report.totalPages, 14);
      expect(report.finishedBookCount, 0);
      expect(report.isEmpty, isFalse);

      expect(report.books, hasLength(1));
      final ReadingReportBook book = report.books.single;
      expect(book.bookId, 'buku-1');
      expect(book.title, 'Bumi Manusia');
      expect(book.author, 'Pramoedya Ananta Toer');
      expect(book.sessionCount, 1);
      expect(book.minutes, 25);
      expect(book.pages, 14);
      expect(book.finished, isFalse);

      expect(report.days, hasLength(1));
      final ReadingReportDay day = report.days.single;
      expect(day.date, DateTime(2026, 10, 5));
      expect(day.sessionCount, 1);
      expect(day.minutes, 25);
      expect(day.pages, 14);
    });

    test('menggabungkan banyak sesi per buku dan per hari', () {
      final ReadingReport report = buildReport(<ReadingSession>[
        session(
          id: 'zaman-1',
          bookId: 'buku-zaman',
          bookTitle: 'Zaman',
          startedAt: DateTime(2026, 10, 2, 8),
          durationSeconds: 600,
          startPage: 0,
          endPage: 10,
        ),
        session(
          id: 'zaman-2',
          bookId: 'buku-zaman',
          bookTitle: 'Zaman',
          startedAt: DateTime(2026, 10, 2, 19),
          durationSeconds: 900,
          startPage: 10,
          endPage: 25,
        ),
        session(
          id: 'awan-1',
          bookId: 'buku-awan',
          bookTitle: 'Awan',
          startedAt: DateTime(2026, 10, 3, 7),
          durationSeconds: 600,
          startPage: 5,
          endPage: 12,
        ),
      ]);

      expect(report.sessionCount, 3);
      expect(report.totalMinutes, 35);
      expect(report.totalPages, 32);

      expect(report.books.map((ReadingReportBook book) => book.title), <String>[
        'Awan',
        'Zaman',
      ]);
      final ReadingReportBook awan = report.books.first;
      expect(awan.sessionCount, 1);
      expect(awan.minutes, 10);
      expect(awan.pages, 7);
      final ReadingReportBook zaman = report.books.last;
      expect(zaman.sessionCount, 2);
      expect(zaman.minutes, 25);
      expect(zaman.pages, 25);

      expect(report.days.map((ReadingReportDay day) => day.date), <DateTime>[
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
      ]);
      expect(report.days.first.sessionCount, 2);
      expect(report.days.first.minutes, 25);
      expect(report.days.first.pages, 25);
      expect(report.days.last.sessionCount, 1);
      expect(report.days.last.minutes, 10);
      expect(report.days.last.pages, 7);
    });

    test('menyaring sesi berdasarkan tanggal lokal secara inklusif', () {
      final ReadingReport report = buildReport(<ReadingSession>[
        session(
          id: 'sebelum',
          bookId: 'buku-1',
          bookTitle: 'Sebelum',
          startedAt: DateTime(2026, 9, 30, 23, 59),
          durationSeconds: 60,
        ),
        session(
          id: 'awal',
          bookId: 'buku-2',
          bookTitle: 'Awal',
          startedAt: DateTime(2026, 10, 1),
          durationSeconds: 60,
        ),
        session(
          id: 'akhir',
          bookId: 'buku-3',
          bookTitle: 'Akhir',
          startedAt: DateTime(2026, 10, 31, 23, 59),
          durationSeconds: 60,
        ),
        session(
          id: 'sesudah',
          bookId: 'buku-4',
          bookTitle: 'Sesudah',
          startedAt: DateTime(2026, 11, 1),
          durationSeconds: 60,
        ),
      ]);

      expect(report.sessionCount, 2);
      expect(report.totalMinutes, 2);
      expect(report.books.map((ReadingReportBook book) => book.title), <String>[
        'Akhir',
        'Awal',
      ]);
      expect(report.days, hasLength(2));
    });

    test('mengabaikan sesi tanpa tanggal', () {
      final ReadingReport report = buildReport(<ReadingSession>[
        session(
          id: 'tanpa-tanggal',
          bookId: 'buku-1',
          bookTitle: 'Tanpa Tanggal',
          dated: false,
          durationSeconds: 600,
        ),
      ]);

      expect(report.sessionCount, 0);
      expect(report.totalMinutes, 0);
      expect(report.books, isEmpty);
      expect(report.days, isEmpty);
    });

    test('tidak menambah menit atau halaman dari nilai negatif', () {
      final ReadingReport report = buildReport(<ReadingSession>[
        session(
          id: 'negatif',
          bookId: 'buku-1',
          bookTitle: 'Mundur',
          durationSeconds: -120,
          startPage: 50,
          endPage: 20,
        ),
      ]);

      expect(report.sessionCount, 1);
      expect(report.totalMinutes, 0);
      expect(report.totalPages, 0);
      expect(report.books.single.minutes, 0);
      expect(report.books.single.pages, 0);
      expect(report.days.single.minutes, 0);
      expect(report.days.single.pages, 0);
    });

    test('menormalkan tanggal rentang ke tengah malam', () {
      final ReadingReport report = buildReport(
        const <ReadingSession>[],
        startDate: DateTime(2026, 10, 1, 15, 30),
        endDate: DateTime(2026, 10, 31, 22, 45),
      );

      expect(report.startDate, DateTime(2026, 10, 1));
      expect(report.endDate, DateTime(2026, 10, 31));
    });

    test('menolak rentang yang tanggal akhirnya lebih awal', () {
      expect(
        () => buildReport(
          const <ReadingSession>[],
          startDate: DateTime(2026, 10, 31),
          endDate: DateTime(2026, 10, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Buku selesai', () {
    test('menandai buku selesai dari entri rak', () {
      final ReadingReport report = buildReport(
        <ReadingSession>[
          session(id: 'sesi-1', bookId: 'buku-1', bookTitle: 'Buku Selesai'),
        ],
        libraryEntries: <LibraryEntry>[
          entry(
            bookId: 'buku-1',
            bookTitle: 'Buku Selesai',
            status: LibraryEntry.statusFinished,
            finishedAt: DateTime(2026, 10, 20),
          ),
        ],
      );

      expect(report.finishedBookCount, 1);
      expect(report.books.single.finished, isTrue);
    });

    test('menyertakan buku yang selesai pada rentang tanpa sesi', () {
      final ReadingReport report = buildReport(
        const <ReadingSession>[],
        libraryEntries: <LibraryEntry>[
          entry(
            bookId: 'buku-selesai',
            bookTitle: 'Selesai Tanpa Sesi',
            bookAuthor: 'Nama Penulis',
            status: LibraryEntry.statusFinished,
            finishedAt: DateTime(2026, 10, 12),
          ),
        ],
      );

      expect(report.sessionCount, 0);
      expect(report.finishedBookCount, 1);
      expect(report.books, hasLength(1));
      final ReadingReportBook book = report.books.single;
      expect(book.title, 'Selesai Tanpa Sesi');
      expect(book.author, 'Nama Penulis');
      expect(book.sessionCount, 0);
      expect(book.minutes, 0);
      expect(book.pages, 0);
      expect(book.finished, isTrue);
      expect(report.isEmpty, isFalse);
    });

    test('tidak menandai selesai bila tanggal selesai melewati rentang', () {
      final ReadingReport report = buildReport(
        <ReadingSession>[
          session(
            id: 'sesi-1',
            bookId: 'buku-1',
            bookTitle: 'Belum Selesai Saat Itu',
          ),
        ],
        libraryEntries: <LibraryEntry>[
          entry(
            bookId: 'buku-1',
            bookTitle: 'Belum Selesai Saat Itu',
            status: LibraryEntry.statusFinished,
            finishedAt: DateTime(2026, 11, 5),
          ),
        ],
      );

      expect(report.finishedBookCount, 0);
      expect(report.books.single.finished, isFalse);
    });

    test('mengikuti status selesai lama tanpa tanggal selesai', () {
      final ReadingReport report = buildReport(
        <ReadingSession>[
          session(id: 'sesi-1', bookId: 'buku-1', bookTitle: 'Entri Lama'),
        ],
        libraryEntries: <LibraryEntry>[
          entry(
            bookId: 'buku-1',
            bookTitle: 'Entri Lama',
            status: LibraryEntry.statusFinished,
          ),
        ],
      );

      expect(report.books.single.finished, isTrue);
      expect(report.finishedBookCount, 1);
    });
  });
}
