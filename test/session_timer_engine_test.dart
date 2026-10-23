import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/session/data/session_timer_engine.dart';

void main() {
  group('SessionTimerEngine', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 10, 23, 9);
    });

    DateTime clock() => now;

    test('dimulai dari idle dan berjalan sesuai cap waktu', () {
      final SessionTimerEngine engine = SessionTimerEngine.idle(
        target: const Duration(minutes: 30),
        clock: clock,
      );

      expect(engine.state, SessionTimerState.idle);
      expect(engine.elapsed, Duration.zero);
      expect(engine.startedAt, isNull);
      expect(engine.endedAt, isNull);
      expect(engine.progress, 0);

      final SessionTimerEngine started = engine.start();

      expect(started.state, SessionTimerState.running);
      expect(started.startedAt, now);
      expect(started.elapsed, Duration.zero);

      now = now.add(const Duration(seconds: 75));

      expect(started.state, SessionTimerState.running);
      expect(started.elapsed, const Duration(seconds: 75));
      expect(started.progress, 75 / (30 * 60));
    });

    test('jeda membekukan durasi dan lanjut meneruskan dari titik jeda', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(minutes: 30),
        clock: clock,
      ).start();

      now = now.add(const Duration(seconds: 45));
      final SessionTimerEngine paused = started.pause();

      expect(paused.state, SessionTimerState.paused);
      expect(paused.elapsed, const Duration(seconds: 45));

      now = now.add(const Duration(minutes: 10));

      expect(paused.state, SessionTimerState.paused);
      expect(paused.elapsed, const Duration(seconds: 45));

      final SessionTimerEngine resumed = paused.resume();

      expect(resumed.state, SessionTimerState.running);
      expect(resumed.elapsed, const Duration(seconds: 45));

      now = now.add(const Duration(seconds: 15));

      expect(resumed.elapsed, const Duration(minutes: 1));
      expect(paused.elapsed, const Duration(seconds: 45));
    });

    test('mencapai target tepat dan berhenti pada nilai target', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(minutes: 2),
        clock: clock,
      ).start();

      now = now.add(const Duration(minutes: 1));

      expect(started.state, SessionTimerState.running);
      expect(started.progress, 0.5);

      now = now.add(const Duration(minutes: 1));

      expect(started.state, SessionTimerState.targetReached);
      expect(started.elapsed, const Duration(minutes: 2));
      expect(started.progress, 1);
      expect(started.endedAt, DateTime(2026, 10, 23, 9, 2));

      now = now.add(const Duration(minutes: 20));

      expect(started.state, SessionTimerState.targetReached);
      expect(started.elapsed, const Duration(minutes: 2));

      final SessionTimerEngine finished = started.finish();

      expect(finished.state, SessionTimerState.finished);
      expect(finished.elapsed, const Duration(minutes: 2));
      expect(finished.endedAt, DateTime(2026, 10, 23, 9, 2));

      now = now.add(const Duration(hours: 1));

      expect(finished.elapsed, const Duration(minutes: 2));
    });

    test('jeda panjang tidak dihitung menuju target', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(minutes: 2),
        clock: clock,
      ).start();

      now = now.add(const Duration(minutes: 1));
      final SessionTimerEngine paused = started.pause();

      now = now.add(const Duration(hours: 1));

      expect(paused.state, SessionTimerState.paused);
      expect(paused.elapsed, const Duration(minutes: 1));

      final SessionTimerEngine resumed = paused.resume();
      now = now.add(const Duration(seconds: 59));

      expect(resumed.state, SessionTimerState.running);
      expect(resumed.elapsed, const Duration(minutes: 1, seconds: 59));

      now = now.add(const Duration(seconds: 1));

      expect(resumed.state, SessionTimerState.targetReached);
      expect(resumed.elapsed, const Duration(minutes: 2));
    });

    test('selesai sebelum target membekukan durasi akhir', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(minutes: 30),
        clock: clock,
      ).start();

      now = now.add(const Duration(minutes: 10));
      final SessionTimerEngine finished = started.finish();

      expect(finished.state, SessionTimerState.finished);
      expect(finished.elapsed, const Duration(minutes: 10));
      expect(finished.endedAt, DateTime(2026, 10, 23, 9, 10));

      now = now.add(const Duration(minutes: 20));

      expect(finished.state, SessionTimerState.finished);
      expect(finished.elapsed, const Duration(minutes: 10));
    });

    test('selesai saat jeda tidak menghitung sisa waktu jeda', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(minutes: 30),
        clock: clock,
      ).start();

      now = now.add(const Duration(minutes: 5));
      final SessionTimerEngine paused = started.pause();
      now = now.add(const Duration(minutes: 5));

      final SessionTimerEngine finished = paused.finish();

      expect(finished.state, SessionTimerState.finished);
      expect(finished.elapsed, const Duration(minutes: 5));
      expect(finished.endedAt, DateTime(2026, 10, 23, 9, 10));
    });

    test('serialisasi menyimpan cap waktu dan akumulasi jeda', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(minutes: 25),
        clock: clock,
      ).start();

      now = now.add(const Duration(minutes: 10));
      final SessionTimerEngine paused = started.pause();
      now = now.add(const Duration(minutes: 2));
      final SessionTimerEngine resumed = paused.resume();
      now = now.add(const Duration(minutes: 3));

      final Map<String, dynamic> map = resumed.toMap();

      expect(map['state'], 'running');
      expect(map['targetSeconds'], 25 * 60);
      expect(
        map['startedAtMs'],
        DateTime(2026, 10, 23, 9).millisecondsSinceEpoch,
      );
      expect(map['accumulatedPauseMs'], 2 * 60 * 1000);
      expect(map['pausedAtMs'], isNull);
      expect(map['finishedAtMs'], isNull);

      final SessionTimerEngine restored = SessionTimerEngine.fromMap(
        map,
        clock: clock,
      );

      expect(restored.state, SessionTimerState.running);
      expect(restored.startedAt, DateTime(2026, 10, 23, 9));
      expect(restored.elapsed, const Duration(minutes: 13));
      expect(restored.toMap(), map);
    });

    test('memulihkan sesi berjalan setelah aplikasi lama tertutup', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(hours: 3),
        clock: clock,
      ).start();

      now = now.add(const Duration(minutes: 10));
      final Map<String, dynamic> map = started.toMap();

      now = DateTime(2026, 10, 23, 11);

      final SessionTimerEngine restored = SessionTimerEngine.fromMap(
        map,
        clock: clock,
      );

      expect(restored.state, SessionTimerState.running);
      expect(restored.startedAt, DateTime(2026, 10, 23, 9));
      expect(restored.elapsed, const Duration(hours: 2));
      expect(restored.toMap(), map);
    });

    test('memulihkan sesi jeda setelah aplikasi lama tertutup', () {
      final SessionTimerEngine started = SessionTimerEngine.idle(
        target: const Duration(minutes: 10),
        clock: clock,
      ).start();

      now = now.add(const Duration(minutes: 5));
      final SessionTimerEngine paused = started.pause();
      final Map<String, dynamic> map = paused.toMap();

      now = DateTime(2026, 10, 23, 12);

      final SessionTimerEngine restored = SessionTimerEngine.fromMap(
        map,
        clock: clock,
      );

      expect(restored.state, SessionTimerState.paused);
      expect(restored.elapsed, const Duration(minutes: 5));
      expect(restored.toMap(), map);

      now = now.add(const Duration(minutes: 1));
      final SessionTimerEngine resumed = restored.resume();

      now = now.add(const Duration(minutes: 5));

      expect(resumed.state, SessionTimerState.targetReached);
      expect(resumed.elapsed, const Duration(minutes: 10));
    });

    test('map kosong atau rusak dipulihkan sebagai idle', () {
      final SessionTimerEngine restored = SessionTimerEngine.fromMap(
        <String, dynamic>{'state': 'tidakDikenal', 'targetSeconds': -5},
        clock: clock,
      );

      expect(restored.state, SessionTimerState.idle);
      expect(restored.target, Duration.zero);
      expect(restored.elapsed, Duration.zero);
    });
  });
}
