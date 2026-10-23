import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/session_notification_content.dart';

void main() {
  group('SessionNotificationContent', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 10, 23, 9);
    });

    ActiveSession newSession({Duration target = const Duration(minutes: 25)}) {
      return ActiveSession.start(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        target: target,
        clock: () => now,
      );
    }

    test('memakai judul buku dan waktu berjalan', () {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 5, seconds: 3));

      final SessionNotificationContent content =
          SessionNotificationContent.fromSession(session);

      expect(content.title, 'Bumi Manusia');
      expect(content.text, 'Sedang membaca • 00:05:03 dari target 00:25:00');
    });

    test('waktu membeku selama sesi dijeda', () {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 5));
      final ActiveSession paused = session.copyWithTimer(session.timer.pause());

      now = now.add(const Duration(minutes: 30));

      final SessionNotificationContent content =
          SessionNotificationContent.fromSession(paused);
      expect(content.text, 'Dijeda • 00:05:00 dari target 00:25:00');
    });

    test('target tercapai berhenti pada nilai target', () {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 40));

      final SessionNotificationContent content =
          SessionNotificationContent.fromSession(session);
      expect(content.text, 'Target tercapai • 00:25:00');
    });

    test('sesi selesai menampilkan status selesai', () {
      final ActiveSession session = newSession();
      now = now.add(const Duration(minutes: 10));
      final ActiveSession finished = session.copyWithTimer(
        session.timer.finish(),
      );

      final SessionNotificationContent content =
          SessionNotificationContent.fromSession(finished);
      expect(content.text, 'Sesi selesai • 00:10:00');
    });

    test('target nol langsung dianggap tercapai', () {
      final ActiveSession session = newSession(target: Duration.zero);

      final SessionNotificationContent content =
          SessionNotificationContent.fromSession(session);
      expect(content.text, 'Target tercapai • 00:00:00');
    });
  });
}
