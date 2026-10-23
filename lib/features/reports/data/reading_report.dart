import '../../library/data/library_entry.dart';
import '../../session/data/reading_session.dart';

/// Ringkasan satu buku pada laporan membaca (FR-P2).
class ReadingReportBook {
  const ReadingReportBook({
    required this.bookId,
    required this.title,
    required this.author,
    required this.sessionCount,
    required this.minutes,
    required this.pages,
    required this.finished,
  });

  final String bookId;
  final String title;
  final String author;

  /// Jumlah sesi buku ini yang jatuh pada rentang laporan.
  final int sessionCount;

  /// Total menit membaca buku ini, dibulatkan ke bawah.
  final int minutes;

  /// Total halaman yang bertambah dari sesi buku ini.
  final int pages;

  /// `true` bila buku sudah berstatus selesai di rak pengguna.
  final bool finished;
}

/// Ringkasan aktivitas membaca pada satu tanggal.
class ReadingReportDay {
  const ReadingReportDay({
    required this.date,
    required this.sessionCount,
    required this.minutes,
    required this.pages,
  });

  /// Tanggal lokal pada tengah malam.
  final DateTime date;

  final int sessionCount;
  final int minutes;
  final int pages;
}

/// Data laporan membaca yang siap digambar menjadi dokumen PDF.
///
/// [ReadingReport.fromSessions] menyaring sesi berdasarkan tanggal lokal,
/// menggabungkan sesi per buku dan per hari, lalu menandai buku yang sudah
/// selesai berdasarkan entri rak pengguna. Sesi tanpa tanggal tidak dapat
/// ditempatkan pada rentang mana pun sehingga tidak dihitung.
class ReadingReport {
  const ReadingReport({
    required this.userName,
    required this.startDate,
    required this.endDate,
    required this.sessionCount,
    required this.totalMinutes,
    required this.totalPages,
    required this.finishedBookCount,
    required this.books,
    required this.days,
  });

  final String userName;

  /// Tanggal awal rentang (inklusif), sudah dinormalkan ke tengah malam.
  final DateTime startDate;

  /// Tanggal akhir rentang (inklusif), sudah dinormalkan ke tengah malam.
  final DateTime endDate;

  final int sessionCount;
  final int totalMinutes;
  final int totalPages;
  final int finishedBookCount;

  /// Buku yang dibaca pada rentang, diurutkan menurut judul.
  final List<ReadingReportBook> books;

  /// Hari yang memiliki sesi pada rentang, diurutkan dari paling lama.
  final List<ReadingReportDay> days;

  /// `true` bila tidak ada sesi maupun buku yang dapat dilaporkan.
  bool get isEmpty => sessionCount == 0 && books.isEmpty;

  /// Menyusun laporan dari sesi dan entri rak pengguna.
  ///
  /// [startDate] dan [endDate] bersifat inklusif dan hanya bagian tanggalnya
  /// yang dipakai. [endDate] tidak boleh mendahului [startDate].
  ///
  /// Aturan perhitungan mengikuti [ReadingStatsCalculator]: menit dibulatkan ke
  /// bawah dari total detik, halaman dihitung dari selisih positif, dan sesi
  /// tanpa durasi positif tetap dihitung sebagai sesi tetapi tidak menambah
  /// menit.
  factory ReadingReport.fromSessions({
    required String userName,
    required DateTime startDate,
    required DateTime endDate,
    required Iterable<ReadingSession> sessions,
    Iterable<LibraryEntry> libraryEntries = const <LibraryEntry>[],
  }) {
    final DateTime firstDay = _dateOnly(startDate);
    final DateTime lastDay = _dateOnly(endDate);
    if (lastDay.isBefore(firstDay)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'Tanggal akhir tidak boleh mendahului tanggal mulai.',
      );
    }

    final Map<String, LibraryEntry> entriesByBook = <String, LibraryEntry>{
      for (final LibraryEntry entry in libraryEntries) entry.bookId: entry,
    };
    final Map<String, _BookAggregate> bookAggregates =
        <String, _BookAggregate>{};
    final Map<int, _DayAggregate> dayAggregates = <int, _DayAggregate>{};
    int totalSeconds = 0;
    int totalPages = 0;
    int sessionCount = 0;

    for (final ReadingSession session in sessions) {
      final DateTime? day = _sessionDay(session);
      if (day == null || day.isBefore(firstDay) || day.isAfter(lastDay)) {
        continue;
      }

      sessionCount++;
      final int seconds = session.durationSeconds > 0
          ? session.durationSeconds
          : 0;
      final int pageDelta = session.endPage - session.startPage;
      final int pages = pageDelta > 0 ? pageDelta : 0;
      totalSeconds += seconds;
      totalPages += pages;

      final _BookAggregate book = bookAggregates.putIfAbsent(
        session.bookId,
        () => _BookAggregate(bookId: session.bookId, title: session.bookTitle),
      );
      if (book.title.isEmpty && session.bookTitle.isNotEmpty) {
        book.title = session.bookTitle;
      }
      book.sessionCount++;
      book.seconds += seconds;
      book.pages += pages;

      final _DayAggregate dayAggregate = dayAggregates.putIfAbsent(
        _dateKey(day),
        () => _DayAggregate(date: day),
      );
      dayAggregate.sessionCount++;
      dayAggregate.seconds += seconds;
      dayAggregate.pages += pages;
    }

    // Buku yang selesai pada rentang tetap dilaporkan walau sesinya dimulai
    // sebelum rentang atau tidak memiliki sesi pada rentang tersebut.
    for (final LibraryEntry entry in entriesByBook.values) {
      final DateTime? finishedAt = _localDate(entry.finishedAt);
      if (entry.status != LibraryEntry.statusFinished ||
          finishedAt == null ||
          finishedAt.isBefore(firstDay) ||
          finishedAt.isAfter(lastDay)) {
        continue;
      }
      final _BookAggregate book = bookAggregates.putIfAbsent(
        entry.bookId,
        () => _BookAggregate(bookId: entry.bookId, title: entry.bookTitle),
      );
      if (book.title.isEmpty) {
        book.title = entry.bookTitle;
      }
    }

    final List<ReadingReportBook> books =
        bookAggregates.values
            .map((_BookAggregate aggregate) {
              final LibraryEntry? entry = entriesByBook[aggregate.bookId];
              final String author = entry?.bookAuthor.trim() ?? '';
              return ReadingReportBook(
                bookId: aggregate.bookId,
                title: aggregate.title.trim(),
                author: author,
                sessionCount: aggregate.sessionCount,
                minutes: aggregate.seconds ~/ 60,
                pages: aggregate.pages,
                finished: _isFinished(entry, lastDay),
              );
            })
            .toList(growable: false)
          ..sort((ReadingReportBook a, ReadingReportBook b) {
            final int byTitle = a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            );
            if (byTitle != 0) {
              return byTitle;
            }
            return a.bookId.compareTo(b.bookId);
          });

    final List<ReadingReportDay> days =
        dayAggregates.values
            .map(
              (_DayAggregate aggregate) => ReadingReportDay(
                date: aggregate.date,
                sessionCount: aggregate.sessionCount,
                minutes: aggregate.seconds ~/ 60,
                pages: aggregate.pages,
              ),
            )
            .toList(growable: false)
          ..sort((ReadingReportDay a, ReadingReportDay b) {
            return a.date.compareTo(b.date);
          });

    return ReadingReport(
      userName: userName,
      startDate: firstDay,
      endDate: lastDay,
      sessionCount: sessionCount,
      totalMinutes: totalSeconds ~/ 60,
      totalPages: totalPages,
      finishedBookCount: books
          .where((ReadingReportBook book) => book.finished)
          .length,
      books: List<ReadingReportBook>.unmodifiable(books),
      days: List<ReadingReportDay>.unmodifiable(days),
    );
  }

  /// Buku dianggap selesai bila status rak sudah selesai dan tanggal selesainya
  /// tidak melewati akhir rentang. Entri lama tanpa `finishedAt` mengikuti
  /// statusnya.
  static bool _isFinished(LibraryEntry? entry, DateTime lastDay) {
    if (entry == null || entry.status != LibraryEntry.statusFinished) {
      return false;
    }
    final DateTime? finishedAt = _localDate(entry.finishedAt);
    if (finishedAt == null) {
      return true;
    }
    return !finishedAt.isAfter(lastDay);
  }

  static DateTime? _sessionDay(ReadingSession session) {
    return _localDate(session.startedAt ?? session.endedAt);
  }

  static DateTime? _localDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    final DateTime local = value.toLocal();
    return _dateOnly(local);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static int _dateKey(DateTime value) {
    return value.year * 10000 + value.month * 100 + value.day;
  }
}

class _BookAggregate {
  _BookAggregate({required this.bookId, required this.title});

  final String bookId;
  String title;
  int sessionCount = 0;
  int seconds = 0;
  int pages = 0;
}

class _DayAggregate {
  _DayAggregate({required this.date});

  final DateTime date;
  int sessionCount = 0;
  int seconds = 0;
  int pages = 0;
}
