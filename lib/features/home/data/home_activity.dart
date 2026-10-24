import '../../library/data/library_entry.dart';
import '../../session/data/reading_session.dart';

/// Target menit membaca harian yang ditampilkan pada kartu Beranda.
///
/// Nilai ini mengikuti desain Stitch "Libria - Beranda & Dasbor Membaca".
/// PRD belum mengatur target yang dapat diubah pengguna, sehingga nilainya
/// berupa konstanta aplikasi sampai ada pengaturan target tersendiri.
const int homeDailyTargetMinutes = 45;

/// Jumlah hari pada kartu statistik dan grafik Beranda.
const int homeActivityDayCount = 7;

/// Jumlah hari sesi yang dibaca untuk menghitung streak dan grafik.
///
/// Dua pekan dipakai agar perbandingan dengan pekan sebelumnya dan streak
/// tetap dapat dihitung tanpa query tanpa batas.
const int homeActivityLookbackDays = 14;

/// Batas jumlah sesi yang dimuat untuk kartu aktivitas Beranda.
const int homeActivitySessionLimit = 500;

/// Jumlah menit membaca pada satu hari kalender.
class HomeDailyMinutes {
  const HomeDailyMinutes({required this.date, required this.minutes});

  /// Tanggal lokal pada tengah malam.
  final DateTime date;

  /// Total menit membaca pada tanggal tersebut.
  final int minutes;
}

/// Ringkasan aktivitas membaca pekan ini untuk Beranda.
class HomeActivitySummary {
  const HomeActivitySummary({
    required this.finishedBooks,
    required this.finishedBooksDelta,
    required this.sessions,
    required this.minutes,
    required this.streak,
    required this.daily,
  });

  /// Jumlah buku yang selesai dibaca pada tujuh hari terakhir.
  final int finishedBooks;

  /// Selisih jumlah buku selesai dibanding tujuh hari sebelumnya.
  final int finishedBooksDelta;

  /// Jumlah sesi membaca pada tujuh hari terakhir.
  final int sessions;

  /// Total menit membaca pada tujuh hari terakhir.
  final int minutes;

  /// Jumlah hari membaca berturut-turut sampai hari ini atau kemarin.
  final int streak;

  /// Menit membaca per hari, dari hari paling lama ke hari ini.
  final List<HomeDailyMinutes> daily;

  /// Menit tertinggi pada grafik, atau nol bila belum ada sesi.
  int get highestMinutes {
    int highest = 0;
    for (final HomeDailyMinutes day in daily) {
      if (day.minutes > highest) {
        highest = day.minutes;
      }
    }
    return highest;
  }

  /// Target menit membaca selama tujuh hari.
  int get weeklyTargetMinutes => homeDailyTargetMinutes * homeActivityDayCount;

  /// Persentase menit membaca terhadap target pekan ini.
  int get targetPercent {
    final int target = weeklyTargetMinutes;
    if (target <= 0) {
      return 0;
    }
    return (minutes / target * 100).round();
  }

  /// Rata-rata jumlah sesi per hari.
  double get averageSessionsPerDay => sessions / homeActivityDayCount;

  /// `true` bila belum ada sesi, buku selesai, atau streak pekan ini.
  bool get isEmpty => sessions == 0 && finishedBooks == 0 && streak == 0;
}

/// Perhitungan aktivitas Beranda yang murni dan dapat diuji tanpa Firestore.
abstract final class HomeActivityCalculator {
  const HomeActivityCalculator._();

  /// Menyusun ringkasan tujuh hari terakhir sampai [today].
  ///
  /// Sesi dihitung berdasarkan tanggal mulai lokal, atau tanggal selesai bila
  /// waktu mulai kosong. Menit dibulatkan ke bawah per hari, sama seperti
  /// grafik Statistik. Buku dianggap selesai pekan ini bila `finishedAt`
  /// berada pada rentang tujuh hari terakhir.
  static HomeActivitySummary summarize({
    required Iterable<ReadingSession> sessions,
    required Iterable<LibraryEntry> libraryEntries,
    required DateTime today,
  }) {
    final DateTime todayDay = _dateOnly(today);
    final DateTime firstDay = _addDays(todayDay, -(homeActivityDayCount - 1));
    final DateTime previousFirstDay = _addDays(firstDay, -homeActivityDayCount);

    final Map<int, int> secondsByDay = <int, int>{};
    final Set<int> readingDays = <int>{};
    int sessionCount = 0;

    for (final ReadingSession session in sessions) {
      final DateTime? day = _sessionDay(session);
      if (day == null) {
        continue;
      }
      if (session.durationSeconds > 0) {
        readingDays.add(_dateKey(day));
      }
      if (day.isBefore(firstDay) || day.isAfter(todayDay)) {
        continue;
      }
      sessionCount++;
      if (session.durationSeconds > 0) {
        final int key = _dateKey(day);
        secondsByDay[key] = (secondsByDay[key] ?? 0) + session.durationSeconds;
      }
    }

    final List<HomeDailyMinutes> daily = List<HomeDailyMinutes>.generate(
      homeActivityDayCount,
      (int index) {
        final DateTime date = _addDays(firstDay, index);
        return HomeDailyMinutes(
          date: date,
          minutes: (secondsByDay[_dateKey(date)] ?? 0) ~/ 60,
        );
      },
      growable: false,
    );
    final int minutes = daily.fold<int>(
      0,
      (int value, HomeDailyMinutes day) => value + day.minutes,
    );

    final int finishedBooks = _finishedBooks(
      libraryEntries,
      firstDay: firstDay,
      endDay: todayDay,
    );
    final int previousFinishedBooks = _finishedBooks(
      libraryEntries,
      firstDay: previousFirstDay,
      endDay: _addDays(firstDay, -1),
    );

    return HomeActivitySummary(
      finishedBooks: finishedBooks,
      finishedBooksDelta: finishedBooks - previousFinishedBooks,
      sessions: sessionCount,
      minutes: minutes,
      streak: _streak(readingDays, todayDay),
      daily: daily,
    );
  }

  /// Jumlah buku unik yang selesai pada rentang tanggal inklusif.
  static int _finishedBooks(
    Iterable<LibraryEntry> entries, {
    required DateTime firstDay,
    required DateTime endDay,
  }) {
    final Set<String> bookIds = <String>{};
    for (final LibraryEntry entry in entries) {
      final DateTime? finishedAt = entry.finishedAt;
      if (entry.status != LibraryEntry.statusFinished || finishedAt == null) {
        continue;
      }
      final DateTime day = _dateOnly(finishedAt.toLocal());
      if (day.isBefore(firstDay) || day.isAfter(endDay)) {
        continue;
      }
      bookIds.add(entry.bookId);
    }
    return bookIds.length;
  }

  /// Jumlah hari membaca berturut-turut yang berakhir pada [today] atau
  /// kemarin.
  static int _streak(Set<int> readingDays, DateTime today) {
    if (readingDays.isEmpty) {
      return 0;
    }

    DateTime cursor = today;
    if (!readingDays.contains(_dateKey(cursor))) {
      cursor = _addDays(cursor, -1);
      if (!readingDays.contains(_dateKey(cursor))) {
        return 0;
      }
    }

    int streak = 0;
    while (readingDays.contains(_dateKey(cursor))) {
      streak++;
      cursor = _addDays(cursor, -1);
    }
    return streak;
  }

  static DateTime? _sessionDay(ReadingSession session) {
    final DateTime? value = session.startedAt ?? session.endedAt;
    if (value == null) {
      return null;
    }
    return _dateOnly(value.toLocal());
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _addDays(DateTime value, int days) {
    return DateTime(value.year, value.month, value.day + days);
  }

  static int _dateKey(DateTime value) {
    return value.year * 10000 + value.month * 100 + value.day;
  }
}
