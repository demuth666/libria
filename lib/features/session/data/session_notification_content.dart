import '../../../core/constants/app_strings.dart';
import '../../../core/utils/duration_formatter.dart';
import 'active_session.dart';
import 'session_timer_engine.dart';

/// Isi notifikasi layanan latar belakang untuk sesi membaca aktif.
///
/// Judul memakai judul buku agar pengguna langsung mengetahui buku yang
/// sedang dibaca, sedangkan teks memuat status dan waktu berjalan. Nilai
/// dihitung ulang dari cap waktu mesin timer, bukan dari penghitung detik,
/// sehingga tetap benar walaupun notifikasi diperbarui terlambat.
class SessionNotificationContent {
  const SessionNotificationContent({required this.title, required this.text});

  /// Membentuk isi notifikasi dari [session] pada saat ini.
  factory SessionNotificationContent.fromSession(ActiveSession session) {
    final SessionTimerEngine timer = session.timer;
    final String elapsed = AppDurationFormatter.timer(timer.elapsed);

    final String text = switch (timer.state) {
      SessionTimerState.idle => AppStrings.sessionNotificationIdle,
      SessionTimerState.running => _progress(
        AppStrings.sessionNotificationRunning,
        elapsed,
        timer.target,
      ),
      SessionTimerState.paused => _progress(
        AppStrings.sessionNotificationPaused,
        elapsed,
        timer.target,
      ),
      SessionTimerState.targetReached => AppStrings.sessionNotificationElapsed(
        AppStrings.sessionNotificationTargetReached,
        elapsed,
      ),
      SessionTimerState.finished => AppStrings.sessionNotificationElapsed(
        AppStrings.sessionNotificationFinished,
        elapsed,
      ),
    };

    return SessionNotificationContent(title: session.bookTitle, text: text);
  }

  /// Judul notifikasi, yaitu judul buku yang sedang dibaca.
  final String title;

  /// Status dan waktu berjalan sesi.
  final String text;

  static String _progress(String status, String elapsed, Duration target) {
    if (target <= Duration.zero) {
      return AppStrings.sessionNotificationElapsed(status, elapsed);
    }
    return AppStrings.sessionNotificationProgress(
      status,
      elapsed,
      AppDurationFormatter.timer(target),
    );
  }
}
