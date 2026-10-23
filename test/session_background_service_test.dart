import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/session_background_service.dart';

void main() {
  group('ForegroundSessionBackgroundService', () {
    late DateTime now;
    late FakeSessionBackgroundDriver driver;
    late ForegroundSessionBackgroundService service;

    setUp(() {
      now = DateTime(2026, 10, 23, 9);
      driver = FakeSessionBackgroundDriver();
      service = ForegroundSessionBackgroundService(driver: driver);
    });

    ActiveSession newSession({Duration target = const Duration(minutes: 25)}) {
      return ActiveSession.start(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        target: target,
        clock: () => now,
      );
    }

    test(
      'sesi berjalan memulai layanan dengan judul dan waktu berjalan',
      () async {
        final ActiveSession session = newSession();
        now = now.add(const Duration(minutes: 5));

        await service.sync(session, requestNotificationPermission: true);

        expect(driver.calls, <String>[
          'permission',
          'save',
          'isRunning',
          'start',
          'send',
        ]);
        expect(driver.running, isTrue);
        expect(driver.lastTitle, 'Bumi Manusia');
        expect(
          driver.lastText,
          'Sedang membaca • 00:05:00 dari target 00:25:00',
        );
        expect(driver.savedPayload, isNotNull);
        expect(driver.taskPayload, driver.savedPayload);

        final Map<String, dynamic> payload =
            jsonDecode(driver.savedPayload!) as Map<String, dynamic>;
        expect(payload['bookId'], 'book-1');
        expect(payload['bookTitle'], 'Bumi Manusia');
        expect((payload['timer'] as Map<String, dynamic>)['state'], 'running');
      },
    );

    test('layanan yang sudah berjalan hanya diperbarui', () async {
      final ActiveSession session = newSession();
      driver.running = true;

      await service.sync(session);

      expect(driver.calls, <String>['save', 'isRunning', 'update', 'send']);
      expect(driver.calls, isNot(contains('permission')));
      expect(driver.calls, isNot(contains('start')));
      expect(driver.lastText, startsWith('Sedang membaca • 00:00:00'));
    });

    test('sesi dijeda menampilkan waktu yang membeku', () async {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 5));
      final ActiveSession paused = session.copyWithTimer(session.timer.pause());
      driver.running = true;

      await service.sync(paused);

      expect(driver.lastText, 'Dijeda • 00:05:00 dari target 00:25:00');
      final Map<String, dynamic> payload =
          jsonDecode(driver.taskPayload!) as Map<String, dynamic>;
      expect((payload['timer'] as Map<String, dynamic>)['state'], 'paused');
    });

    test(
      'target tercapai tetap menampilkan notifikasi pada nilai target',
      () async {
        final ActiveSession session = newSession();
        now = now.add(const Duration(minutes: 30));
        driver.running = true;

        await service.sync(session);

        expect(driver.lastText, 'Target tercapai • 00:25:00');
        expect(driver.calls, isNot(contains('stop')));
      },
    );

    test('sesi selesai menghentikan layanan dan menghapus payload', () async {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 10));
      final ActiveSession finished = session.copyWithTimer(
        session.timer.finish(),
      );
      driver.running = true;

      await service.sync(finished);

      expect(driver.calls, <String>['clear', 'stop']);
      expect(driver.running, isFalse);
      expect(driver.savedPayload, isNull);
      expect(driver.taskPayload, isNull);
    });

    test('sesi kosong menghentikan layanan', () async {
      driver.running = true;

      await service.sync(null);

      expect(driver.calls, <String>['clear', 'stop']);
      expect(driver.running, isFalse);
    });

    test('izin notifikasi ditolak tidak membatalkan layanan', () async {
      final ActiveSession session = newSession();
      driver.permissionResult = false;

      await service.sync(session, requestNotificationPermission: true);

      expect(driver.calls, contains('permission'));
      expect(driver.calls, contains('start'));
      expect(driver.running, isTrue);
    });

    test('kegagalan driver tidak dilempar ke pemanggil', () async {
      final ActiveSession session = newSession();
      driver.startError = StateError('layanan gagal dimulai');

      await expectLater(service.sync(session), completes);
      expect(driver.calls, contains('start'));
    });

    test('penyelarasan berurutan memakai antrean yang sama', () async {
      final ActiveSession session = newSession();
      driver.startGate = Completer<void>();

      final Future<void> first = service.sync(session);
      await Future<void>.delayed(Duration.zero);
      expect(driver.calls, <String>['save', 'isRunning', 'start']);

      final Future<void> second = service.sync(session);
      await Future<void>.delayed(Duration.zero);
      expect(driver.calls, <String>['save', 'isRunning', 'start']);

      driver.startGate!.complete();
      await first;
      await second;

      expect(driver.calls, <String>[
        'save',
        'isRunning',
        'start',
        'send',
        'save',
        'isRunning',
        'update',
        'send',
      ]);
    });
  });
}

class FakeSessionBackgroundDriver implements SessionBackgroundDriver {
  final List<String> calls = <String>[];

  bool running = false;
  bool permissionResult = true;
  Object? startError;
  Completer<void>? startGate;

  String? savedPayload;
  String? taskPayload;
  String? lastTitle;
  String? lastText;

  @override
  Future<bool> requestNotificationPermission() async {
    calls.add('permission');
    return permissionResult;
  }

  @override
  Future<bool> isServiceRunning() async {
    calls.add('isRunning');
    return running;
  }

  @override
  Future<void> startService({
    required String title,
    required String text,
  }) async {
    calls.add('start');
    lastTitle = title;
    lastText = text;
    final Completer<void>? gate = startGate;
    if (gate != null) {
      await gate.future;
    }
    if (startError != null) {
      throw startError!;
    }
    running = true;
  }

  @override
  Future<void> updateService({
    required String title,
    required String text,
  }) async {
    calls.add('update');
    lastTitle = title;
    lastText = text;
  }

  @override
  Future<void> stopService() async {
    calls.add('stop');
    running = false;
  }

  @override
  Future<void> saveSessionPayload(String payload) async {
    calls.add('save');
    savedPayload = payload;
  }

  @override
  Future<void> clearSessionPayload() async {
    calls.add('clear');
    savedPayload = null;
  }

  @override
  Future<void> sendSessionPayloadToTask(String payload) async {
    calls.add('send');
    taskPayload = payload;
  }
}
