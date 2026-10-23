import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/home/data/home_repository.dart';
import 'package:libria/features/session/data/reading_session.dart';

void main() {
  final DateTime dayStart = DateTime(2026, 10, 23);
  final DateTime dayEnd = DateTime(2026, 10, 24);

  ReadingSession session({
    required String id,
    DateTime? startedAt,
    int durationSeconds = 0,
    int startPage = 0,
    int endPage = 0,
  }) {
    return ReadingSession(
      id: id,
      bookId: 'book-$id',
      bookTitle: 'Buku $id',
      startedAt: startedAt,
      endedAt: startedAt,
      durationSeconds: durationSeconds,
      targetSeconds: 1800,
      startPage: startPage,
      endPage: endPage,
    );
  }

  test('menjumlahkan menit dan halaman sesi pada hari yang sama', () {
    final HomeTodaySummary summary = HomeRepository.summarizeSessions(
      <ReadingSession>[
        session(
          id: '1',
          startedAt: DateTime(2026, 10, 23, 8),
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
      dayStart: dayStart,
      dayEnd: dayEnd,
    );

    expect(summary.minutes, 30);
    expect(summary.pages, 70);
  });

  test('mengabaikan sesi di luar hari dan sesi tanpa waktu mulai', () {
    final HomeTodaySummary summary = HomeRepository.summarizeSessions(
      <ReadingSession>[
        session(
          id: 'kemarin',
          startedAt: DateTime(2026, 10, 22, 23, 59),
          durationSeconds: 3600,
          endPage: 100,
        ),
        session(
          id: 'besok',
          startedAt: DateTime(2026, 10, 24),
          durationSeconds: 3600,
          endPage: 100,
        ),
        session(id: 'tanpa-waktu', durationSeconds: 3600, endPage: 100),
        session(
          id: 'hari-ini',
          startedAt: DateTime(2026, 10, 23, 12),
          durationSeconds: 119,
          startPage: 10,
          endPage: 12,
        ),
      ],
      dayStart: dayStart,
      dayEnd: dayEnd,
    );

    expect(summary.minutes, 1);
    expect(summary.pages, 2);
  });

  test('mengabaikan durasi negatif dan halaman yang mundur', () {
    final HomeTodaySummary summary = HomeRepository.summarizeSessions(
      <ReadingSession>[
        session(
          id: 'mundur',
          startedAt: DateTime(2026, 10, 23, 9),
          durationSeconds: -500,
          startPage: 80,
          endPage: 40,
        ),
        session(
          id: 'tetap',
          startedAt: DateTime(2026, 10, 23, 10),
          durationSeconds: 60,
          startPage: 40,
          endPage: 40,
        ),
      ],
      dayStart: dayStart,
      dayEnd: dayEnd,
    );

    expect(summary.minutes, 1);
    expect(summary.pages, 0);
  });

  test('memakai batas awal hari dan menolak tepat di awal hari berikutnya', () {
    final HomeTodaySummary summary = HomeRepository.summarizeSessions(
      <ReadingSession>[
        session(
          id: 'awal',
          startedAt: dayStart,
          durationSeconds: 60,
          endPage: 1,
        ),
        session(
          id: 'akhir',
          startedAt: dayEnd.subtract(const Duration(seconds: 1)),
          durationSeconds: 60,
          endPage: 2,
        ),
        session(
          id: 'batas-berikutnya',
          startedAt: dayEnd,
          durationSeconds: 60,
          endPage: 3,
        ),
      ],
      dayStart: dayStart,
      dayEnd: dayEnd,
    );

    expect(summary.minutes, 2);
    expect(summary.pages, 3);
  });
}
