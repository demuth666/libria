/// Teks antarmuka aplikasi dalam bahasa Indonesia.
///
/// Kerangka ini diisi bertahap: setiap task yang menyentuh UI menambahkan
/// teksnya di bagian sesuai fiturnya, bukan menulis teks langsung di widget.
/// Urutan bagian mengikuti PRD dan `docs/TASKS.md`.
class AppStrings {
  const AppStrings._();

  // Umum.
  static const String appName = 'Libria';

  // Autentikasi.
  // Katalog buku (admin).
  // Perpustakaan dan beranda (user).
  // Sesi membaca.
  // Jurnal dan ulasan.
  // Statistik dan laporan.
  // Komunitas, kegiatan, tantangan, notifikasi.
  // Pengaturan.

  // Komponen bersama (core/widgets).
  static const String retry = 'Coba Lagi';
  static const String cancel = 'Batal';
  static const String genericError = 'Terjadi kesalahan. Silakan coba lagi.';
  static const String offlineBanner = 'Anda sedang offline';
  static const String showPassword = 'Tampilkan kata sandi';
  static const String hidePassword = 'Sembunyikan kata sandi';

  /// Label halaman yang sudah dibaca, contoh: "Hlm 75 / 100".
  static String pagesRead(int current, int total) => 'Hlm $current / $total';

  /// Label persentase progres baca, contoh: "75% Selesai".
  static String percentDone(int percent) => '$percent% Selesai';

  /// Label jumlah tanggapan pada kartu postingan, contoh: "24 Tanggapan".
  static String replyCountLabel(int count) => '$count Tanggapan';
}
