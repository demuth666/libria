import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/active_session_repository.dart';
import 'package:libria/features/session/data/session_timer_engine.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ActiveSession', () {
    test('serialisasi menyimpan buku dan seluruh cap waktu timer', () {
      final DateTime now = DateTime(2026, 10, 23, 9);
      final ActiveSession session = ActiveSession.start(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        target: const Duration(minutes: 30),
        clock: () => now,
      );

      final Map<String, dynamic> map = session.toMap();

      expect(map['bookId'], 'book-1');
      expect(map['bookTitle'], 'Bumi Manusia');
      final Map<String, dynamic> timer = map['timer'] as Map<String, dynamic>;
      expect(timer['state'], 'running');
      expect(timer['targetSeconds'], 30 * 60);
      expect(timer['startedAtMs'], now.millisecondsSinceEpoch);
    });

    test('map tanpa buku atau tanpa waktu mulai dianggap tidak layak', () {
      final ActiveSession missingBook = ActiveSession.fromMap(<String, dynamic>{
        'bookId': 'book-1',
        'bookTitle': '',
        'timer': <String, dynamic>{
          'state': 'running',
          'targetSeconds': 600,
          'startedAtMs': DateTime(2026, 10, 23).millisecondsSinceEpoch,
        },
      });
      final ActiveSession missingStart = ActiveSession.fromMap(
        <String, dynamic>{
          'bookId': 'book-1',
          'bookTitle': 'Bumi Manusia',
          'timer': <String, dynamic>{'state': 'running', 'targetSeconds': 600},
        },
      );

      expect(missingBook.isRestorable, isFalse);
      expect(missingStart.isRestorable, isFalse);
    });
  });

  group('ActiveSessionRepository', () {
    test('memulihkan sesi berjalan setelah aplikasi dibuka lagi', () async {
      DateTime now = DateTime(2026, 10, 23, 9);
      final ActiveSessionRepository repository = ActiveSessionRepository(
        clock: () => now,
      );
      final ActiveSession session = ActiveSession.start(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        target: const Duration(hours: 5),
        clock: () => now,
      );

      now = now.add(const Duration(minutes: 12));
      await repository.save(session);

      // Buang cache statis plugin untuk meniru proses aplikasi baru.
      SharedPreferences.resetStatic();
      now = DateTime(2026, 10, 23, 11);

      final ActiveSession? restored = await ActiveSessionRepository(
        clock: () => now,
      ).load();

      expect(restored, isNotNull);
      expect(restored!.bookId, 'book-1');
      expect(restored.bookTitle, 'Bumi Manusia');
      expect(restored.timer.state, SessionTimerState.running);
      expect(restored.timer.startedAt, DateTime(2026, 10, 23, 9));
      expect(restored.timer.elapsed, const Duration(hours: 2));
      expect(restored.timer.target, const Duration(hours: 5));
    });

    test('memulihkan sesi jeda setelah aplikasi dibuka lagi', () async {
      DateTime now = DateTime(2026, 10, 23, 9);
      final ActiveSessionRepository repository = ActiveSessionRepository(
        clock: () => now,
      );
      final ActiveSession running = ActiveSession.start(
        bookId: 'book-2',
        bookTitle: 'Laskar Pelangi',
        target: const Duration(minutes: 20),
        clock: () => now,
      );

      now = now.add(const Duration(minutes: 5));
      await repository.save(running.copyWithTimer(running.timer.pause()));

      SharedPreferences.resetStatic();
      now = DateTime(2026, 10, 23, 12);

      final ActiveSession? restored = await ActiveSessionRepository(
        clock: () => now,
      ).load();

      expect(restored, isNotNull);
      expect(restored!.timer.state, SessionTimerState.paused);
      expect(restored.timer.elapsed, const Duration(minutes: 5));
      expect(restored.timer.startedAt, DateTime(2026, 10, 23, 9));
    });

    test('tanpa data tersimpan mengembalikan null', () async {
      final ActiveSession? restored = await ActiveSessionRepository().load();

      expect(restored, isNull);
    });

    test('JSON rusak dibuang dan dianggap tidak ada sesi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ActiveSessionRepository.storageKey: '{bukan json',
      });

      final ActiveSession? restored = await ActiveSessionRepository().load();

      expect(restored, isNull);
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(preferences.getString(ActiveSessionRepository.storageKey), isNull);
    });

    test('data tidak lengkap dibuang dan dianggap tidak ada sesi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ActiveSessionRepository.storageKey: jsonEncode(<String, dynamic>{
          'bookId': 'book-1',
          'bookTitle': '',
          'timer': <String, dynamic>{
            'state': 'running',
            'targetSeconds': 600,
            'startedAtMs': DateTime(2026, 10, 23).millisecondsSinceEpoch,
          },
        }),
      });

      final ActiveSession? restored = await ActiveSessionRepository().load();

      expect(restored, isNull);
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(preferences.getString(ActiveSessionRepository.storageKey), isNull);
    });

    test('clear menghapus sesi aktif', () async {
      final ActiveSessionRepository repository = ActiveSessionRepository();
      final ActiveSession session = ActiveSession.start(
        bookId: 'book-3',
        bookTitle: 'Sapiens',
        target: const Duration(minutes: 15),
      );
      await repository.save(session);

      await repository.clear();

      expect(await repository.load(), isNull);
    });
  });
}
