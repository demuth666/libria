import 'session_timer_engine.dart';

/// Sesi membaca aktif yang disimpan di perangkat.
///
/// Sesi aktif menyimpan buku yang sedang dibaca dan [SessionTimerEngine] yang
/// menghitung durasi dari cap waktu. Bentuk ini dipakai agar sesi yang berjalan
/// dapat dipulihkan setelah aplikasi dimatikan sistem (FR-S9).
class ActiveSession {
  const ActiveSession({
    required this.bookId,
    required this.bookTitle,
    required this.timer,
  });

  /// Membuat sesi baru yang langsung berjalan dengan target [target].
  factory ActiveSession.start({
    required String bookId,
    required String bookTitle,
    required Duration target,
    DateTime Function()? clock,
  }) {
    return ActiveSession(
      bookId: bookId,
      bookTitle: bookTitle,
      timer: SessionTimerEngine.idle(target: target, clock: clock).start(),
    );
  }

  /// ID dokumen buku yang sedang dibaca.
  final String bookId;

  /// Judul buku untuk header timer (FR-S3).
  final String bookTitle;

  /// Mesin timer yang menyimpan cap waktu dan status sesi.
  final SessionTimerEngine timer;

  /// Apakah data ini layak dipulihkan sebagai sesi aktif.
  ///
  /// Data kosong, tanpa judul buku, atau tanpa waktu mulai dianggap rusak
  /// sehingga dibuang oleh repository, bukan ditampilkan sebagai sesi aktif.
  bool get isRestorable {
    return bookId.trim().isNotEmpty &&
        bookTitle.trim().isNotEmpty &&
        timer.startedAt != null &&
        timer.state != SessionTimerState.idle;
  }

  /// Salinan sesi dengan mesin timer yang sudah bertransisi.
  ActiveSession copyWithTimer(SessionTimerEngine timer) {
    return ActiveSession(bookId: bookId, bookTitle: bookTitle, timer: timer);
  }

  /// Bentuk map yang aman disimpan sebagai JSON di penyimpanan lokal.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'bookId': bookId,
      'bookTitle': bookTitle,
      'timer': timer.toMap(),
    };
  }

  /// Memulihkan sesi dari hasil [toMap].
  ///
  /// Nilai yang hilang atau rusak memakai nilai aman, lalu [isRestorable]
  /// menentukan apakah sesi masih bisa dipakai.
  factory ActiveSession.fromMap(
    Map<String, dynamic> map, {
    DateTime Function()? clock,
  }) {
    final Object? timer = map['timer'];
    return ActiveSession(
      bookId: map['bookId'] as String? ?? '',
      bookTitle: map['bookTitle'] as String? ?? '',
      timer: SessionTimerEngine.fromMap(
        timer is Map
            ? Map<String, dynamic>.from(timer)
            : const <String, dynamic>{},
        clock: clock,
      ),
    );
  }
}
