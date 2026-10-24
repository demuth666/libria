import 'dart:math' as math;

import 'challenge.dart';

/// Aturan progres otomatis tantangan (FR-C3).
///
/// Fungsi di kelas ini murni agar rentang tanggal dan penambahan progres dapat
/// diuji tanpa Firestore. Rentang tanggal dibandingkan per hari agar tantangan
/// tetap aktif sepanjang tanggal selesai, bukan berhenti pada tengah malam di
/// awal tanggal tersebut.
abstract final class ChallengeProgress {
  const ChallengeProgress._();

  /// `true` bila [moment] berada pada rentang tanggal tantangan.
  ///
  /// Tantangan tanpa tanggal mulai atau selesai dianggap tidak aktif karena
  /// admin selalu mengisi kedua tanggal pada FR-C1.
  static bool isActive(Challenge challenge, DateTime moment) {
    final DateTime? startDate = challenge.startDate;
    final DateTime? endDate = challenge.endDate;
    if (startDate == null || endDate == null) {
      return false;
    }
    final DateTime day = _dayOf(moment);
    final DateTime startDay = _dayOf(startDate);
    final DateTime endDay = _dayOf(endDate);
    return !day.isBefore(startDay) && !day.isAfter(endDay);
  }

  /// Penambahan progres untuk satu peristiwa membaca.
  ///
  /// Tantangan menit bertambah sebanyak menit penuh dari [readingDuration].
  /// Tantangan buku hanya bertambah satu ketika [bookFinished] benar. Nilai
  /// nol dipakai bila tantangan sedang tidak aktif atau jenisnya tidak dikenal.
  static int incrementFor({
    required Challenge challenge,
    required DateTime moment,
    Duration readingDuration = Duration.zero,
    bool bookFinished = false,
  }) {
    if (!isActive(challenge, moment)) {
      return 0;
    }
    switch (challenge.type) {
      case Challenge.typeMinutes:
        return math.max(readingDuration.inMinutes, 0);
      case Challenge.typeBooks:
        return bookFinished ? 1 : 0;
      default:
        return 0;
    }
  }

  /// Progres setelah penambahan, tidak pernah negatif.
  static int nextProgress(int current, int increment) {
    return math.max(current + increment, 0);
  }

  /// Rasio progres terhadap target pada rentang 0 sampai 1.
  static double ratio(int progress, int target) {
    if (target <= 0) {
      return 0;
    }
    return (progress / target).clamp(0, 1).toDouble();
  }

  /// Persentase progres terhadap target pada rentang 0 sampai 100.
  static int percent(int progress, int target) {
    return (ratio(progress, target) * 100).round();
  }

  static DateTime _dayOf(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
