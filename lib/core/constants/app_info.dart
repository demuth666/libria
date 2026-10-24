/// Informasi statis aplikasi yang tampil di antarmuka.
///
/// Versi ini harus disamakan dengan `version` pada `pubspec.yaml` setiap kali
/// versi rilis berubah (T-099). Nilainya berupa konstanta karena paket
/// `package_info_plus` tidak termasuk daftar paket proyek (AGENTS.md bagian 2).
abstract final class AppInfo {
  /// Versi rilis aplikasi, tanpa nomor build.
  static const String version = '1.0.0';
}
