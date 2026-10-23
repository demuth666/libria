import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/session_alarm_content.dart';
import 'package:libria/features/session/data/session_alarm_service.dart';

void main() {
  group('SessionAlarmContent', () {
    test('memuat judul buku dan durasi target', () {
      final ActiveSession session = ActiveSession.start(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        target: const Duration(minutes: 25),
        clock: () => DateTime(2026, 10, 23, 9),
      );

      final SessionAlarmContent content = SessionAlarmContent.fromSession(
        session,
      );

      expect(content.title, AppStrings.sessionAlarmNotificationTitle);
      expect(
        content.body,
        'Sesi "Bumi Manusia" mencapai target 00:25:00. Timer berhenti.',
      );
    });
  });

  group('LocalSessionAlarmService', () {
    late DateTime now;
    late FakeSessionAlarmDriver driver;
    late LocalSessionAlarmService service;

    setUp(() {
      now = DateTime(2026, 10, 23, 9);
      driver = FakeSessionAlarmDriver();
      service = LocalSessionAlarmService(driver: driver, clock: () => now);
    });

    tearDown(() => service.cancel());

    ActiveSession newSession({Duration target = const Duration(minutes: 25)}) {
      return ActiveSession.start(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        target: target,
        clock: () => now,
      );
    }

    test('sesi berjalan menjadwalkan notifikasi tepat pada target', () async {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 5));

      await service.sync(session);

      expect(driver.initializeCalls, 1);
      expect(driver.scheduledAt, DateTime(2026, 10, 23, 9, 25));
      expect(driver.scheduledExact, isTrue);
      expect(driver.scheduledTitle, AppStrings.sessionAlarmNotificationTitle);
      expect(
        driver.scheduledBody,
        'Sesi "Bumi Manusia" mencapai target 00:25:00. Timer berhenti.',
      );
    });

    test('callback target dipanggil saat waktu target tiba', () async {
      final ActiveSession session = newSession(
        target: const Duration(milliseconds: 40),
      );
      int callbacks = 0;

      await service.sync(session, onTargetReached: () => callbacks += 1);
      now = now.add(const Duration(milliseconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(callbacks, 1);
    });

    test('sesi dijeda membatalkan jadwal alarm', () async {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 5));
      final ActiveSession paused = session.copyWithTimer(session.timer.pause());

      await service.sync(paused);

      expect(driver.scheduledAt, isNull);
      expect(driver.cancelCalls, 1);
    });

    test('sesi selesai lebih awal membatalkan jadwal alarm', () async {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 10));
      final ActiveSession finished = session.copyWithTimer(
        session.timer.finish(),
      );

      await service.sync(finished);

      expect(driver.scheduledAt, isNull);
      expect(driver.cancelCalls, 1);
      expect(driver.vibrateCalls, 0);
      expect(driver.showCalls, 0);
    });

    test(
      'target tercapai bergetar, menampilkan notifikasi, dan berhenti',
      () async {
        final ActiveSession session = newSession();
        now = now.add(const Duration(minutes: 30));

        await service.sync(session, announceTargetReached: true);

        expect(driver.cancelCalls, 1);
        expect(driver.vibrateCalls, 1);
        expect(driver.showCalls, 1);
        expect(driver.shownTitle, AppStrings.sessionAlarmNotificationTitle);
        expect(
          driver.shownBody,
          'Sesi "Bumi Manusia" mencapai target 00:25:00. Timer berhenti.',
        );
      },
    );

    test('alarm target tidak dipicu dua kali untuk sesi yang sama', () async {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 30));

      await service.sync(session, announceTargetReached: true);
      await service.sync(session, announceTargetReached: true);

      expect(driver.vibrateCalls, 1);
      expect(driver.showCalls, 1);
    });

    test('pemulihan sesi target tercapai tidak memicu alarm ulang', () async {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 30));

      await service.sync(session);

      expect(driver.cancelCalls, 1);
      expect(driver.vibrateCalls, 0);
      expect(driver.showCalls, 0);
    });

    test('permintaan izin dijalankan saat sesi baru dimulai', () async {
      final ActiveSession session = newSession();

      await service.sync(session, requestPermissions: true);

      expect(driver.notificationPermissionRequests, 1);
      expect(driver.exactPermissionRequests, 1);
    });

    test('izin alarm tepat ditolak memakai jadwal tidak tepat', () async {
      final ActiveSession session = newSession();
      driver.canScheduleExact = false;

      await service.sync(session, requestPermissions: true);

      expect(driver.scheduledExact, isFalse);
      expect(driver.scheduledAt, isNotNull);
    });

    test('sesi kosong membatalkan jadwal', () async {
      await service.sync(null);

      expect(driver.cancelCalls, 1);
      expect(driver.scheduledAt, isNull);
    });

    test('kegagalan plugin tidak dilempar ke pemanggil', () async {
      final ActiveSession session = newSession();
      driver.scheduleError = StateError('jadwal gagal');

      await expectLater(service.sync(session), completes);
      await expectLater(service.cancel(), completes);
    });

    test('penyelarasan berurutan memakai antrean yang sama', () async {
      final ActiveSession session = newSession();
      final Completer<void> gate = Completer<void>();
      driver.scheduleGate = gate;

      final Future<void> first = service.sync(session);
      await Future<void>.delayed(Duration.zero);
      expect(driver.scheduleCalls, 1);

      final Future<void> second = service.sync(null);
      await Future<void>.delayed(Duration.zero);
      expect(driver.cancelCalls, 0);

      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(driver.scheduleCalls, 1);
      expect(driver.cancelCalls, 1);
      expect(driver.lastOperation, 'cancel');
    });
  });
}

class FakeSessionAlarmDriver implements SessionAlarmDriver {
  int initializeCalls = 0;
  int notificationPermissionRequests = 0;
  int exactPermissionRequests = 0;
  int cancelCalls = 0;
  int vibrateCalls = 0;
  int showCalls = 0;
  int scheduleCalls = 0;

  bool canScheduleExact = true;
  Object? scheduleError;
  Completer<void>? scheduleGate;

  DateTime? scheduledAt;
  bool? scheduledExact;
  String? scheduledTitle;
  String? scheduledBody;
  String? shownTitle;
  String? shownBody;
  String lastOperation = '';

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    notificationPermissionRequests += 1;
    return true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactPermissionRequests += 1;
    return canScheduleExact;
  }

  @override
  Future<bool> canScheduleExactAlarms() async => canScheduleExact;

  @override
  Future<void> schedule({
    required DateTime at,
    required bool exact,
    required String title,
    required String body,
  }) async {
    scheduleCalls += 1;
    lastOperation = 'schedule';
    final Completer<void>? gate = scheduleGate;
    if (gate != null) {
      await gate.future;
    }
    if (scheduleError != null) {
      throw scheduleError!;
    }
    scheduledAt = at;
    scheduledExact = exact;
    scheduledTitle = title;
    scheduledBody = body;
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    showCalls += 1;
    lastOperation = 'show';
    shownTitle = title;
    shownBody = body;
  }

  @override
  Future<void> cancelScheduled() async {
    cancelCalls += 1;
    lastOperation = 'cancel';
    scheduledAt = null;
  }

  @override
  Future<void> vibrateAlarm() async {
    vibrateCalls += 1;
    lastOperation = 'vibrate';
  }
}
