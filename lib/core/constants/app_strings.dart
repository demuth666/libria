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
  static const String loginTitle = 'Masuk';
  static const String registerTitle = 'Daftar Akun Baru';
  static const String forgotPasswordTitle = 'Lupa Kata Sandi';

  // Splash (T-013).
  static const String splashTagline =
      'Ruang tenang untuk membaca, mencatat refleksi, dan menjelajahi '
      'samudera literasi.';
  static const String splashQuote =
      '“Membaca adalah jendela menuju ribuan kehidupan yang belum sempat '
      'dijalani.”';
  static const String splashQuoteAttribution = 'Catatan Perjalanan Literasi';
  static const String splashStatusPreparing = 'Menyiapkan Rak Pilihan...';
  static const String splashStatusSyncing = 'Menyinkronkan Kutipan...';
  static const String splashStatusReady = 'Selamat Membaca.';
  static const String splashFooter = 'Libria • Literary Elegance';
  static const String splashError =
      'Tidak dapat memeriksa status masuk. Periksa koneksi Anda lalu coba '
      'lagi.';

  /// Persentase pada bilah progres splash, contoh: "65%".
  static String splashProgressPercent(int percent) => '$percent%';

  // Autentikasi: pesan galat dari AuthRepository (T-010).
  static const String authErrorInvalidEmail = 'Format email tidak valid.';
  static const String authErrorUserDisabled = 'Akun ini telah dinonaktifkan.';
  static const String authErrorInvalidCredential =
      'Email atau kata sandi salah.';
  static const String authErrorEmailInUse = 'Email ini sudah terdaftar.';
  static const String authErrorWeakPassword =
      'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
  static const String authErrorOperationNotAllowed =
      'Metode masuk ini belum diaktifkan.';
  static const String authErrorTooManyRequests =
      'Terlalu banyak percobaan. Silakan coba lagi nanti.';
  static const String authErrorNetwork =
      'Tidak ada koneksi internet. Periksa jaringan Anda.';
  static const String authErrorRequiresRecentLogin =
      'Sesi Anda sudah kedaluwarsa. Silakan masuk kembali.';
  static const String authErrorGoogleCancelled =
      'Proses masuk dengan Google dibatalkan.';
  static const String authErrorGoogleFailed =
      'Masuk dengan Google gagal. Silakan coba lagi.';
  static const String authErrorNoCurrentUser =
      'Tidak ada pengguna yang sedang masuk.';

  // Katalog buku (admin).
  static const String adminDashboardTitle = 'Dashboard Admin';
  static const String adminBooksTitle = 'Kelola Buku';
  static const String adminBookNewTitle = 'Tambah Buku';
  static const String adminBookEditTitle = 'Ubah Buku';
  static const String adminIsbnLogsTitle = 'Log ISBN';

  // Perpustakaan dan beranda (user).
  static const String homeTitle = 'Beranda';
  static const String libraryTitle = 'Koleksi';
  static const String bookDetailTitle = 'Detail Buku';

  // Sesi membaca.
  static const String sessionNavLabel = 'Sesi Baca';
  static const String sessionSetupTitle = 'Atur Sesi';
  static const String sessionRunTitle = 'Sesi Membaca';
  static const String sessionFinishTitle = 'Selesai Sesi';

  // Jurnal dan ulasan.
  static const String journalTitle = 'Jurnal';
  static const String journalNewTitle = 'Jurnal Baru';

  // Statistik dan laporan.
  static const String statsTitle = 'Statistik';
  static const String reportTitle = 'Laporan';

  // Komunitas, kegiatan, tantangan, notifikasi.
  static const String communityTitle = 'Komunitas';
  static const String notificationsTitle = 'Notifikasi';
  static const String eventsTitle = 'Kegiatan';
  static const String eventDetailTitle = 'Detail Kegiatan';
  static const String challengesTitle = 'Tantangan';
  static const String challengeDetailTitle = 'Detail Tantangan';
  static const String postDetailTitle = 'Detail Postingan';
  static const String adminReportsTitle = 'Moderasi Laporan';
  static const String adminEventsTitle = 'Kelola Kegiatan';
  static const String adminChallengesTitle = 'Kelola Tantangan';

  // Pengaturan.
  // Label "Profil" mengikuti nama layar dan item navigasi bawah di Stitch
  // untuk rute `/home/settings` (lihat docs/stitch-screens.md).
  static const String profileTitle = 'Profil';

  // Kerangka router (layar sementara T-007).
  /// Pesan isi layar placeholder sebelum layar aslinya dibangun.
  static String routeNotBuiltYet(String title) => '$title belum dibangun.';

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
