import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'active_session.dart';
import 'session_notification_content.dart';

/// Kunci penyimpanan data sesi untuk isolate layanan latar belakang.
const String sessionTimerStorageKey = 'libria_reading_session_timer';

/// ID notifikasi layanan timer sesi membaca.
const int sessionTimerServiceId = 1001;

/// Selang pembaruan notifikasi timer dalam milidetik.
///
/// Timer tetap dihitung dari cap waktu, sehingga selang ini hanya menentukan
/// seberapa cepat waktu pada notifikasi diperbarui, bukan akurasi durasi.
const int sessionTimerEventIntervalMs = 1000;

/// Titik masuk task handler layanan latar belakang.
///
/// Fungsi ini harus berada di level atas dan ditandai `vm:entry-point` agar
/// dapat dijalankan di isolate layanan oleh `flutter_foreground_task`.
@pragma('vm:entry-point')
void sessionTimerTaskCallback() {
  FlutterForegroundTask.setTaskHandler(SessionTimerTaskHandler());
}

/// Task handler yang memperbarui notifikasi sesi membaca setiap selang
/// [sessionTimerEventIntervalMs].
///
/// Handler menerima data sesi terbaru dari isolate utama lewat
/// [FlutterForegroundTask.sendDataToTask] setiap kali status timer berubah,
/// lalu menghitung ulang durasi dari cap waktu. Dengan begitu notifikasi tetap
/// benar saat layar dimatikan dan isolate utama tidak aktif.
class SessionTimerTaskHandler extends TaskHandler {
  ActiveSession? _session;
  bool _isUpdating = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _session = await _readStoredSession();
    await _refreshNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_refreshNotification());
  }

  @override
  void onReceiveData(Object data) {
    final ActiveSession? session = decodeSessionPayload(data);
    if (session == null) {
      return;
    }
    _session = session;
    unawaited(_refreshNotification());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _session = null;
  }

  Future<void> _refreshNotification() async {
    final ActiveSession? session = _session;
    if (session == null || _isUpdating) {
      return;
    }

    _isUpdating = true;
    try {
      final SessionNotificationContent content =
          SessionNotificationContent.fromSession(session);
      await FlutterForegroundTask.updateService(
        notificationTitle: content.title,
        notificationText: content.text,
      );
    } catch (_) {
      // Layanan dapat berhenti tepat saat notifikasi diperbarui. Kesalahan ini
      // tidak boleh menghentikan siklus berikutnya.
    } finally {
      _isUpdating = false;
    }
  }

  Future<ActiveSession?> _readStoredSession() async {
    try {
      final String? payload = await FlutterForegroundTask.getData<String>(
        key: sessionTimerStorageKey,
      );
      return decodeSessionPayload(payload);
    } catch (_) {
      // Data akan dikirim ulang oleh isolate utama lewat `onReceiveData`.
      return null;
    }
  }
}

/// Membaca payload sesi dari JSON yang dikirim isolate utama.
///
/// Data yang rusak atau tidak lengkap diabaikan agar layanan tetap berjalan
/// dan menunggu payload berikutnya.
ActiveSession? decodeSessionPayload(Object? data) {
  if (data == null) {
    return null;
  }

  try {
    Object? decoded = data;
    if (decoded is String) {
      decoded = jsonDecode(decoded);
    }
    if (decoded is! Map) {
      return null;
    }

    final ActiveSession session = ActiveSession.fromMap(
      Map<String, dynamic>.from(decoded),
    );
    return session.isRestorable ? session : null;
  } catch (_) {
    return null;
  }
}
