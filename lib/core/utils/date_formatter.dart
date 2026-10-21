import 'package:intl/intl.dart';

/// Pemformatan tanggal dan waktu aplikasi.
///
/// Data locale `id_ID` dimuat di `main.dart` lewat
/// `initializeDateFormatting('id_ID')` sebelum aplikasi berjalan.
abstract final class AppDateFormatter {
  const AppDateFormatter._();

  static final DateFormat _dateTime = DateFormat('d MMMM yyyy, HH.mm', 'id_ID');

  /// Tanggal dan waktu lengkap, contoh "21 Oktober 2026, 14.05".
  static String dateTime(DateTime value) => _dateTime.format(value);
}
