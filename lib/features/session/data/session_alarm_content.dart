import '../../../core/constants/app_strings.dart';
import '../../../core/utils/duration_formatter.dart';
import 'active_session.dart';

/// Isi notifikasi alarm saat target sesi membaca tercapai.
///
/// Judul menandai bahwa target sudah tercapai, sedangkan isi menyebut buku dan
/// durasi target agar pengguna langsung tahu sesi mana yang berhenti.
class SessionAlarmContent {
  const SessionAlarmContent({required this.title, required this.body});

  /// Membentuk isi alarm dari [session].
  factory SessionAlarmContent.fromSession(ActiveSession session) {
    return SessionAlarmContent(
      title: AppStrings.sessionAlarmNotificationTitle,
      body: AppStrings.sessionAlarmNotificationBody(
        session.bookTitle,
        AppDurationFormatter.timer(session.timer.target),
      ),
    );
  }

  /// Judul notifikasi alarm.
  final String title;

  /// Isi notifikasi alarm.
  final String body;
}
