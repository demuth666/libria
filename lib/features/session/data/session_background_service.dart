import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import 'active_session.dart';
import 'session_notification_content.dart';
import 'session_timer_engine.dart';
import 'session_timer_task_handler.dart';

/// Layanan yang menjaga notifikasi timer sesi membaca tetap diperbarui di
/// latar belakang.
abstract interface class SessionBackgroundService {
  /// Menyelaraskan layanan latar belakang dengan [session] terbaru.
  ///
  /// Sesi berjalan, dijeda, atau yang sudah mencapai target menampilkan
  /// notifikasi berkelanjutan. Sesi kosong atau selesai menghentikan layanan.
  /// [requestNotificationPermission] diminta hanya saat sesi baru dimulai
  /// agar dialog izin Android 13 ke atas tidak muncul saat aplikasi dibuka.
  Future<void> sync(
    ActiveSession? session, {
    bool requestNotificationPermission = false,
  });
}

/// Jembatan ke `flutter_foreground_task` yang dapat diganti pada pengujian.
abstract interface class SessionBackgroundDriver {
  /// Meminta izin notifikasi bila belum diberikan.
  Future<bool> requestNotificationPermission();

  /// Apakah layanan sedang berjalan.
  Future<bool> isServiceRunning();

  /// Memulai layanan dengan isi notifikasi awal.
  Future<void> startService({required String title, required String text});

  /// Memperbarui isi notifikasi layanan yang sudah berjalan.
  Future<void> updateService({required String title, required String text});

  /// Menghentikan layanan bila sedang berjalan.
  Future<void> stopService();

  /// Menyimpan payload sesi agar dapat dibaca isolate layanan.
  Future<void> saveSessionPayload(String payload);

  /// Menghapus payload sesi dari penyimpanan layanan.
  Future<void> clearSessionPayload();

  /// Mengirim payload sesi terbaru ke task handler.
  Future<void> sendSessionPayloadToTask(String payload);
}

/// Implementasi [SessionBackgroundService] di atas `flutter_foreground_task`.
class ForegroundSessionBackgroundService implements SessionBackgroundService {
  ForegroundSessionBackgroundService({SessionBackgroundDriver? driver})
    : _driver = driver ?? const FlutterForegroundTaskDriver();

  final SessionBackgroundDriver _driver;

  /// Antrean agar perubahan status yang berurutan tidak saling menimpa di
  /// layanan, misalnya saat pemulihan sesi berjalan bersamaan dengan aksi
  /// jeda dari layar timer.
  Future<void> _pending = Future<void>.value();

  /// Menyiapkan opsi notifikasi dan task handler.
  ///
  /// Dipanggil sekali dari `main.dart` sebelum aplikasi berjalan.
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'libria_reading_session',
        channelName: AppStrings.sessionNotificationChannelName,
        channelDescription: AppStrings.sessionNotificationChannelDescription,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          sessionTimerEventIntervalMs,
        ),
        allowWakeLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  @override
  Future<void> sync(
    ActiveSession? session, {
    bool requestNotificationPermission = false,
  }) {
    final Completer<void> result = Completer<void>();
    _pending = _pending.then<void>((void _) async {
      try {
        await _syncNow(
          session,
          requestNotificationPermission: requestNotificationPermission,
        );
      } catch (_) {
        // Layanan latar belakang bersifat pelengkap dan tidak boleh membuat
        // antrean perubahan sesi berhenti.
      } finally {
        if (!result.isCompleted) {
          result.complete();
        }
      }
    });
    return result.future;
  }

  Future<void> _syncNow(
    ActiveSession? session, {
    required bool requestNotificationPermission,
  }) async {
    if (session == null || !_shouldKeepServiceRunning(session.timer.state)) {
      await _stopSafely();
      return;
    }

    if (requestNotificationPermission) {
      try {
        await _driver.requestNotificationPermission();
      } catch (_) {
        // Izin notifikasi bersifat pelengkap; timer tetap berjalan walaupun
        // pengguna menolak atau permintaan izin gagal.
      }
    }

    final String payload = jsonEncode(session.toMap());
    try {
      await _driver.saveSessionPayload(payload);
    } catch (_) {
      // Layanan tetap dicoba; payload juga dikirim langsung ke task handler.
    }

    final SessionNotificationContent content =
        SessionNotificationContent.fromSession(session);

    bool isRunning = false;
    try {
      isRunning = await _driver.isServiceRunning();
    } catch (_) {
      isRunning = false;
    }

    bool serviceAvailable = isRunning;
    try {
      if (isRunning) {
        await _driver.updateService(title: content.title, text: content.text);
      } else {
        await _driver.startService(title: content.title, text: content.text);
        serviceAvailable = true;
      }
    } catch (_) {
      // Kegagalan layanan tidak boleh membatalkan sesi yang sudah tersimpan.
      serviceAvailable = false;
    }

    if (!serviceAvailable) {
      return;
    }

    try {
      await _driver.sendSessionPayloadToTask(payload);
    } catch (_) {
      // Task handler juga membaca payload tersimpan saat layanan dimulai.
    }
  }

  Future<void> _stopSafely() async {
    try {
      await _driver.clearSessionPayload();
    } catch (_) {
      // Payload lama akan ditimpa saat sesi berikutnya dimulai.
    }
    try {
      await _driver.stopService();
    } catch (_) {
      // Layanan mungkin sudah berhenti lebih dulu.
    }
  }

  static bool _shouldKeepServiceRunning(SessionTimerState state) {
    return switch (state) {
      SessionTimerState.running ||
      SessionTimerState.paused ||
      SessionTimerState.targetReached => true,
      SessionTimerState.idle || SessionTimerState.finished => false,
    };
  }
}

/// Implementasi [SessionBackgroundDriver] yang memakai plugin asli.
class FlutterForegroundTaskDriver implements SessionBackgroundDriver {
  const FlutterForegroundTaskDriver();

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final NotificationPermission current =
          await FlutterForegroundTask.checkNotificationPermission();
      if (current == NotificationPermission.granted) {
        return true;
      }
      if (current == NotificationPermission.permanently_denied) {
        return false;
      }

      final NotificationPermission requested =
          await FlutterForegroundTask.requestNotificationPermission();
      return requested == NotificationPermission.granted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isServiceRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startService({
    required String title,
    required String text,
  }) async {
    final ServiceRequestResult result =
        await FlutterForegroundTask.startService(
          serviceId: sessionTimerServiceId,
          serviceTypes: const <ForegroundServiceTypes>[
            ForegroundServiceTypes.specialUse,
          ],
          notificationTitle: title,
          notificationText: text,
          notificationInitialRoute: AppRoutes.sessionRun,
          callback: sessionTimerTaskCallback,
        );

    if (result is ServiceRequestFailure) {
      // Bila layanan ternyata sudah berjalan karena balapan dengan aksi lain,
      // perbarui notifikasinya alih-alih melaporkan kegagalan.
      if (result.error is ServiceAlreadyStartedException) {
        await updateService(title: title, text: text);
        return;
      }
      throw result.error;
    }
  }

  @override
  Future<void> updateService({
    required String title,
    required String text,
  }) async {
    final ServiceRequestResult result =
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  }

  @override
  Future<void> stopService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      return;
    }
    final ServiceRequestResult result =
        await FlutterForegroundTask.stopService();
    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  }

  @override
  Future<void> saveSessionPayload(String payload) async {
    await FlutterForegroundTask.saveData(
      key: sessionTimerStorageKey,
      value: payload,
    );
  }

  @override
  Future<void> clearSessionPayload() async {
    await FlutterForegroundTask.removeData(key: sessionTimerStorageKey);
  }

  @override
  Future<void> sendSessionPayloadToTask(String payload) async {
    FlutterForegroundTask.sendDataToTask(payload);
  }
}

/// Layanan latar belakang timer sesi membaca untuk seluruh lapisan presentasi.
final Provider<SessionBackgroundService> sessionBackgroundServiceProvider =
    Provider<SessionBackgroundService>(
      (Ref ref) => ForegroundSessionBackgroundService(),
    );
