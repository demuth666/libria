/// Pemeriksaan isian formulir yang dipakai bersama oleh layar autentikasi.
abstract final class AppValidators {
  const AppValidators._();

  /// Pola sederhana untuk email: satu `@`, ada bagian domain dan titik.
  ///
  /// Validasi akhir tetap dilakukan Firebase Auth; pola ini hanya menahan
  /// kesalahan ketik yang jelas sebelum permintaan jaringan dikirim.
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// `true` bila [value] berbentuk alamat email yang wajar.
  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());
}
