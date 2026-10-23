import 'package:flutter_test/flutter_test.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/stats/data/reading_stats.dart';

void main() {
  ReadingSession session({
    required String id,
    DateTime? startedAt,
    DateTime? endedAt,
    int durationSeconds = 0,
    int startPage = 0,
    int endPage = 0,
  }) {
    return ReadingSession(
      id: id,
      bookId: 'book-$id',
      bookTitle: 'Buku $id',
      startedAt: startedAt,
      endedAt: endedAt ?? startedAt,
      durationSeconds: durationSeconds,
      targetSeconds: 1800,
      startPage: startPage,
      endPage: endPage,
    );
  }

  LibraryEntry entry({required String bookId, required String status}) {
    return LibraryEntry(
      bookId: bookId,
      status: status,
      bookTitle: 'Buku $bookId',
      bookAuthor: 'Penulis $bookId',
      bookTotalPages: 100,
    );
  }

  group('totalMenit', () {
    test('menjumlahkan durasi dan membulatkan ke bawah', () {
      final int minutes = ReadingStatsCalculator.totalMinutes(<ReadingSession>[
        session(id: '1', durationSeconds: 90),
        session(id: '2', durationSeconds: 189),
        session(id: '3', durationSeconds: -60),
      ]);

      expect(minutes, 4);
    });

    test('menghitung sesi tanpa tanggal', () {
      final int minutes = ReadingStatsCalculator.totalMinutes(<ReadingSession>[
        session(id: 'tanpa-tanggal', durationSeconds: 600),
      ]);

      expect(minutes, 10);
    });
  });

  group('totalHalaman', () {
    test('menjumlahkan pertambahan halaman saja', () {
      final int pages = ReadingStatsCalculator.totalPages(<ReadingSession>[
        session(id: '1', startPage: 10, endPage: 25),
        session(id: '2', startPage: 0, endPage: 5),
        session(id: '3', startPage: 5, endPage: 5),
        session(id: '4', startPage: 40, endPage: 20),
      ]);

      expect(pages, 20);
    });
  });

  group('bukuSelesai', () {
    test('menghitung buku unik berstatus selesai', () {
      final int books = ReadingStatsCalculator.finishedBooks(<LibraryEntry>[
        entry(bookId: 'a', status: LibraryEntry.statusFinished),
        entry(bookId: 'b', status: LibraryEntry.statusReading),
        entry(bookId: 'c', status: LibraryEntry.statusWant),
        entry(bookId: 'a', status: LibraryEntry.statusFinished),
        entry(bookId: 'd', status: LibraryEntry.statusFinished),
      ]);

      expect(books, 2);
    });

    test('rak kosong menghasilkan nol', () {
      expect(ReadingStatsCalculator.finishedBooks(const <LibraryEntry>[]), 0);
    });
  });

  group('ringkasan', () {
    test('menggabungkan total, buku selesai, dan streak', () {
      final ReadingStats stats = ReadingStatsCalculator.summary(
        sessions: <ReadingSession>[
          session(
            id: '1',
            startedAt: DateTime(2026, 10, 22, 9),
            durationSeconds: 600,
            startPage: 0,
            endPage: 20,
          ),
          session(
            id: '2',
            startedAt: DateTime(2026, 10, 23, 20),
            durationSeconds: 1200,
            startPage: 20,
            endPage: 70,
          ),
        ],
        today: DateTime(2026, 10, 23),
        libraryEntries: <LibraryEntry>[
          entry(bookId: 'a', status: LibraryEntry.statusFinished),
          entry(bookId: 'b', status: LibraryEntry.statusReading),
        ],
      );

      expect(stats.totalMinutes, 30);
      expect(stats.totalPages, 70);
      expect(stats.finishedBooks, 1);
      expect(stats.currentStreak, 2);
      expect(stats.isEmpty, isFalse);
    });

    test('tanpa sesi dan rak kosong menghasilkan ringkasan nol', () {
      final ReadingStats stats = ReadingStatsCalculator.summary(
        sessions: const <ReadingSession>[],
        today: DateTime(2026, 10, 23),
      );

      expect(stats.isEmpty, isTrue);
      expect(stats.totalMinutes, 0);
      expect(stats.totalPages, 0);
      expect(stats.finishedBooks, 0);
      expect(stats.currentStreak, 0);
    });
  });

  group('streak', () {
    test('menghitung hari berturut-turut lintas bulan', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(
          id: '1',
          startedAt: DateTime(2026, 10, 31, 8),
          durationSeconds: 600,
        ),
        session(
          id: '2',
          startedAt: DateTime(2026, 11, 1, 8),
          durationSeconds: 600,
        ),
        session(
          id: '3',
          startedAt: DateTime(2026, 11, 2, 8),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 11, 2));

      expect(streak, 3);
    });

    test('beberapa sesi pada hari yang sama dihitung satu hari', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(
          id: '1',
          startedAt: DateTime(2026, 10, 21, 8),
          durationSeconds: 600,
        ),
        session(
          id: '2',
          startedAt: DateTime(2026, 10, 22, 8),
          durationSeconds: 600,
        ),
        session(
          id: '3',
          startedAt: DateTime(2026, 10, 22, 20),
          durationSeconds: 600,
        ),
        session(
          id: '4',
          startedAt: DateTime(2026, 10, 23, 8),
          durationSeconds: 600,
        ),
        session(
          id: '5',
          startedAt: DateTime(2026, 10, 23, 20),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 10, 23));

      expect(streak, 3);
    });

    test('hari kosong memutus streak', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(
          id: '1',
          startedAt: DateTime(2026, 10, 23, 8),
          durationSeconds: 600,
        ),
        session(
          id: '2',
          startedAt: DateTime(2026, 10, 21, 8),
          durationSeconds: 600,
        ),
        session(
          id: '3',
          startedAt: DateTime(2026, 10, 20, 8),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 10, 23));

      expect(streak, 1);
    });

    test('streak masih berjalan sampai kemarin bila hari ini kosong', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(
          id: '1',
          startedAt: DateTime(2026, 10, 21, 8),
          durationSeconds: 600,
        ),
        session(
          id: '2',
          startedAt: DateTime(2026, 10, 22, 8),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 10, 23));

      expect(streak, 2);
    });

    test('streak nol bila dua hari terakhir kosong', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(
          id: '1',
          startedAt: DateTime(2026, 10, 21, 8),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 10, 23));

      expect(streak, 0);
    });

    test('tanpa sesi menghasilkan streak nol', () {
      expect(
        ReadingStatsCalculator.currentStreak(
          const <ReadingSession>[],
          today: DateTime(2026, 10, 23),
        ),
        0,
      );
    });

    test('mengabaikan sesi tanpa tanggal dan durasi nol', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(id: 'tanpa-tanggal', durationSeconds: 600),
        session(
          id: 'durasi-nol',
          startedAt: DateTime(2026, 10, 23, 8),
          durationSeconds: 0,
        ),
        session(
          id: 'kemarin',
          startedAt: DateTime(2026, 10, 22, 8),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 10, 23));

      expect(streak, 1);
    });

    test('mengabaikan sesi pada masa depan', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(
          id: '1',
          startedAt: DateTime(2026, 10, 24, 8),
          durationSeconds: 600,
        ),
        session(
          id: '2',
          startedAt: DateTime(2026, 10, 25, 8),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 10, 23));

      expect(streak, 0);
    });

    test('memakai tanggal mulai untuk sesi yang melewati tengah malam', () {
      final int streak = ReadingStatsCalculator.currentStreak(<ReadingSession>[
        session(
          id: 'lintas-malam',
          startedAt: DateTime(2026, 10, 22, 23, 59),
          endedAt: DateTime(2026, 10, 23, 0, 30),
          durationSeconds: 1800,
        ),
        session(
          id: 'hari-ini',
          startedAt: DateTime(2026, 10, 23, 20),
          durationSeconds: 600,
        ),
      ], today: DateTime(2026, 10, 23));

      expect(streak, 2);
    });
  });

  group('menitPerHari', () {
    test('rentang 7 hari mengisi hari kosong dan mengabaikan luar rentang', () {
      final List<DailyReadingMinutes> result =
          ReadingStatsCalculator.minutesPerDay(
            <ReadingSession>[
              session(
                id: 'hari-ini',
                startedAt: DateTime(2026, 10, 23, 12),
                durationSeconds: 600,
              ),
              session(
                id: 'kemarin',
                startedAt: DateTime(2026, 10, 22, 9),
                durationSeconds: 1800,
              ),
              session(
                id: 'hari-pertama',
                startedAt: DateTime(2026, 10, 17, 8),
                durationSeconds: 90,
              ),
              session(
                id: 'di-luar-rentang',
                startedAt: DateTime(2026, 10, 16, 8),
                durationSeconds: 3600,
              ),
              session(id: 'tanpa-tanggal', durationSeconds: 600),
            ],
            endDay: DateTime(2026, 10, 23, 18),
            dayCount: 7,
          );

      expect(result, hasLength(7));
      expect(
        result.map((DailyReadingMinutes day) => day.date).toList(),
        <DateTime>[
          DateTime(2026, 10, 17),
          DateTime(2026, 10, 18),
          DateTime(2026, 10, 19),
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 21),
          DateTime(2026, 10, 22),
          DateTime(2026, 10, 23),
        ],
      );
      expect(
        result.map((DailyReadingMinutes day) => day.minutes).toList(),
        <int>[1, 0, 0, 0, 0, 30, 10],
      );
    });

    test('rentang 30 hari melintasi bulan dan memakai batas tanggal', () {
      final List<DailyReadingMinutes> result =
          ReadingStatsCalculator.minutesPerDay(
            <ReadingSession>[
              session(
                id: 'sebelum-rentang',
                startedAt: DateTime(2026, 9, 23, 23),
                durationSeconds: 3600,
              ),
              session(
                id: 'hari-pertama',
                startedAt: DateTime(2026, 9, 24),
                durationSeconds: 60,
              ),
              session(
                id: 'awal-oktober',
                startedAt: DateTime(2026, 10, 1, 8),
                durationSeconds: 600,
              ),
              session(
                id: 'hari-terakhir',
                startedAt: DateTime(2026, 10, 23, 23, 59),
                durationSeconds: 120,
              ),
              session(
                id: 'setelah-rentang',
                startedAt: DateTime(2026, 10, 24),
                durationSeconds: 3600,
              ),
            ],
            endDay: DateTime(2026, 10, 23),
            dayCount: 30,
          );

      expect(result, hasLength(30));
      expect(result.first.date, DateTime(2026, 9, 24));
      expect(result.last.date, DateTime(2026, 10, 23));
      expect(result[0].minutes, 1);
      expect(result[7].minutes, 10);
      expect(result.last.minutes, 2);
      expect(
        result.fold<int>(
          0,
          (int total, DailyReadingMinutes day) => total + day.minutes,
        ),
        13,
      );
    });

    test('menjumlahkan beberapa sesi dalam satu hari sebelum dibulatkan', () {
      final List<DailyReadingMinutes> result =
          ReadingStatsCalculator.minutesPerDay(
            <ReadingSession>[
              session(
                id: '1',
                startedAt: DateTime(2026, 10, 23, 8),
                durationSeconds: 59,
              ),
              session(
                id: '2',
                startedAt: DateTime(2026, 10, 23, 9),
                durationSeconds: 60,
              ),
              session(
                id: '3',
                startedAt: DateTime(2026, 10, 22, 9),
                durationSeconds: 120,
              ),
            ],
            endDay: DateTime(2026, 10, 23),
            dayCount: 2,
          );

      expect(
        result.map((DailyReadingMinutes day) => day.minutes).toList(),
        <int>[2, 1],
      );
    });

    test('rentang tidak positif menghasilkan daftar kosong', () {
      expect(
        ReadingStatsCalculator.minutesPerDay(
          const <ReadingSession>[],
          endDay: DateTime(2026, 10, 23),
          dayCount: 0,
        ),
        isEmpty,
      );
    });
  });
}
