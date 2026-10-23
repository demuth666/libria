import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/session_timer_task_handler.dart';

void main() {
  group('decodeSessionPayload', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 10, 23, 9);
    });

    ActiveSession newSession() {
      return ActiveSession.start(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        target: const Duration(minutes: 25),
        clock: () => now,
      );
    }

    test('membaca payload JSON dari isolate utama', () {
      final ActiveSession session = newSession();

      final ActiveSession? decoded = decodeSessionPayload(
        jsonEncode(session.toMap()),
      );

      expect(decoded, isNotNull);
      expect(decoded!.bookId, 'book-1');
      expect(decoded.bookTitle, 'Bumi Manusia');
      expect(decoded.timer.target, const Duration(minutes: 25));
    });

    test('membaca payload berupa map', () {
      final ActiveSession session = newSession();

      final ActiveSession? decoded = decodeSessionPayload(session.toMap());

      expect(decoded?.bookId, 'book-1');
    });

    test('mengabaikan data kosong, rusak, dan tidak lengkap', () {
      expect(decodeSessionPayload(null), isNull);
      expect(decodeSessionPayload('bukan json'), isNull);
      expect(decodeSessionPayload('<xml/>'), isNull);
      expect(decodeSessionPayload(<String, dynamic>{}), isNull);
      expect(
        decodeSessionPayload(<String, dynamic>{
          'bookId': 'book-1',
          'bookTitle': 'Bumi Manusia',
          'timer': <String, dynamic>{},
        }),
        isNull,
      );
    });
  });
}
