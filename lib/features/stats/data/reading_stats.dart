import '../../library/data/library_entry.dart';
import '../../session/data/reading_session.dart';

/// Ringkasan statistik membaca pengguna (FR-T1).
class ReadingStats {
  const ReadingStats({
    required this.totalMinutes,
    required this.totalPages,
    required this.finishedBooks,
    required this.currentStreak,
  });

  /// Total menit membaca dari seluruh sesi.
  final int totalMinutes;

  /// Total halaman yang bertambah dari seluruh sesi.
  final int totalPages;

  /// Jumlah buku unik yang berstatus selesai di rak pengguna.
  final int finishedBooks;

  /// Jumlah hari membaca berturut-turut sampai hari ini atau kemarin.
  final int currentStreak;

  /// Ringkasan nol untuk pengguna yang belum memiliki aktivitas membaca.
  static const ReadingStats empty = ReadingStats(
    totalMinutes: 0,
    totalPages: 0,
    finishedBooks: 0,
    currentStreak: 0,
  );

  bool get isEmpty =>
      totalMinutes == 0 &&
      totalPages == 0 &&
      finishedBooks == 0 &&
      currentStreak == 0;
}

/// Jumlah menit membaca pada satu hari kalender.
class DailyReadingMinutes {
  const DailyReadingMinutes({required this.date, required this.minutes});

  /// Tanggal lokal pada tengah malam.
  final DateTime date;

  /// Total menit membaca pada tanggal tersebut.
  final int minutes;
}

/// Perhitungan statistik membaca yang murni dan dapat diuji tanpa Firestore.
///
/// Aturan yang dipakai:
/// - Menit dihitung dengan pembulatan ke bawah dari total detik, sama seperti
///   ringkasan Beranda, agar angka tidak melebih-lebihkan waktu membaca.
/// - Halaman dihitung dari selisih halaman akhir dan awal setiap sesi;
///   selisih nol atau negatif diabaikan.
/// - Satu hari dianggap hari membaca bila memiliki sesi dengan durasi positif.
///   Tanggal mengikuti waktu mulai sesi dalam zona waktu perangkat; sesi tanpa
///   waktu mulai memakai waktu selesai.
/// - Streak adalah runtutan hari terakhir yang berakhir pada hari ini. Bila
///   belum ada sesi hari ini, runtutan masih boleh berakhir kemarin sehingga
///   streak belum dianggap putus sebelum hari berganti.
abstract final class ReadingStatsCalculator {
  const ReadingStatsCalculator._();

  /// Menyusun seluruh ringkasan statistik dalam satu panggilan.
  static ReadingStats summary({
    required Iterable<ReadingSession> sessions,
    required DateTime today,
    Iterable<LibraryEntry> libraryEntries = const <LibraryEntry>[],
  }) {
    final List<ReadingSession> sessionList = sessions.toList(growable: false);
    return ReadingStats(
      totalMinutes: totalMinutes(sessionList),
      totalPages: totalPages(sessionList),
      finishedBooks: finishedBooks(libraryEntries),
      currentStreak: currentStreak(sessionList, today: today),
    );
  }

  /// Jumlah menit dari seluruh sesi, dibulatkan ke bawah.
  ///
  /// Durasi negatif diabaikan. Sesi tanpa tanggal tetap dihitung karena total
  /// menit tidak bergantung pada hari.
  static int totalMinutes(Iterable<ReadingSession> sessions) {
    int seconds = 0;
    for (final ReadingSession session in sessions) {
      if (session.durationSeconds > 0) {
        seconds += session.durationSeconds;
      }
    }
    return seconds ~/ 60;
  }

  /// Jumlah halaman yang dibaca dari seluruh sesi.
  ///
  /// Hanya pertambahan halaman yang dihitung; sesi yang halamannya mundur atau
  /// tetap tidak menambah total.
  static int totalPages(Iterable<ReadingSession> sessions) {
    int pages = 0;
    for (final ReadingSession session in sessions) {
      final int delta = session.endPage - session.startPage;
      if (delta > 0) {
        pages += delta;
      }
    }
    return pages;
  }

  /// Jumlah buku unik yang berstatus selesai di rak pengguna.
  static int finishedBooks(Iterable<LibraryEntry> libraryEntries) {
    final Set<String> bookIds = <String>{};
    for (final LibraryEntry entry in libraryEntries) {
      if (entry.status == LibraryEntry.statusFinished) {
        bookIds.add(entry.bookId);
      }
    }
    return bookIds.length;
  }

  /// Jumlah hari membaca berturut-turut yang berakhir pada [today] atau
  /// kemarin.
  ///
  /// Beberapa sesi pada hari yang sama dihitung satu hari. Sesi tanpa tanggal
  /// dan sesi tanpa durasi positif tidak dianggap sebagai hari membaca.
  static int currentStreak(
    Iterable<ReadingSession> sessions, {
    required DateTime today,
  }) {
    final Set<int> readingDays = <int>{};
    for (final ReadingSession session in sessions) {
      if (session.durationSeconds <= 0) {
        continue;
      }
      final DateTime? day = _sessionDay(session);
      if (day != null) {
        readingDays.add(_dateKey(day));
      }
    }
    if (readingDays.isEmpty) {
      return 0;
    }

    DateTime cursor = _dateOnly(today);
    if (!readingDays.contains(_dateKey(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (!readingDays.contains(_dateKey(cursor))) {
        return 0;
      }
    }

    int streak = 0;
    while (readingDays.contains(_dateKey(cursor))) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  /// Menit membaca per hari untuk [dayCount] hari terakhir sampai [endDay].
  ///
  /// Hasil selalu berisi [dayCount] entri berurutan dari hari paling lama ke
  /// [endDay], termasuk hari tanpa sesi dengan nilai nol. Tanggal pada hasil
  /// berada pada tengah malam waktu lokal. Bila [dayCount] tidak positif,
  /// hasilnya kosong.
  static List<DailyReadingMinutes> minutesPerDay(
    Iterable<ReadingSession> sessions, {
    required DateTime endDay,
    required int dayCount,
  }) {
    if (dayCount <= 0) {
      return const <DailyReadingMinutes>[];
    }

    final DateTime lastDay = _dateOnly(endDay);
    final DateTime firstDay = DateTime(
      lastDay.year,
      lastDay.month,
      lastDay.day - dayCount + 1,
    );

    final Map<int, int> secondsByDay = <int, int>{};
    for (final ReadingSession session in sessions) {
      if (session.durationSeconds <= 0) {
        continue;
      }
      final DateTime? day = _sessionDay(session);
      if (day == null || day.isBefore(firstDay) || day.isAfter(lastDay)) {
        continue;
      }
      final int key = _dateKey(day);
      secondsByDay[key] = (secondsByDay[key] ?? 0) + session.durationSeconds;
    }

    return List<DailyReadingMinutes>.generate(dayCount, (int index) {
      final DateTime date = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day + index,
      );
      return DailyReadingMinutes(
        date: date,
        minutes: (secondsByDay[_dateKey(date)] ?? 0) ~/ 60,
      );
    }, growable: false);
  }

  /// Tanggal lokal sesi, atau `null` bila sesi tidak memiliki waktu.
  static DateTime? _sessionDay(ReadingSession session) {
    final DateTime? value = session.startedAt ?? session.endedAt;
    if (value == null) {
      return null;
    }
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static int _dateKey(DateTime value) {
    return value.year * 10000 + value.month * 100 + value.day;
  }
}
