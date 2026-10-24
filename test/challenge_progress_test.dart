import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/challenges/data/challenge.dart';
import 'package:libria/features/challenges/data/challenge_progress.dart';

void main() {
  group('ChallengeProgress.isActive', () {
    test('aktif pada tanggal di dalam rentang', () {
      final Challenge challenge = _challenge(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.isActive(challenge, DateTime(2026, 11, 15, 9, 30)),
        isTrue,
      );
    });

    test('aktif pada tanggal mulai dan tanggal selesai', () {
      final Challenge challenge = _challenge(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.isActive(challenge, DateTime(2026, 11, 1)),
        isTrue,
      );
      expect(
        ChallengeProgress.isActive(challenge, DateTime(2026, 11, 30, 23, 59)),
        isTrue,
      );
    });

    test('tidak aktif sebelum tanggal mulai', () {
      final Challenge challenge = _challenge(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.isActive(challenge, DateTime(2026, 10, 31, 23, 59)),
        isFalse,
      );
    });

    test('tidak aktif setelah tanggal selesai', () {
      final Challenge challenge = _challenge(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.isActive(challenge, DateTime(2026, 12, 1)),
        isFalse,
      );
    });

    test('tantangan tanpa tanggal dianggap tidak aktif', () {
      final Challenge challenge = _challenge(startDate: null, endDate: null);

      expect(
        ChallengeProgress.isActive(challenge, DateTime(2026, 11, 15)),
        isFalse,
      );
    });
  });

  group('ChallengeProgress.incrementFor', () {
    test('tantangan menit menambah sebanyak menit penuh di dalam rentang', () {
      final Challenge challenge = _challenge(
        type: Challenge.typeMinutes,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.incrementFor(
          challenge: challenge,
          moment: DateTime(2026, 11, 15, 10),
          readingDuration: const Duration(minutes: 42, seconds: 30),
        ),
        42,
      );
    });

    test('tantangan menit tidak bertambah di luar rentang', () {
      final Challenge challenge = _challenge(
        type: Challenge.typeMinutes,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.incrementFor(
          challenge: challenge,
          moment: DateTime(2026, 12, 2),
          readingDuration: const Duration(minutes: 42),
        ),
        0,
      );
    });

    test('tantangan buku bertambah satu saat buku selesai', () {
      final Challenge challenge = _challenge(
        type: Challenge.typeBooks,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.incrementFor(
          challenge: challenge,
          moment: DateTime(2026, 11, 15),
          bookFinished: true,
        ),
        1,
      );
    });

    test('tantangan buku tidak bertambah bila buku belum selesai', () {
      final Challenge challenge = _challenge(
        type: Challenge.typeBooks,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.incrementFor(
          challenge: challenge,
          moment: DateTime(2026, 11, 15),
        ),
        0,
      );
    });

    test('tantangan buku tidak bertambah di luar rentang', () {
      final Challenge challenge = _challenge(
        type: Challenge.typeBooks,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.incrementFor(
          challenge: challenge,
          moment: DateTime(2026, 10, 1),
          bookFinished: true,
        ),
        0,
      );
    });

    test('dua jenis tantangan dihitung terpisah pada peristiwa yang sama', () {
      final DateTime moment = DateTime(2026, 11, 15, 10);
      final Challenge minutes = _challenge(
        id: 'minutes',
        type: Challenge.typeMinutes,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );
      final Challenge books = _challenge(
        id: 'books',
        type: Challenge.typeBooks,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.incrementFor(
          challenge: minutes,
          moment: moment,
          readingDuration: const Duration(minutes: 30),
          bookFinished: true,
        ),
        30,
      );
      expect(
        ChallengeProgress.incrementFor(
          challenge: books,
          moment: moment,
          readingDuration: const Duration(minutes: 30),
          bookFinished: true,
        ),
        1,
      );
    });

    test('jenis tidak dikenal tidak menambah progres', () {
      final Challenge challenge = _challenge(
        type: 'pages',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(
        ChallengeProgress.incrementFor(
          challenge: challenge,
          moment: DateTime(2026, 11, 15),
          readingDuration: const Duration(minutes: 30),
          bookFinished: true,
        ),
        0,
      );
    });
  });

  group('ChallengeProgress hitungan tampilan', () {
    test('progres tidak pernah negatif', () {
      expect(ChallengeProgress.nextProgress(2, -5), 0);
      expect(ChallengeProgress.nextProgress(2, 3), 5);
    });

    test('rasio dan persentase dipotong pada batas target', () {
      expect(ChallengeProgress.ratio(5, 10), 0.5);
      expect(ChallengeProgress.ratio(15, 10), 1);
      expect(ChallengeProgress.ratio(5, 0), 0);
      expect(ChallengeProgress.percent(5, 10), 50);
      expect(ChallengeProgress.percent(15, 10), 100);
    });
  });
}

Challenge _challenge({
  String id = 'challenge-1',
  String type = Challenge.typeMinutes,
  DateTime? startDate,
  DateTime? endDate,
}) {
  return Challenge(
    id: id,
    title: 'Tantangan Membaca',
    description: 'Deskripsi tantangan.',
    type: type,
    targetValue: 100,
    startDate: startDate,
    endDate: endDate,
    createdBy: 'admin-1',
  );
}
