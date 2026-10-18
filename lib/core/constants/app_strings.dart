/// Teks antarmuka aplikasi dalam bahasa Indonesia.
///
/// Kerangka ini diisi bertahap: setiap task yang menyentuh UI menambahkan
/// teksnya di bagian sesuai fiturnya, bukan menulis teks langsung di widget.
/// Urutan bagian mengikuti PRD dan `docs/TASKS.md`.
class AppStrings {
  const AppStrings._();

  // Umum.
  static const String appName = 'Libria';
  static const String brandMonogram = 'L';

  // Autentikasi.
  static const String loginTitle = 'Masuk';
  static const String registerTitle = 'Daftar Akun Baru';
  static const String forgotPasswordTitle = 'Lupa Kata Sandi';

  // Autentikasi: layar masuk (T-014).
  static const String loginWelcomeTitle = 'Selamat Datang Kembali';
  static const String loginSubtitle =
      'Masuk untuk melanjutkan petualangan membacamu dan membuka catatan '
      'refleksi pribadimu.';
  static const String loginEmailLabel = 'Email';
  static const String loginEmailHint = 'nama@email.com';
  static const String loginPasswordLabel = 'Kata Sandi';
  static const String loginPasswordHint = 'Masukkan kata sandi';
  static const String loginForgotPassword = 'Lupa Kata Sandi?';
  static const String loginSubmit = 'Masuk ke Akun';
  static const String loginSubmitting = 'Membuka Pustaka...';
  static const String loginOr = 'ATAU MASUK DENGAN';
  static const String loginGoogle = 'Masuk dengan Google';
  static const String loginGoogleLoading = 'Menghubungkan...';
  static const String loginNoAccount = 'Belum memiliki akun Libria?';
  static const String loginRegisterNow = 'Daftar Sekarang';
  static const String loginEmailRequired = 'Email wajib diisi.';
  static const String loginPasswordRequired = 'Kata sandi wajib diisi.';
  static const String loginEmailNotVerified =
      'Email Anda belum terverifikasi. Periksa kotak masuk dan folder spam, '
      'lalu masuk kembali, atau kirim ulang email verifikasi.';
  static const String loginResendVerification = 'Kirim Ulang Email Verifikasi';
  static const String loginProfileSetupError =
      'Tidak dapat menyiapkan data akun. Silakan masuk kembali.';

  /// Pesan setelah email verifikasi berhasil dikirim ulang, contoh:
  /// "Email verifikasi sudah dikirim ulang ke nama@email.com. ...".
  static String loginVerificationResent(String email) =>
      'Email verifikasi sudah dikirim ulang ke $email. Periksa kotak masuk '
      'dan folder spam.';

  // Autentikasi: layar daftar akun baru (T-016).
  static const String registerHeroTitle = 'Buat Akun Baru';
  static const String registerHeroSubtitle =
      'Bergabung dengan ribuan pembaca Libria dan bangun kebiasaan literasi '
      'terbaikmu.';
  static const String registerCommunityStat = '3.420+ Buku Dibaca Pekan Ini';
  static const String registerFullNameLabel = 'Nama Lengkap';
  static const String registerFullNameHint = 'Nama lengkap Anda';
  static const String registerFullNameHelper = 'Wajib diisi';
  static const String registerEmailLabel = 'Alamat Email';
  static const String registerEmailHint = 'nama@email.com';
  static const String registerPasswordLabel = 'Kata Sandi';
  static const String registerPasswordHint = 'Masukkan kata sandi';
  static const String registerPasswordHelper = 'Minimal 8 karakter';
  static const String registerConfirmPasswordLabel = 'Konfirmasi Kata Sandi';
  static const String registerConfirmPasswordHint = 'Ulangi kata sandi';
  static const String registerAgreementPrefix = 'Saya menyetujui ';
  static const String registerAgreementTerms = 'Syarat & Ketentuan';
  static const String registerAgreementConjunction = ' serta ';
  static const String registerAgreementPrivacy = 'Kebijakan Privasi';
  static const String registerAgreementSuffix = ' Libria.';
  static const String registerSubmit = 'DAFTAR SEKARANG';
  static const String registerSubmitting = 'Mendaftarkan Akun...';
  static const String registerOr = 'ATAU DAFTAR DENGAN';
  static const String registerGoogle = 'Daftar dengan Google';
  static const String registerGoogleLoading = 'Menghubungkan...';
  static const String registerHaveAccount = 'Sudah punya akun Libria?';
  static const String registerSignIn = 'Masuk di sini';
  static const String registerBackToLogin = 'Kembali ke Masuk';
  static const String registerFullNameRequired = 'Nama lengkap wajib diisi.';
  static const String registerEmailRequired = 'Email wajib diisi.';
  static const String registerPasswordRequired = 'Kata sandi wajib diisi.';
  static const String registerPasswordTooShort =
      'Kata sandi minimal 8 karakter.';
  static const String registerConfirmPasswordRequired =
      'Konfirmasi kata sandi wajib diisi.';
  static const String registerPasswordMismatch =
      'Konfirmasi kata sandi tidak sama.';
  static const String registerAgreementRequired =
      'Anda harus menyetujui Syarat & Ketentuan serta Kebijakan Privasi '
      'Libria.';
  static const String registerSuccessTitle = 'Akun Berhasil Dibuat';
  static const String registerProfileSetupError =
      'Tidak dapat menyiapkan data akun. Silakan coba lagi.';

  /// Pesan sukses pendaftaran, contoh:
  /// "Email verifikasi sudah dikirim ke nama@email.com. ...".
  static String registerSuccessMessage(String email) =>
      'Email verifikasi sudah dikirim ke $email. Periksa kotak masuk dan '
      'folder spam, lalu masuk setelah email diverifikasi.';

  // Autentikasi: layar lupa kata sandi (T-016).
  static const String forgotPasswordSubtitle =
      'Masukkan email akun Libria Anda. Kami akan mengirimkan tautan untuk '
      'mengatur ulang kata sandi.';
  static const String forgotPasswordEmailLabel = 'Email';
  static const String forgotPasswordEmailHint = 'nama@email.com';
  static const String forgotPasswordSubmit = 'Kirim Tautan Reset';
  static const String forgotPasswordSubmitting = 'Mengirim Tautan...';
  static const String forgotPasswordEmailRequired = 'Email wajib diisi.';
  static const String forgotPasswordSuccessTitle = 'Periksa Kotak Masuk';
  static const String forgotPasswordBackToLogin = 'Kembali ke Masuk';

  /// Pesan hasil yang sama diberikan baik email terdaftar maupun tidak
  /// (FR-A5), contoh: "Tautan reset sudah dikirim ke nama@email.com. ...".
  static String forgotPasswordSuccessMessage(String email) =>
      'Tautan reset sudah dikirim ke $email. Periksa kotak masuk dan folder '
      'spam.';

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

  // Katalog buku: pesan dari BookRepository (T-030).
  static const String bookIsbnDuplicate =
      'Buku dengan ISBN ini sudah terdaftar. Gunakan ISBN lain.';
  static const String bookNotFound = 'Buku tidak ditemukan.';

  // Katalog buku (admin).
  static const String adminDashboardTitle = 'Dashboard Admin';
  static const String adminBooksTitle = 'Kelola Buku';
  static const String adminBookNewTitle = 'Tambah Buku';
  static const String adminBookEditTitle = 'Ubah Buku';
  static const String adminIsbnLogsTitle = 'Log ISBN';

  // Dashboard admin (T-031).
  static const String adminDashboardSubtitle =
      'Ringkasan katalog, laporan, dan pengguna Libria.';
  static const String adminDashboardLoading = 'Memuat ringkasan dashboard...';
  static const String adminDashboardLoadError =
      'Tidak dapat memuat ringkasan dashboard. Periksa koneksi Anda lalu '
      'coba lagi.';
  static const String adminStatBooksLabel = 'Total Buku';
  static const String adminStatOpenReportsLabel = 'Laporan Terbuka';
  static const String adminStatUnhandledIsbnLogsLabel =
      'Log ISBN Belum Ditangani';
  static const String adminStatUsersLabel = 'Total Pengguna';
  static const String adminDashboardMenuTitle = 'Menu';
  static const String adminMenuBooks = 'Kelola Buku';
  static const String adminMenuIsbnLogs = 'Log ISBN';
  static const String adminMenuReports = 'Laporan Komunitas';
  static const String adminMenuEvents = 'Kegiatan';
  static const String adminMenuChallenges = 'Tantangan';
  static const String adminMenuLogout = 'Keluar';
  static const String adminLogoutDialogTitle = 'Keluar dari Akun?';
  static const String adminLogoutDialogMessage =
      'Anda yakin ingin keluar dari akun admin? Anda perlu masuk kembali '
      'untuk mengelola Libria.';
  static const String adminLogoutConfirm = 'Keluar';
  static const String adminLogoutError =
      'Tidak dapat keluar saat ini. Periksa koneksi Anda lalu coba lagi.';

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
