import 'package:intl/intl.dart';

import '../constants/app_strings.dart';

/// Pemformatan tanggal dan waktu aplikasi.
///
/// Data locale `id_ID` dimuat di `main.dart` lewat
/// `initializeDateFormatting('id_ID')` sebelum aplikasi berjalan.
abstract final class AppDateFormatter {
  const AppDateFormatter._();

  static final DateFormat _dateTime = DateFormat('d MMMM yyyy, HH.mm', 'id_ID');
  static final DateFormat _date = DateFormat('d MMMM yyyy', 'id_ID');
  static final DateFormat _weekdayShort = DateFormat('E', 'id_ID');
  static final DateFormat _dayMonthShort = DateFormat('d MMM', 'id_ID');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'id_ID');
  static final DateFormat _weekdayNarrow = DateFormat('EEE', 'id_ID');

  /// Tanggal dan waktu lengkap, contoh "21 Oktober 2026, 14.05".
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// Tanggal saja, contoh "21 Oktober 2026".
  static String date(DateTime value) => _date.format(value);

  /// Nama bulan dan tahun, contoh "Oktober 2026".
  static String monthYear(DateTime value) => _monthYear.format(value);

  /// Nama hari singkat untuk header kalender, contoh "Sen".
  static String weekdayNarrow(DateTime value) => _weekdayNarrow.format(value);

  /// Nama hari singkat, contoh "Sen".
  static String weekdayShort(DateTime value) => _weekdayShort.format(value);

  /// Tanggal dan bulan singkat, contoh "23 Okt".
  static String dayMonthShort(DateTime value) => _dayMonthShort.format(value);

  /// Waktu relatif singkat untuk feed dan daftar aktivitas.
  ///
  /// Hari yang sama memakai menit atau jam, hari sebelumnya "Kemarin", lalu
  /// jumlah hari sampai satu pekan. Tanggal yang lebih lama memakai tanggal
  /// singkat, atau tanggal lengkap bila tahunnya berbeda.
  static String relativeTime(DateTime value, {DateTime? now}) {
    final DateTime reference = (now ?? DateTime.now()).toLocal();
    final DateTime local = value.toLocal();
    final DateTime referenceDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final DateTime valueDay = DateTime(local.year, local.month, local.day);
    final int dayDifference = referenceDay.difference(valueDay).inDays;

    if (dayDifference <= 0) {
      final Duration elapsed = reference.difference(local);
      if (elapsed.inMinutes < 1) {
        return AppStrings.relativeJustNow;
      }
      if (elapsed.inMinutes < 60) {
        return AppStrings.relativeMinutesAgo(elapsed.inMinutes);
      }
      return AppStrings.relativeHoursAgo(elapsed.inHours);
    }
    if (dayDifference == 1) {
      return AppStrings.relativeYesterday;
    }
    if (dayDifference < 7) {
      return AppStrings.relativeDaysAgo(dayDifference);
    }
    if (local.year == reference.year) {
      return dayMonthShort(local);
    }
    return date(local);
  }
}
