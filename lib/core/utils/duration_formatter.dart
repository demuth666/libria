/// Pemformatan durasi untuk timer sesi membaca.
abstract final class AppDurationFormatter {
  const AppDurationFormatter._();

  /// Durasi timer dengan format `HH:MM:SS`, contoh "00:25:00".
  ///
  /// Nilai negatif dianggap nol agar sisa waktu tidak pernah tampil dengan
  /// tanda minus. Jam tidak dibatasi dua digit sehingga sesi yang sangat
  /// panjang tetap terbaca utuh.
  static String timer(Duration duration) {
    final Duration value = duration.isNegative ? Duration.zero : duration;
    final String hours = value.inHours.toString().padLeft(2, '0');
    final String minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
