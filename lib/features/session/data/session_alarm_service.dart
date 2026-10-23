import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:vibration/vibration.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import 'active_session.dart';
import 'session_alarm_content.dart';
import 'session_timer_engine.dart';

/// ID notifikasi alarm target sesi membaca.
const int sessionAlarmNotificationId = 1002;

/// Pola getar alarm dalam milidetik.
///
/// Nilai pertama adalah jeda sebelum getar pertama, lalu bergantian antara
/// getar dan jeda. Pola ini diputar satu kali agar alarm tidak bergetar terus
/// tanpa cara menghentikannya dari layar sesi (T-055).
const List<int> sessionAlarmVibrationPattern = <int>[
  0,
  800,
  350,
  800,
  350,
  1400,
];

/// Layanan alarm target sesi membaca.
///
/// Alarm terdiri dari dua lapis: jadwal notifikasi lokal tepat waktu sebagai
/// cadangan bila layanan latar belakang dihentikan sistem (FR-S5), dan getar
/// serta notifikasi langsung saat aplikasi masih hidup (FR-S6). Jadwal
/// dibatalkan ketika sesi dijeda, selesai, atau dihapus.
abstract interface class SessionAlarmService {
  /// Menyelaraskan alarm dengan [session] terbaru.
  ///
  /// Sesi berjalan menjadwalkan notifikasi pada waktu target. Sesi dijeda,
  /// selesai, atau kosong membatalkan jadwal. Sesi yang sudah mencapai target
  /// membatalkan jadwal dan, bila [announceTargetReached] benar, memicu getar
  /// alarm serta notifikasi. [requestPermissions] diminta hanya saat sesi baru
  /// dimulai agar dialog izin tidak muncul setiap kali aplikasi dibuka.
  /// [onTargetReached] dipanggil dari isolate utama tepat setelah target
  /// tercapai agar pengendali sesi dapat menghentikan timer dan menyimpan
  /// status terbaru.
  Future<void> sync(
    ActiveSession? session, {
    bool requestPermissions = false,
    bool announceTargetReached = false,
    void Function()? onTargetReached,
  });

  /// Membatalkan jadwal alarm tanpa menunggu perubahan sesi.
  Future<void> cancel();
}

/// Jembatan ke `flutter_local_notifications` dan `vibration`.
///
/// Dipisahkan agar dapat diganti pada pengujian tanpa menyentuh platform
/// Android.
abstract interface class SessionAlarmDriver {
  /// Menyiapkan plugin, zona waktu, dan kanal notifikasi.
  Future<void> initialize();

  /// Meminta izin notifikasi Android 13 ke atas.
  Future<bool> requestNotificationPermission();

  /// Meminta izin alarm tepat Android 12 ke atas.
  Future<bool> requestExactAlarmPermission();

  /// Apakah perangkat mengizinkan alarm tepat saat ini.
  Future<bool> canScheduleExactAlarms();

  /// Menjadwalkan notifikasi alarm pada [at].
  Future<void> schedule({
    required DateTime at,
    required bool exact,
    required String title,
    required String body,
  });

  /// Menampilkan notifikasi alarm sekarang.
  Future<void> showNow({required String title, required String body});

  /// Membatalkan notifikasi alarm yang sudah dijadwalkan atau tampil.
  Future<void> cancelScheduled();

  /// Memutar pola getar alarm satu kali.
  Future<void> vibrateAlarm();
}

/// Implementasi [SessionAlarmService] di atas plugin notifikasi dan getar.
class LocalSessionAlarmService implements SessionAlarmService {
  LocalSessionAlarmService({
    SessionAlarmDriver? driver,
    DateTime Function()? clock,
  }) : _driver = driver ?? FlutterSessionAlarmDriver(),
       _clock = clock ?? DateTime.now;

  final SessionAlarmDriver _driver;
  final DateTime Function() _clock;

  /// Antrean agar jadwal dan pembatalan yang berurutan tidak saling menimpa.
  Future<void> _pending = Future<void>.value();

  bool _initialized = false;
  String? _announcedTargetKey;
  Timer? _targetTimer;
  void Function()? _onTargetReached;

  @override
  Future<void> sync(
    ActiveSession? session, {
    bool requestPermissions = false,
    bool announceTargetReached = false,
    void Function()? onTargetReached,
  }) {
    final Completer<void> result = Completer<void>();
    _pending = _pending.then<void>((void _) async {
      try {
        await _syncNow(
          session,
          requestPermissions: requestPermissions,
          announceTargetReached: announceTargetReached,
          onTargetReached: onTargetReached,
        );
      } catch (_) {
        // Alarm bersifat pelengkap. Kegagalan plugin tidak boleh membatalkan
        // sesi atau membuat transisi timer gagal.
      } finally {
        if (!result.isCompleted) {
          result.complete();
        }
      }
    });
    return result.future;
  }

  @override
  Future<void> cancel() {
    final Completer<void> result = Completer<void>();
    _pending = _pending.then<void>((void _) async {
      try {
        await _ensureInitialized();
        _cancelTargetTimer();
        await _driver.cancelScheduled();
        _announcedTargetKey = null;
      } catch (_) {
        // Pembatalan bersifat pelengkap.
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
    required bool requestPermissions,
    required bool announceTargetReached,
    required void Function()? onTargetReached,
  }) async {
    await _ensureInitialized();

    if (session == null) {
      _cancelTargetTimer();
      await _cancelScheduledSafely();
      _announcedTargetKey = null;
      return;
    }

    if (requestPermissions) {
      await _ignoreFailure(_driver.requestNotificationPermission);
      await _ignoreFailure(_driver.requestExactAlarmPermission);
    }

    switch (session.timer.state) {
      case SessionTimerState.running:
        _scheduleTargetTimer(session, onTargetReached);
        await _scheduleForTarget(session);
      case SessionTimerState.paused:
        _cancelTargetTimer();
        await _cancelScheduledSafely();
      case SessionTimerState.targetReached:
        _cancelTargetTimer();
        await _cancelScheduledSafely();
        if (announceTargetReached) {
          await _announceTargetReached(session);
        }
      case SessionTimerState.finished:
        _cancelTargetTimer();
        await _cancelScheduledSafely();
        _announcedTargetKey = null;
      case SessionTimerState.idle:
        _cancelTargetTimer();
        await _cancelScheduledSafely();
    }
  }

  void _scheduleTargetTimer(
    ActiveSession session,
    void Function()? onTargetReached,
  ) {
    _cancelTargetTimer();
    if (onTargetReached == null) {
      return;
    }

    final Duration remaining = session.timer.target - session.timer.elapsed;
    final Duration delay = remaining <= Duration.zero
        ? Duration.zero
        : remaining + const Duration(milliseconds: 50);
    _onTargetReached = onTargetReached;
    _targetTimer = Timer(delay, () {
      _targetTimer = null;
      _onTargetReached?.call();
    });
  }

  void _cancelTargetTimer() {
    _targetTimer?.cancel();
    _targetTimer = null;
    _onTargetReached = null;
  }

  Future<void> _scheduleForTarget(ActiveSession session) async {
    final Duration remaining = session.timer.target - session.timer.elapsed;
    if (session.timer.target <= Duration.zero || remaining <= Duration.zero) {
      return;
    }

    final SessionAlarmContent content = SessionAlarmContent.fromSession(
      session,
    );
    final bool exact = await _canScheduleExactAlarms();
    await _driver.schedule(
      at: _clock().add(remaining),
      exact: exact,
      title: content.title,
      body: content.body,
    );
  }

  Future<void> _announceTargetReached(ActiveSession session) async {
    final String key = _sessionKey(session);
    if (_announcedTargetKey == key) {
      return;
    }
    // Tandai lebih dulu agar pemanggilan sync berikutnya tidak memicu getar
    // kedua walaupun plugin selesai secara asinkron.
    _announcedTargetKey = key;

    final SessionAlarmContent content = SessionAlarmContent.fromSession(
      session,
    );
    await _ignoreVoidFailure(_driver.vibrateAlarm);
    await _driver.showNow(title: content.title, body: content.body);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await _driver.initialize();
    _initialized = true;
  }

  Future<bool> _canScheduleExactAlarms() async {
    try {
      return await _driver.canScheduleExactAlarms();
    } catch (_) {
      return false;
    }
  }

  Future<void> _ignoreFailure(Future<bool> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Izin dan getar bersifat pelengkap.
    }
  }

  Future<void> _ignoreVoidFailure(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Getar bersifat pelengkap; notifikasi tetap ditampilkan.
    }
  }

  Future<void> _cancelScheduledSafely() async {
    try {
      await _driver.cancelScheduled();
    } catch (_) {
      // Jadwal lama akan ditimpa saat sesi berikutnya berjalan.
    }
  }

  static String _sessionKey(ActiveSession session) {
    final int? startedAt = session.timer.startedAt?.millisecondsSinceEpoch;
    return '${session.bookId}|$startedAt|${session.timer.target.inSeconds}';
  }
}

/// Implementasi [SessionAlarmDriver] yang memakai plugin asli.
class FlutterSessionAlarmDriver implements SessionAlarmDriver {
  FlutterSessionAlarmDriver({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'libria_session_alarm';

  static final NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      AppStrings.sessionAlarmChannelName,
      channelDescription: AppStrings.sessionAlarmChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      onlyAlertOnce: true,
      vibrationPattern: Int64List.fromList(sessionAlarmVibrationPattern),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
  );

  @override
  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final bool? granted = await _android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    try {
      final bool? canSchedule = await _android?.canScheduleExactNotifications();
      if (canSchedule ?? false) {
        return true;
      }
      return await _android?.requestExactAlarmsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> schedule({
    required DateTime at,
    required bool exact,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id: sessionAlarmNotificationId,
      scheduledDate: timezone.TZDateTime.from(at, timezone.UTC),
      notificationDetails: _notificationDetails,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: AppRoutes.sessionRun,
    );
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    await _plugin.show(
      id: sessionAlarmNotificationId,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
      payload: AppRoutes.sessionRun,
    );
  }

  @override
  Future<void> cancelScheduled() async {
    await _plugin.cancel(id: sessionAlarmNotificationId);
  }

  @override
  Future<void> vibrateAlarm() async {
    try {
      if (!await Vibration.hasVibrator()) {
        return;
      }
      await Vibration.vibrate(pattern: sessionAlarmVibrationPattern);
    } catch (_) {
      // Notifikasi alarm tetap tampil walaupun perangkat tidak bisa bergetar.
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
}

/// Akses layanan alarm target sesi untuk seluruh lapisan presentasi.
final Provider<SessionAlarmService> sessionAlarmServiceProvider =
    Provider<SessionAlarmService>((Ref ref) => LocalSessionAlarmService());
