import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/home/data/home_activity.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/reading_session.dart';

void main() {
  final DateTime today = DateTime(2026, 10, 24, 9);

  ReadingSession session({
    required int index,
    required DateTime startedAt,
    required int minutes,
    int pageDelta = 10,
  }) {
    return ReadingSession(
      id: 'session-$index',
      bookId: 'book-1',
      bookTitle: 'Bumi Manusia',
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(minutes: minutes)),
      durationSeconds: minutes * 60,
      targetSeconds: 30 * 60,
      startPage: 0,
      endPage: pageDelta,
      targetReached: true,
    );
  }

  LibraryEntry finishedBook({
    required int index,
    required DateTime finishedAt,
  }) {
    return LibraryEntry(
      bookId: 'book-$index',
      status: LibraryEntry.statusFinished,
      bookTitle: 'Buku $index',
      bookAuthor: 'Penulis $index',
      bookTotalPages: 100,
      finishedAt: finishedAt,
    );
  }

  test('meringkas menit, sesi, target, dan streak pekan ini', () {
    final HomeActivitySummary summary = HomeActivityCalculator.summarize(
      sessions: <ReadingSession>[
        session(index: 1, startedAt: DateTime(2026, 10, 24, 8), minutes: 45),
        session(index: 2, startedAt: DateTime(2026, 10, 23, 20), minutes: 30),
        session(index: 3, startedAt: DateTime(2026, 10, 22, 19), minutes: 15),
      ],
      libraryEntries: const <LibraryEntry>[],
      today: today,
    );

    expect(summary.sessions, 3);
    expect(summary.minutes, 90);
    expect(summary.streak, 3);
    expect(summary.daily.length, homeActivityDayCount);
    expect(summary.daily.last.minutes, 45);
    expect(summary.daily.first.date, DateTime(2026, 10, 18));
    expect(summary.highestMinutes, 45);
    expect(summary.averageSessionsPerDay, 3 / homeActivityDayCount);
    expect(summary.targetPercent, 29);
    expect(summary.finishedBooks, 0);
    expect(summary.finishedBooksDelta, 0);
  });

  test('menghitung buku selesai dan selisih pekan sebelumnya', () {
    final HomeActivitySummary summary = HomeActivityCalculator.summarize(
      sessions: const <ReadingSession>[],
      libraryEntries: <LibraryEntry>[
        finishedBook(index: 1, finishedAt: DateTime(2026, 10, 23)),
        finishedBook(index: 2, finishedAt: DateTime(2026, 10, 22)),
        finishedBook(index: 3, finishedAt: DateTime(2026, 10, 15)),
      ],
      today: today,
    );

    expect(summary.finishedBooks, 2);
    expect(summary.finishedBooksDelta, 1);
    expect(summary.isEmpty, isFalse);
  });

  test('streak masih berlanjut bila hari ini belum ada sesi', () {
    final HomeActivitySummary summary = HomeActivityCalculator.summarize(
      sessions: <ReadingSession>[
        session(index: 1, startedAt: DateTime(2026, 10, 23, 20), minutes: 30),
        session(index: 2, startedAt: DateTime(2026, 10, 22, 20), minutes: 20),
      ],
      libraryEntries: const <LibraryEntry>[],
      today: today,
    );

    expect(summary.streak, 2);
  });

  test('tanpa sesi menghasilkan ringkasan kosong dan tujuh hari nol', () {
    final HomeActivitySummary summary = HomeActivityCalculator.summarize(
      sessions: const <ReadingSession>[],
      libraryEntries: const <LibraryEntry>[],
      today: today,
    );

    expect(summary.sessions, 0);
    expect(summary.minutes, 0);
    expect(summary.streak, 0);
    expect(summary.highestMinutes, 0);
    expect(summary.targetPercent, 0);
    expect(
      summary.daily.every((HomeDailyMinutes day) => day.minutes == 0),
      true,
    );
    expect(summary.isEmpty, isTrue);
  });

  test('sesi di luar rentang tidak menambah menit atau sesi', () {
    final HomeActivitySummary summary = HomeActivityCalculator.summarize(
      sessions: <ReadingSession>[
        session(index: 1, startedAt: DateTime(2026, 10, 17, 10), minutes: 60),
        session(index: 2, startedAt: DateTime(2026, 10, 24, 8), minutes: 10),
      ],
      libraryEntries: const <LibraryEntry>[],
      today: today,
    );

    expect(summary.sessions, 1);
    expect(summary.minutes, 10);
  });

  test('format durasi mengikuti jam dan menit', () {
    expect(AppStrings.homeActivityDuration(0), '0m');
    expect(AppStrings.homeActivityDuration(45), '45m');
    expect(AppStrings.homeActivityDuration(60), '1j');
    expect(AppStrings.homeActivityDuration(755), '12j 35m');
  });
}
