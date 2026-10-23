import 'package:intl/intl.dart';

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
}
