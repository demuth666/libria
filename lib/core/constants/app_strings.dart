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

  // Katalog buku: sampul (T-033).
  static const String bookCoverOffline =
      'Tidak ada koneksi internet. Coba lagi.';
  static const String bookCoverUploadError =
      'Gagal mengunggah sampul. Coba lagi.';

  // Log ISBN: pencatatan pemindaian (T-034b).
  static const String isbnLogUnreadableIsbn =
      'Kode ISBN tidak terbaca. Pindai ulang kode ISBN.';
  static const String isbnLogSignInRequired =
      'Masuk terlebih dahulu untuk mencatat log ISBN.';
  static const String isbnLogNetworkError =
      'Tidak ada koneksi internet. Log ISBN belum tersimpan. Coba lagi.';
  static const String isbnLogPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk mencatat log ISBN. Masuk kembali '
      'lalu coba lagi.';
  static const String isbnLogSaveError = 'Gagal menyimpan log ISBN. Coba lagi.';
  static const String isbnLogListNetworkError =
      'Tidak ada koneksi internet. Log ISBN belum dapat dimuat. Coba lagi.';
  static const String isbnLogListPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk melihat log ISBN. Masuk kembali '
      'lalu coba lagi.';
  static const String isbnLogListError = 'Gagal memuat log ISBN. Coba lagi.';

  // Log ISBN: antrean belum ditangani (T-035a).
  static const String adminIsbnLogsSubtitle =
      'Antrean ISBN yang dipindai pengguna tetapi belum ditemukan di katalog.';
  static const String adminIsbnLogsLoading = 'Memuat log ISBN...';
  static const String adminIsbnLogsLoadError =
      'Tidak dapat memuat log ISBN. Periksa koneksi Anda lalu coba lagi.';
  static const String adminIsbnLogsEmptyTitle = 'Tidak ada log ISBN';
  static const String adminIsbnLogsEmptyMessage =
      'Semua log ISBN sudah ditangani. Pemindaian baru akan muncul di sini.';
  static const String adminIsbnLogsStatusUnhandled = 'Belum ditangani';
  static const String adminIsbnLogsLastScannedUnavailable =
      'Waktu pemindaian tidak tersedia';
  static const String adminIsbnLogsLoadMore = 'Muat Lebih Banyak';
  static const String adminIsbnLogsLoadMoreError =
      'Tidak dapat memuat log ISBN berikutnya. Periksa koneksi Anda lalu '
      'coba lagi.';

  // Log ISBN: aksi antrean (T-035b).
  static const String adminIsbnLogsMarkHandled = 'Tandai ditangani';
  static const String adminIsbnLogsMarkingHandled = 'Menandai...';
  static const String adminIsbnLogsAddBook = 'Tambah buku';
  static const String adminIsbnLogsMarkHandledSuccess =
      'Log ISBN ditandai sebagai sudah ditangani.';
  static const String adminIsbnLogsMarkHandledError =
      'Tidak dapat menandai log ISBN. Periksa koneksi Anda lalu coba lagi.';

  // Log ISBN: penulisan status ditangani (T-035b).
  static const String isbnLogHandleMissingIsbn =
      'ISBN log tidak valid. Muat ulang daftar log lalu coba lagi.';
  static const String isbnLogHandleNetworkError =
      'Tidak ada koneksi internet. Log ISBN belum ditandai. Coba lagi.';
  static const String isbnLogHandlePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menandai log ISBN. Masuk kembali '
      'lalu coba lagi.';
  static const String isbnLogHandleError =
      'Gagal menandai log ISBN. Coba lagi.';

  /// Jumlah pemindaian pada baris log ISBN, contoh: "3 pemindaian".
  static String adminIsbnLogsScanCount(int count) => '$count pemindaian';

  /// Waktu pemindaian terakhir pada baris log ISBN, contoh:
  /// "Terakhir dipindai 21 Oktober 2026, 14.05".
  static String adminIsbnLogsLastScanned(String time) =>
      'Terakhir dipindai $time';

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
  static const String adminNavDashboard = 'Dasbor';
  static const String adminNavBooks = 'Buku';
  static const String adminNavIsbnLogs = 'ISBN';
  static const String adminNavReports = 'Laporan';
  static const String adminNavEvents = 'Kegiatan';
  static const String adminNavChallenges = 'Tantangan';
  static const String adminLogoutLabel = 'Keluar';
  static const String adminLogoutDialogTitle = 'Keluar dari Akun?';
  static const String adminLogoutDialogMessage =
      'Anda yakin ingin keluar dari akun admin? Anda perlu masuk kembali '
      'untuk mengelola Libria.';
  static const String adminLogoutConfirm = 'Keluar';
  static const String adminLogoutError =
      'Tidak dapat keluar saat ini. Periksa koneksi Anda lalu coba lagi.';

  // Katalog buku admin: daftar buku (T-032).
  static const String adminBooksSubtitle =
      'Cari, tambah, ubah, atau hapus buku di katalog Libria.';
  static const String adminBooksAdd = 'Tambah Buku';
  static const String adminBooksSearchLabel = 'Cari buku';
  static const String bookSearchTitleHint = 'Cari berdasarkan judul';
  static const String bookSearchAuthorHint = 'Cari berdasarkan nama penulis';
  static const String bookSearchIsbnHint = 'Cari berdasarkan ISBN';
  static const String bookSearchScopeTitle = 'Judul';
  static const String bookSearchScopeAuthor = 'Penulis';
  static const String bookSearchScopeIsbn = 'ISBN';
  static const String adminBooksClearSearch = 'Hapus pencarian';
  static const String adminBooksLoading = 'Memuat daftar buku...';
  static const String adminBooksLoadError =
      'Tidak dapat memuat daftar buku. Periksa koneksi Anda lalu coba lagi.';
  static const String adminBooksEmptyTitle = 'Belum ada buku';
  static const String adminBooksEmptyMessage =
      'Tambahkan buku pertama untuk mulai mengisi katalog Libria.';
  static const String adminBooksEmptySearchTitle = 'Tidak ada buku yang cocok';
  static const String adminBooksEmptySearchMessage =
      'Coba kata kunci lain atau ubah cakupan pencarian.';
  static const String adminBooksLoadMore = 'Muat Lebih Banyak';
  static const String adminBooksLoadMoreError =
      'Tidak dapat memuat buku berikutnya. Periksa koneksi Anda lalu coba '
      'lagi.';
  static const String adminBooksDeleteDialogTitle = 'Hapus Buku?';
  static const String adminBooksDeleteConfirm = 'Hapus';
  static const String adminBooksDeleteError =
      'Tidak dapat menghapus buku. Periksa koneksi Anda lalu coba lagi.';
  static const String adminBooksDeleteSuccess = 'Buku berhasil dihapus.';

  // Katalog buku admin: formulir tambah dan ubah (T-033).
  static const String adminBookFormSubtitleNew =
      'Lengkapi data buku untuk menambahkannya ke katalog Libria.';
  static const String adminBookFormSubtitleEdit =
      'Perbarui data buku di katalog Libria.';
  static const String adminBookFormSectionDetails = 'Informasi Buku';
  static const String adminBookFormSectionCover = 'Sampul Buku';
  static const String adminBookFormTitleLabel = 'Judul';
  static const String adminBookFormTitleHint = 'Judul buku';
  static const String adminBookFormAuthorLabel = 'Penulis';
  static const String adminBookFormAuthorHint = 'Nama penulis';
  static const String adminBookFormIsbnLabel = 'ISBN';
  static const String adminBookFormIsbnHint = '978-979-973-123-4';
  static const String adminBookFormPublisherLabel = 'Penerbit';
  static const String adminBookFormPublisherHint = 'Nama penerbit';
  static const String adminBookFormYearLabel = 'Tahun Terbit';
  static const String adminBookFormYearHint = '1980';
  static const String adminBookFormPagesLabel = 'Jumlah Halaman';
  static const String adminBookFormPagesHint = '535';
  static const String adminBookFormCategoryLabel = 'Kategori';
  static const String adminBookFormCategoryHint = 'Fiksi, Sastra, Sejarah';
  static const String adminBookFormSynopsisLabel = 'Sinopsis';
  static const String adminBookFormSynopsisHint = 'Ringkasan isi buku';
  static const String adminBookFormCoverHint =
      'Pilih gambar dari galeri atau tempel URL gambar. Gambar galeri '
      'diperkecil ke lebar 800 px dan dikompres otomatis.';
  static const String adminBookFormCoverUrlLabel = 'URL Sampul';
  static const String adminBookFormCoverUrlHint =
      'https://contoh.com/sampul.jpg';
  static const String adminBookFormCoverChoose = 'Pilih Sampul';
  static const String adminBookFormCoverChange = 'Ganti Sampul';
  static const String adminBookFormCoverEmpty = 'Belum ada sampul';
  static const String adminBookFormPickCoverError =
      'Tidak dapat membuka galeri. Silakan coba lagi.';
  static const String adminBookFormSave = 'Simpan Buku';
  static const String adminBookFormSaving = 'Menyimpan...';
  static const String adminBookFormLoading = 'Memuat data buku...';
  static const String adminBookFormLoadError =
      'Tidak dapat memuat data buku. Periksa koneksi Anda lalu coba lagi.';
  static const String adminBookFormNotFoundMessage =
      'Buku mungkin sudah dihapus atau alamatnya tidak valid.';
  static const String adminBookFormBackToList = 'Kembali ke Daftar Buku';
  static const String adminBookFormSaveError =
      'Tidak dapat menyimpan buku. Periksa koneksi Anda lalu coba lagi.';
  static const String adminBookFormUserMissing =
      'Tidak dapat membaca data akun Anda. Silakan masuk kembali.';
  static const String adminBookFormTitleRequired = 'Judul wajib diisi.';
  static const String adminBookFormAuthorRequired = 'Penulis wajib diisi.';
  static const String adminBookFormIsbnRequired = 'ISBN wajib diisi.';
  static const String adminBookFormIsbnInvalid =
      'ISBN harus 10 atau 13 karakter. ISBN-10 boleh berakhir X.';
  static const String adminBookFormYearInvalid =
      'Tahun terbit hanya boleh berisi angka.';
  static const String adminBookFormPagesRequired =
      'Jumlah halaman wajib diisi.';
  static const String adminBookFormPagesInvalid =
      'Jumlah halaman harus bilangan bulat lebih dari 0.';

  /// Tooltip tombol hapus per baris, contoh: 'Hapus buku "Bumi Manusia"'.
  static String adminBooksDeleteTooltip(String title) => 'Hapus buku "$title"';

  /// Pesan konfirmasi hapus buku, contoh:
  /// "Buku "Bumi Manusia" akan dihapus dari katalog Libria. ...".
  static String adminBooksDeleteDialogMessage(String title) =>
      'Buku "$title" akan dihapus dari katalog Libria. Tindakan ini tidak '
      'dapat dibatalkan.';

  /// Label ISBN pada baris buku, contoh: "ISBN 9789799731234".
  static String isbnLabel(String isbn) {
    final String trimmed = isbn.trim();
    if (trimmed.isEmpty) {
      return 'ISBN belum tersedia';
    }
    return 'ISBN $trimmed';
  }

  // Perpustakaan pribadi: pesan dari LibraryRepository (T-040).
  static const String librarySignInRequired =
      'Masuk terlebih dahulu untuk membuka koleksi Anda.';
  static const String libraryEntryNotFound =
      'Buku tidak ditemukan di koleksi Anda. Muat ulang koleksi lalu coba '
      'lagi.';
  static const String libraryInvalidStatus =
      'Status buku tidak valid. Pilih Ingin Dibaca, Sedang Dibaca, atau '
      'Selesai.';
  static const String libraryInvalidPage =
      'Halaman terakhir tidak boleh kurang dari 0.';
  static const String libraryLoadNetworkError =
      'Tidak ada koneksi internet. Koleksi belum dapat dimuat. Coba lagi.';
  static const String libraryLoadPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk membuka koleksi. Masuk kembali '
      'lalu coba lagi.';
  static const String libraryLoadError = 'Gagal memuat koleksi. Coba lagi.';
  static const String libraryAddNetworkError =
      'Tidak ada koneksi internet. Buku belum ditambahkan ke koleksi. Coba '
      'lagi.';
  static const String libraryAddPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menambah buku ke koleksi. Masuk '
      'kembali lalu coba lagi.';
  static const String libraryAddError =
      'Gagal menambahkan buku ke koleksi. Coba lagi.';
  static const String libraryStatusNetworkError =
      'Tidak ada koneksi internet. Status buku belum berubah. Coba lagi.';
  static const String libraryStatusPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk mengubah status buku. Masuk '
      'kembali lalu coba lagi.';
  static const String libraryStatusError =
      'Gagal mengubah status buku. Coba lagi.';
  static const String libraryPageNetworkError =
      'Tidak ada koneksi internet. Halaman terakhir belum tersimpan. Coba '
      'lagi.';
  static const String libraryPagePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menyimpan halaman terakhir. Masuk '
      'kembali lalu coba lagi.';
  static const String libraryPageError =
      'Gagal menyimpan halaman terakhir. Coba lagi.';
  static const String libraryDeleteNetworkError =
      'Tidak ada koneksi internet. Buku belum dihapus dari koleksi. Coba '
      'lagi.';
  static const String libraryDeletePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menghapus buku dari koleksi. Masuk '
      'kembali lalu coba lagi.';
  static const String libraryDeleteError =
      'Gagal menghapus buku dari koleksi. Coba lagi.';

  // Perpustakaan dan beranda (user).
  static const String homeTitle = 'Beranda';
  static const String libraryTitle = 'Koleksi';
  static const String bookDetailTitle = 'Detail Buku';

  // Beranda (T-045).
  static const String homeReaderFallback = 'Pembaca';
  static const String homeReadingLabel = 'Sedang Dibaca';
  static const String homeReadingProgress = 'Kemajuan Baca';
  static const String homeContinueReading = 'Lanjutkan Membaca';
  static const String homeReadingLoading = 'Memuat buku yang sedang dibaca...';
  static const String homeReadingLoadError =
      'Tidak dapat memuat buku yang sedang dibaca. Coba lagi.';
  static const String homeReadingOffline =
      'Buku yang sedang dibaca belum tersedia saat offline.';
  static const String homeReadingStale =
      'Buku yang sedang dibaca tidak dapat diperbarui. Menampilkan data '
      'terakhir.';
  static const String homeReadingEmptyTitle =
      'Belum ada buku yang sedang dibaca';
  static const String homeReadingEmptyMessage =
      'Pilih buku dari koleksi atau katalog untuk mulai membaca.';
  static const String homeChooseBook = 'Pilih Buku';
  static const String homeTodayTitle = 'Ringkasan Hari Ini';
  static const String homeTodayLoading = 'Memuat ringkasan hari ini...';
  static const String homeTodayLoadError =
      'Tidak dapat memuat ringkasan hari ini. Coba lagi.';
  static const String homeTodayNetworkError =
      'Tidak ada koneksi internet. Ringkasan hari ini belum dapat dimuat.';
  static const String homeTodayPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk membaca ringkasan hari ini. Masuk '
      'kembali lalu coba lagi.';
  static const String homeTodaySignInRequired =
      'Masuk terlebih dahulu untuk melihat ringkasan hari ini.';
  static const String homeTodayEmpty =
      'Belum ada sesi membaca hari ini. Mulai sesi untuk mengisi ringkasan.';
  static const String homeTodayOffline =
      'Ringkasan hari ini belum tersedia saat offline.';
  static const String homeMinutesLabel = 'Menit Membaca';
  static const String homePagesLabel = 'Halaman Dibaca';
  static const String homeQuickActionsTitle = 'Aksi Cepat';
  static const String homeStartSession = 'Mulai Sesi';
  static const String homeScanIsbn = 'Scan ISBN';
  static const String homeChallengesTitle = 'Tantangan Aktif';
  static const String homeChallengesEmpty = 'Belum ada tantangan aktif.';
  static const String homeEventsTitle = 'Kegiatan Terdekat';
  static const String homeEventsEmpty = 'Belum ada kegiatan mendatang.';

  /// Sapaan Beranda dengan nama depan pengguna.
  static String homeGreeting(String name) => 'Halo, $name';

  /// Nilai menit membaca pada ringkasan hari ini.
  static String homeMinutesValue(int minutes) => '$minutes mnt';

  /// Nilai halaman yang dibaca pada ringkasan hari ini.
  static String homePagesValue(int pages) => '$pages hlm';

  /// Persentase progres buku yang sedang dibaca.
  static String homeReadingPercent(int percent) => '$percent%';

  // Perpustakaan pribadi: layar Koleksi (T-041).
  static const String libraryLoading = 'Memuat koleksi...';
  static const String libraryAvatarLabel = 'Avatar pengguna';
  static const String librarySegmentReading = 'Sedang Dibaca';
  static const String librarySegmentWant = 'Ingin Dibaca';
  static const String librarySegmentFinished = 'Selesai';
  static const String libraryEmptyTitle = 'Koleksi masih kosong';
  static const String libraryEmptyMessage =
      'Buku yang Anda tambahkan ke rak akan muncul di sini.';
  static const String libraryEmptyReadingTitle =
      'Belum ada buku di rak Sedang Dibaca';
  static const String libraryEmptyReadingMessage =
      'Buku yang sedang Anda baca akan muncul di sini.';
  static const String libraryEmptyWantTitle =
      'Belum ada buku di rak Ingin Dibaca';
  static const String libraryEmptyWantMessage =
      'Simpan buku yang ingin Anda baca agar mudah ditemukan nanti.';
  static const String libraryEmptyFinishedTitle =
      'Belum ada buku di rak Selesai';
  static const String libraryEmptyFinishedMessage =
      'Buku yang sudah selesai dibaca akan muncul di sini.';
  static const String libraryOfflineTitle = 'Koleksi belum dapat dimuat';
  static const String libraryOfflineMessage =
      'Tidak ada koneksi internet dan belum ada data tersimpan. Sambungkan '
      'perangkat ke internet lalu coba lagi.';
  static const String libraryStaleMessage =
      'Koleksi tidak dapat diperbarui. Menampilkan data terakhir.';
  static const String libraryQuote =
      '“Buku adalah pesawat terbang, kereta api, dan jalan raya. Buku adalah '
      'tujuan sekaligus perjalanan.”';
  static const String libraryQuoteAuthor = '— Anna Quindlen';

  /// Tanggal selesai membaca, contoh: "Selesai 12 Maret 2026".
  static String libraryFinishedOn(String date) => 'Selesai $date';

  // Pencarian katalog (T-042).
  static const String catalogSearchTitle = 'Cari Katalog';
  static const String catalogSearchBack = 'Kembali';
  static const String catalogSearchFieldLabel = 'Cari buku';
  static const String catalogSearchFieldHint = 'Ketik kata kunci';
  static const String catalogSearchInitialTitle =
      'Ketik judul, penulis, atau ISBN';
  static const String catalogSearchInitialMessage =
      'Hasil pencarian akan muncul di sini.';
  static const String catalogSearchClear = 'Hapus pencarian';
  static const String catalogSearchLoading = 'Mencari buku...';
  static const String catalogSearchEmptyTitle = 'Tidak ada buku yang cocok';
  static const String catalogSearchEmptyMessage =
      'Coba kata kunci lain atau ubah cakupan pencarian.';
  static const String catalogSearchError =
      'Tidak dapat mencari buku. Periksa koneksi Anda lalu coba lagi.';
  static const String catalogSearchOfflineTitle =
      'Pencarian belum dapat dimuat';
  static const String catalogSearchOfflineMessage =
      'Tidak ada koneksi internet dan hasil pencarian ini belum tersimpan. '
      'Sambungkan perangkat ke internet lalu coba lagi.';
  static const String catalogSearchLoadMore = 'Muat Lebih Banyak';
  static const String catalogSearchLoadMoreError =
      'Tidak dapat memuat hasil berikutnya. Periksa koneksi Anda lalu coba '
      'lagi.';

  // Detail buku (T-043).
  static const String bookDetailLoading = 'Memuat detail buku...';
  static const String bookDetailBack = 'Kembali';
  static const String bookDetailNotFoundTitle = 'Buku tidak ditemukan';
  static const String bookDetailNotFoundMessage =
      'Buku mungkin sudah dihapus atau alamatnya tidak valid.';
  static const String bookDetailOfflineTitle = 'Detail buku belum dapat dimuat';
  static const String bookDetailOfflineMessage =
      'Tidak ada koneksi internet dan buku ini belum tersimpan. Sambungkan '
      'perangkat ke internet lalu coba lagi.';
  static const String bookDetailLoadError =
      'Tidak dapat memuat detail buku. Periksa koneksi Anda lalu coba lagi.';
  static const String bookDetailStartSession = 'Mulai Sesi';
  static const String bookDetailSectionDetails = 'Informasi Buku';
  static const String bookDetailSectionSynopsis = 'Sinopsis';
  static const String bookDetailSectionShelf = 'Rak Saya';
  static const String bookDetailIsbnLabel = 'ISBN';
  static const String bookDetailPublisherLabel = 'Penerbit';
  static const String bookDetailYearLabel = 'Tahun Terbit';
  static const String bookDetailPagesLabel = 'Jumlah Halaman';
  static const String bookDetailCategoryLabel = 'Kategori';
  static const String bookDetailUnavailable = 'Belum tersedia';

  /// Kredit penulis pada layar detail, contoh: "oleh Pramoedya Ananta Toer".
  static String bookDetailByAuthor(String author) => 'oleh $author';

  static const String bookDetailAddHint =
      'Buku ini belum ada di rak Anda. Tambahkan untuk mulai membaca dan '
      'mencatat progres.';
  static const String bookDetailShelfLoading = 'Memuat status rak...';
  static const String bookDetailShelfLoadError =
      'Tidak dapat memuat status rak. Coba lagi.';
  static const String bookDetailAddToLibrary = 'Tambah ke Koleksi';
  static const String bookDetailStatusLabel = 'Status baca';
  static const String bookDetailPageLabel = 'Halaman Terakhir';
  static const String bookDetailPageSave = 'Simpan Halaman';
  static const String bookDetailPageRequired = 'Halaman terakhir wajib diisi.';
  static const String bookDetailPageInvalid =
      'Masukkan bilangan bulat untuk halaman terakhir.';
  static const String bookDetailPageNegative =
      'Halaman terakhir tidak boleh kurang dari 0.';
  static const String bookDetailPageUnavailable =
      'Jumlah halaman buku belum tersedia, sehingga progres halaman belum '
      'dapat disimpan.';
  static const String bookDetailSaving = 'Menyimpan...';

  /// Petunjuk isian halaman terakhir, contoh: "0 sampai 320".
  static String bookDetailPageHint(int totalPages) => '0 sampai $totalPages';

  /// Pesan halaman melebihi total, contoh: "Halaman terakhir tidak boleh
  /// melebihi 320.".
  static String bookDetailPageExceeds(int totalPages) =>
      'Halaman terakhir tidak boleh melebihi $totalPages.';

  // Pemindaian ISBN (T-044).
  static const String isbnScanTitle = 'Pindai ISBN';
  static const String isbnScanBack = 'Kembali';
  static const String isbnScanTorchOn = 'Nyalakan lampu';
  static const String isbnScanTorchOff = 'Matikan lampu';
  static const String isbnScanHintTitle = 'Arahkan kamera ke barcode ISBN';
  static const String isbnScanHintMessage =
      'Letakkan barcode di bagian belakang buku di dalam bingkai. '
      'Pemindaian berjalan otomatis.';
  static const String isbnScanPreparingCamera = 'Menyiapkan kamera...';
  static const String isbnScanSearchingTitle = 'Mencari buku...';
  static const String isbnScanNotFoundTitle = 'Buku tidak ditemukan';
  static const String isbnScanInvalidTitle = 'ISBN tidak valid';
  static const String isbnScanInvalidMessage =
      'Barcode yang terbaca bukan ISBN yang valid. Arahkan kamera ke barcode '
      'ISBN di belakang buku.';
  static const String isbnScanErrorTitle = 'Pemindaian gagal';
  static const String isbnScanLookupNetworkError =
      'Tidak ada koneksi internet. Pemindaian ISBN memerlukan koneksi untuk '
      'buku yang belum pernah dimuat.';
  static const String isbnScanLookupPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk mencari buku. Masuk kembali lalu '
      'coba lagi.';
  static const String isbnScanLookupError =
      'Tidak dapat mencari buku saat ini. Coba lagi.';
  static const String isbnScanLogError = 'Gagal menyimpan log ISBN. Coba lagi.';
  static const String isbnScanLogRecorded =
      'ISBN sudah dicatat di Log ISBN agar admin dapat menambahkannya ke '
      'katalog.';
  static const String isbnScanAgain = 'Pindai Ulang';
  static const String isbnScanClose = 'Tutup';
  static const String isbnScanPermissionDeniedTitle = 'Izin kamera diperlukan';
  static const String isbnScanPermissionDeniedMessage =
      'Libria memerlukan izin kamera untuk memindai ISBN. Izinkan akses '
      'kamera untuk Libria di pengaturan perangkat, lalu coba lagi.';
  static const String isbnScanCameraUnsupportedTitle = 'Kamera tidak tersedia';
  static const String isbnScanCameraUnsupportedMessage =
      'Perangkat ini tidak memiliki kamera yang dapat dipakai untuk memindai '
      'ISBN.';
  static const String isbnScanCameraErrorTitle = 'Kamera tidak dapat dibuka';
  static const String isbnScanCameraErrorMessage =
      'Periksa izin kamera lalu coba lagi.';

  /// Pesan saat katalog sedang dicari, contoh:
  /// "Memeriksa katalog untuk ISBN 9789799731234...".
  static String isbnScanSearchingMessage(String isbn) =>
      'Memeriksa katalog untuk ISBN $isbn...';

  /// Pesan ISBN tidak ditemukan, contoh:
  /// "Buku dengan ISBN 9789799731234 tidak ditemukan.".
  static String isbnScanNotFoundMessage(String isbn) =>
      'Buku dengan ISBN $isbn tidak ditemukan.';

  // Sesi membaca.
  static const String sessionNavLabel = 'Sesi Baca';
  static const String sessionSetupTitle = 'Atur Sesi';
  static const String sessionSetupBack = 'Kembali';
  static const String sessionSetupIntro =
      'Pilih buku, tentukan target durasi, lalu mulai sesi membaca. Timer '
      'tetap berjalan saat layar dimatikan.';
  static const String sessionSetupSelectedBook = 'Buku Dipilih';
  static const String sessionSetupNoBookTitle = 'Belum ada buku dipilih';
  static const String sessionSetupNoBookMessage =
      'Pilih buku dari koleksi atau katalog, atau pindai ISBN untuk memilih '
      'dengan cepat.';
  static const String sessionSetupBookLoading = 'Memuat buku...';
  static const String sessionSetupBookLoadError =
      'Tidak dapat memuat buku. Periksa koneksi Anda lalu coba lagi.';
  static const String sessionSetupPickBook = 'Pilih Buku';
  static const String sessionSetupSourceLibrary = 'Koleksi';
  static const String sessionSetupSourceCatalog = 'Katalog';
  static const String sessionSetupScanIsbn = 'Pindai ISBN';
  static const String sessionSetupWillAdd =
      'Buku ini belum ada di rak. Saat sesi dimulai, buku akan ditambahkan ke '
      'rak Sedang Dibaca.';
  static const String sessionSetupInShelf = 'Sudah ada di rak';
  static const String sessionSetupOpenCatalog = 'Buka Katalog';
  static const String sessionSetupLibraryEmptyMessage =
      'Belum ada buku di rak Anda. Buka katalog untuk memilih buku dan '
      'mulai membaca.';
  static const String sessionSetupCatalogLoading = 'Memuat katalog...';
  static const String sessionSetupCatalogError =
      'Tidak dapat memuat katalog. Periksa koneksi Anda lalu coba lagi.';
  static const String sessionSetupCatalogEmptyTitle = 'Katalog masih kosong';
  static const String sessionSetupCatalogEmptyMessage =
      'Belum ada buku yang dapat dipilih dari katalog.';
  static const String sessionSetupCatalogOfflineTitle =
      'Katalog belum dapat dimuat';
  static const String sessionSetupCatalogOfflineMessage =
      'Tidak ada koneksi internet dan katalog belum tersimpan. Sambungkan '
      'perangkat ke internet lalu coba lagi.';
  static const String sessionSetupTargetLabel = 'Target (menit)';
  static const String sessionSetupTargetHint = '30';
  static const String sessionSetupTargetRequired = 'Isi target durasi membaca.';
  static const String sessionSetupTargetInvalid =
      'Target harus berupa angka menit.';
  static const String sessionSetupTargetPositive =
      'Target harus lebih dari 0 menit.';
  static const String sessionSetupStart = 'Mulai Sesi';
  static const String sessionSetupStarting = 'Memulai...';
  static const String sessionSetupStartError =
      'Tidak dapat memulai sesi. Periksa koneksi Anda lalu coba lagi.';
  static const String sessionSetupUntitledBook = 'Buku tanpa judul';
  static const String sessionRunTitle = 'Sesi Membaca';
  static const String sessionFinishTitle = 'Selesai Sesi';
  static const String sessionActiveLoadError =
      'Sesi membaca yang tersimpan tidak dapat dibuka. Coba lagi.';
  static const String sessionActiveSaveError =
      'Sesi membaca tidak dapat disimpan ke perangkat. Periksa ruang '
      'penyimpanan lalu coba lagi.';
  static const String sessionAlreadyActive =
      'Masih ada sesi membaca yang aktif. Selesaikan sesi itu sebelum memulai '
      'sesi baru.';

  // Sesi membaca: layar timer (T-055).
  static const String sessionRunLoading = 'Memuat sesi membaca...';
  static const String sessionRunLoadError =
      'Sesi membaca tidak dapat dimuat. Coba lagi.';
  static const String sessionRunNoSessionTitle = 'Belum ada sesi aktif';
  static const String sessionRunNoSessionMessage =
      'Pilih buku dan target durasi untuk memulai sesi membaca.';
  static const String sessionRunOpenSetup = 'Atur Sesi';
  static const String sessionRunElapsedLabel = 'Waktu membaca';
  static const String sessionRunStatusRunning = 'Sedang membaca';
  static const String sessionRunStatusPaused = 'Dijeda';
  static const String sessionRunStatusTargetReached = 'Target tercapai';
  static const String sessionRunStatusFinished = 'Sesi selesai';
  static const String sessionRunBackgroundHint =
      'Timer tetap berjalan saat layar dimatikan.';
  static const String sessionRunPausedMessage =
      'Timer dijeda. Waktu tidak bertambah sampai kamu melanjutkan.';
  static const String sessionRunTargetReachedMessage =
      'Timer berhenti tepat di target. Catat halaman terakhir untuk menyimpan '
      'sesi.';
  static const String sessionRunFinishedMessage =
      'Sesi sudah selesai. Lanjutkan untuk mencatat halaman terakhir.';
  static const String sessionRunPause = 'Jeda Sesi';
  static const String sessionRunResume = 'Lanjutkan';
  static const String sessionRunFinish = 'Selesai';
  static const String sessionRunFinishing = 'Menyelesaikan...';
  static const String sessionRunContinue = 'Lanjut ke Penyelesaian';
  static const String sessionRunActionError =
      'Tidak dapat memperbarui sesi. Coba lagi.';
  static const String sessionRunProgressSemantics = 'Progres sesi membaca';
  static const String sessionRunProgressLabel = 'Progres Sesi';
  static const String sessionRunTargetLabel = 'Target Durasi Sesi';
  static const String sessionRunTargetFixed = 'Tetap';
  static const String sessionRunMinutesUnit = 'menit';

  /// Target durasi, contoh: "Target 00:30:00".
  static String sessionRunTarget(String target) => 'Target $target';

  /// Pil target pada timer, contoh: "Target: 45 Menit".
  static String sessionRunTargetPill(int minutes) => 'Target: $minutes Menit';

  /// Keterangan target pada ringkasan progres, contoh: "dari target 45 menit".
  static String sessionRunTargetSummary(int minutes) =>
      'dari target $minutes menit';

  /// Progres terhadap target, contoh: "50% dari target".
  static String sessionRunProgress(int percent) => '$percent% dari target';

  /// Persentase progres, contoh: "50%".
  static String sessionRunPercent(int percent) => '$percent%';

  /// Progres halaman buku, contoh: "Halaman 45 dari 100".
  static String sessionRunPage(int currentPage, int totalPages) =>
      'Halaman $currentPage dari $totalPages';

  /// Sisa waktu menuju target, contoh: "Sisa 00:15:00".
  static String sessionRunRemaining(String remaining) => 'Sisa $remaining';

  /// Label aksesibilitas angka timer, contoh:
  /// "Waktu membaca 00:05:00 dari target 00:30:00".
  static String sessionRunTimerSemantics(String elapsed, String target) =>
      'Waktu membaca $elapsed dari target $target';

  /// Status rak pada kartu buku terpilih, contoh: "Di rak: Sedang Dibaca".
  static String sessionSetupShelfStatus(String status) => 'Di rak: $status';

  // Sesi membaca: penyelesaian sesi (T-056).
  static const String sessionFinishLoading = 'Memuat sesi membaca...';
  static const String sessionFinishLoadError =
      'Sesi membaca tidak dapat dimuat. Coba lagi.';
  static const String sessionFinishNoSessionTitle =
      'Belum ada sesi untuk diselesaikan';
  static const String sessionFinishNoSessionMessage =
      'Selesaikan sesi dari layar timer, lalu catat halaman terakhir di sini.';
  static const String sessionFinishOpenSetup = 'Atur Sesi';
  static const String sessionFinishRunningTitle = 'Sesi masih berjalan';
  static const String sessionFinishRunningMessage =
      'Selesaikan timer terlebih dahulu agar halaman terakhir dapat dicatat.';
  static const String sessionFinishOpenRun = 'Kembali ke Timer';
  static const String sessionFinishBookMissingTitle =
      'Buku tidak ada di koleksi';
  static const String sessionFinishBookMissingMessage =
      'Buku sesi ini tidak ditemukan di rak. Tambahkan kembali buku dari '
      'katalog agar progres dapat disimpan.';
  static const String sessionFinishEntryLoading = 'Memuat status buku...';
  static const String sessionFinishEntryLoadError =
      'Status buku di rak tidak dapat dimuat. Coba lagi.';
  static const String sessionFinishIntro =
      'Catat halaman terakhir yang Anda baca untuk menyimpan sesi ini.';
  static const String sessionFinishSummaryTitle = 'Ringkasan Sesi';
  static const String sessionFinishDurationLabel = 'Durasi';
  static const String sessionFinishTargetLabel = 'Target';
  static const String sessionFinishStartPageLabel = 'Halaman Awal';
  static const String sessionFinishTargetReached = 'Target tercapai';
  static const String sessionFinishPageSection = 'Progres Baca';
  static const String sessionFinishPageLabel = 'Halaman Terakhir';
  static const String sessionFinishPageRequired =
      'Halaman terakhir wajib diisi.';
  static const String sessionFinishPageInvalid =
      'Masukkan bilangan bulat untuk halaman terakhir.';
  static const String sessionFinishPageNegative =
      'Halaman terakhir tidak boleh kurang dari 0.';
  static const String sessionFinishPageUnavailable =
      'Jumlah halaman buku belum tersedia, sehingga progres halaman belum '
      'dapat disimpan.';
  static const String sessionFinishSave = 'Simpan Sesi';
  static const String sessionFinishSaving = 'Menyimpan...';
  static const String sessionFinishSaveError =
      'Sesi tidak dapat disimpan. Coba lagi.';
  static const String sessionFinishSaveNetworkError =
      'Tidak ada koneksi internet. Sesi akan dikirim saat koneksi tersedia.';
  static const String sessionFinishSavePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menyimpan sesi membaca. Masuk '
      'kembali lalu coba lagi.';
  static const String sessionFinishSignInRequired =
      'Masuk kembali untuk menyimpan sesi membaca.';
  static const String sessionFinishEntryNotFound =
      'Buku sesi ini tidak ditemukan di koleksi.';
  static const String sessionFinishNotFinished =
      'Sesi belum selesai sehingga belum dapat disimpan.';
  static const String sessionFinishSuccessTitle = 'Sesi Tersimpan';
  static const String sessionFinishSuccessFinished =
      'Halaman terakhir mencapai total, jadi buku sudah ditandai Selesai.';
  static const String sessionFinishHome = 'Kembali ke Beranda';
  static const String sessionFinishJournalOfferTitle = 'Tulis Jurnal Refleksi';
  static const String sessionFinishJournalOfferMessage =
      'Simpan refleksi sesi ini agar terhubung dengan buku dan sesi yang baru '
      'selesai.';
  static const String sessionFinishWriteJournal = 'Tulis Jurnal';
  static const String sessionFinishSkipJournal = 'Lewati';
  static const String sessionFinishClearWarning =
      'Sesi sudah tersimpan, tetapi sesi aktif di perangkat belum terhapus. '
      'Buka layar timer untuk membereskannya.';

  /// Petunjuk isian halaman terakhir, contoh: "40 sampai 320".
  static String sessionFinishPageHint(int startPage, int totalPages) =>
      '$startPage sampai $totalPages';

  /// Keterangan halaman awal sesi, contoh:
  /// "Halaman awal 40 dari 320.".
  static String sessionFinishStartPage(int startPage, int totalPages) =>
      'Halaman awal $startPage dari $totalPages.';

  /// Pesan halaman sebelum halaman awal, contoh:
  /// "Halaman terakhir tidak boleh kurang dari halaman awal 40.".
  static String sessionFinishPageBeforeStart(int startPage) =>
      'Halaman terakhir tidak boleh kurang dari halaman awal $startPage.';

  /// Pesan halaman melebihi total, contoh:
  /// "Halaman terakhir tidak boleh melebihi 320.".
  static String sessionFinishPageExceeds(int totalPages) =>
      'Halaman terakhir tidak boleh melebihi $totalPages.';

  /// Jumlah halaman sesi, contoh: "40 sampai 75".
  static String sessionFinishPagesValue(int startPage, int endPage) =>
      '$startPage sampai $endPage';

  /// Ringkasan sesi pada layar berhasil, contoh:
  /// "Sesi 00:20:00 tersimpan dengan 35 halaman tercatat.".
  static String sessionFinishSuccessMessage(String duration, int pages) =>
      'Sesi $duration tersimpan dengan $pages halaman tercatat.';

  /// Keterangan progres buku setelah sesi, contoh:
  /// "Progres buku diperbarui ke halaman 75.".
  static String sessionFinishProgressUpdated(int endPage) =>
      'Progres buku diperbarui ke halaman $endPage.';

  // Sesi membaca: notifikasi layanan latar belakang (T-053).
  static const String sessionNotificationChannelName = 'Sesi Membaca';
  static const String sessionNotificationChannelDescription =
      'Timer sesi membaca tetap berjalan saat layar dimatikan.';
  static const String sessionNotificationIdle = 'Sesi membaca';
  static const String sessionNotificationRunning = 'Sedang membaca';
  static const String sessionNotificationPaused = 'Dijeda';
  static const String sessionNotificationTargetReached = 'Target tercapai';
  static const String sessionNotificationFinished = 'Sesi selesai';

  /// Teks notifikasi dengan waktu berjalan, contoh:
  /// "Sedang membaca • 00:12:34".
  static String sessionNotificationElapsed(String status, String elapsed) {
    return '$status • $elapsed';
  }

  /// Teks notifikasi dengan waktu berjalan dan target, contoh:
  /// "Sedang membaca • 00:12:34 dari target 00:25:00".
  static String sessionNotificationProgress(
    String status,
    String elapsed,
    String target,
  ) {
    return '$status • $elapsed dari target $target';
  }

  // Sesi membaca: alarm target tercapai (T-054).
  static const String sessionAlarmChannelName = 'Target Sesi Membaca';
  static const String sessionAlarmChannelDescription =
      'Getar dan notifikasi saat target sesi membaca tercapai.';
  static const String sessionAlarmNotificationTitle = 'Target membaca tercapai';

  /// Isi notifikasi alarm, contoh:
  /// "Sesi "Bumi Manusia" mencapai target 00:25:00. Timer berhenti."
  static String sessionAlarmNotificationBody(String bookTitle, String target) {
    return 'Sesi "$bookTitle" mencapai target $target. Timer berhenti.';
  }

  // Jurnal dan ulasan.
  static const String journalTitle = 'Jurnal';
  static const String journalNewTitle = 'Jurnal Baru';

  // Jurnal refleksi (T-060).
  static const String journalEditTitle = 'Ubah Jurnal';
  static const String journalBack = 'Kembali';
  static const String journalAddAction = 'Tulis Jurnal';
  static const String journalFilterAll = 'Semua Buku';
  static const String journalLoading = 'Memuat jurnal...';
  static const String journalLoadError =
      'Tidak dapat memuat jurnal. Coba lagi.';
  static const String journalLoadNetworkError =
      'Tidak ada koneksi internet. Jurnal yang tersimpan belum dapat dimuat. '
      'Coba lagi.';
  static const String journalLoadPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk melihat jurnal. Masuk kembali lalu '
      'coba lagi.';
  static const String journalSignInRequired =
      'Masuk terlebih dahulu untuk melihat jurnal.';
  static const String journalEmptyTitle = 'Belum ada jurnal';
  static const String journalEmptyMessage =
      'Tulis refleksi tentang buku yang sedang atau sudah dibaca.';
  static const String journalBookEmptyMessage =
      'Belum ada jurnal untuk buku ini.';
  static const String journalOfflineTitle = 'Jurnal belum dapat dimuat';
  static const String journalOfflineMessage =
      'Tidak ada koneksi internet dan jurnal belum tersimpan di perangkat. '
      'Sambungkan internet lalu coba lagi.';
  static const String journalLoadMore = 'Muat Lebih Banyak';
  static const String journalLoadingMore = 'Memuat jurnal lainnya...';
  static const String journalLoadMoreError =
      'Jurnal belum dapat diperbarui. Coba lagi.';
  static const String journalDateUnavailable = 'Tanggal tidak tersedia';

  static const String journalBookLabel = 'Buku';
  static const String journalBookRequired = 'Pilih buku terlebih dahulu.';
  static const String journalContentLabel = 'Isi Jurnal';
  static const String journalContentHint =
      'Tulis refleksi Anda tentang buku ini...';
  static const String journalContentRequired = 'Isi jurnal tidak boleh kosong.';
  static const String journalSave = 'Simpan Jurnal';
  static const String journalSaving = 'Menyimpan...';
  static const String journalSaveSuccess = 'Jurnal berhasil disimpan.';
  static const String journalUpdateSuccess = 'Jurnal berhasil diperbarui.';
  static const String journalSaveError = 'Gagal menyimpan jurnal. Coba lagi.';
  static const String journalSaveNetworkError =
      'Tidak ada koneksi internet. Jurnal belum tersimpan. Coba lagi.';
  static const String journalSavePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menyimpan jurnal. Masuk kembali '
      'lalu coba lagi.';
  static const String journalNotFound =
      'Jurnal tidak ditemukan. Mungkin sudah dihapus.';
  static const String journalLoadFormError =
      'Tidak dapat memuat jurnal. Coba lagi.';

  static const String journalDeleteDialogTitle = 'Hapus Jurnal';
  static const String journalDeleteDialogMessage =
      'Jurnal ini akan dihapus secara permanen. Lanjutkan?';
  static const String journalDeleteConfirm = 'Hapus';
  static const String journalDeleteTooltip = 'Hapus jurnal';
  static const String journalDeleteSuccess = 'Jurnal berhasil dihapus.';
  static const String journalDeleteError = 'Gagal menghapus jurnal. Coba lagi.';
  static const String journalDeleteNetworkError =
      'Tidak ada koneksi internet. Jurnal belum dihapus. Coba lagi.';
  static const String journalDeletePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menghapus jurnal. Masuk kembali '
      'lalu coba lagi.';

  static const String journalLibraryEmptyTitle = 'Belum ada buku di koleksi';
  static const String journalLibraryEmptyMessage =
      'Tambahkan buku ke koleksi terlebih dahulu untuk menulis jurnal.';
  static const String journalLibraryLoading = 'Memuat koleksi...';
  static const String journalOpenLibrary = 'Buka Koleksi';

  // Ulasan buku (T-062).
  static const String reviewSectionTitle = 'Ulasan Pembaca';
  static const String reviewMyTitle = 'Ulasan Anda';
  static const String reviewLoading = 'Memuat ulasan...';
  static const String reviewLoadMore = 'Muat Lebih Banyak';
  static const String reviewLoadingMore = 'Memuat ulasan lainnya...';
  static const String reviewLoadMoreError =
      'Ulasan belum dapat diperbarui. Coba lagi.';
  static const String reviewLoadError = 'Tidak dapat memuat ulasan. Coba lagi.';
  static const String reviewLoadNetworkError =
      'Tidak ada koneksi internet. Ulasan yang tersimpan belum dapat dimuat. '
      'Coba lagi.';
  static const String reviewLoadPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk melihat ulasan. Masuk kembali lalu '
      'coba lagi.';
  static const String reviewSignInRequired =
      'Masuk terlebih dahulu untuk melihat ulasan.';
  static const String reviewListEmptyTitle = 'Belum ada ulasan';
  static const String reviewListEmptyMessage =
      'Jadilah pembaca pertama yang memberi rating dan ulasan untuk buku ini.';
  static const String reviewRatingLabel = 'Rating Anda';
  static const String reviewRatingRequired = 'Pilih rating 1 sampai 5.';
  static const String reviewTextLabel = 'Ulasan';
  static const String reviewTextHint =
      'Tulis pendapat Anda tentang buku ini...';
  static const String reviewTextRequired = 'Ulasan tidak boleh kosong.';
  static const String reviewSave = 'Simpan Ulasan';
  static const String reviewUpdate = 'Perbarui Ulasan';
  static const String reviewDelete = 'Hapus Ulasan';
  static const String reviewSaved = 'Ulasan berhasil disimpan.';
  static const String reviewSaveError = 'Gagal menyimpan ulasan. Coba lagi.';
  static const String reviewSaveNetworkError =
      'Tidak ada koneksi internet. Ulasan belum tersimpan. Coba lagi.';
  static const String reviewSavePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menyimpan ulasan. Masuk kembali '
      'lalu coba lagi.';
  static const String reviewBookNotFound =
      'Buku tidak ditemukan. Mungkin sudah dihapus.';
  static const String reviewNotWritten =
      'Ulasan tidak ditemukan. Mungkin sudah dihapus.';
  static const String reviewDeleteDialogTitle = 'Hapus Ulasan';
  static const String reviewDeleteDialogMessage =
      'Ulasan Anda untuk buku ini akan dihapus secara permanen. Lanjutkan?';
  static const String reviewDeleteConfirm = 'Hapus';
  static const String reviewDeleteSuccess = 'Ulasan berhasil dihapus.';
  static const String reviewDeleteError = 'Gagal menghapus ulasan. Coba lagi.';
  static const String reviewDeleteNetworkError =
      'Tidak ada koneksi internet. Ulasan belum dihapus. Coba lagi.';
  static const String reviewDeletePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menghapus ulasan. Masuk kembali '
      'lalu coba lagi.';
  static const String reviewDateUnavailable = 'Tanggal tidak tersedia';
  static const String reviewReaderFallback = 'Pembaca Libria';

  /// Jumlah ulasan sebuah buku, contoh: "12 ulasan".
  static String reviewCount(int count) => '$count ulasan';

  /// Rata-rata rating dengan satu angka desimal dan koma desimal, contoh:
  /// "4,5".
  static String reviewAverageValue(double average) {
    return average.clamp(0, 5).toStringAsFixed(1).replaceAll('.', ',');
  }

  /// Label aksesibilitas tombol bintang, contoh: "Beri rating 4 dari 5".
  static String reviewRatingSemantics(int rating) =>
      'Beri rating $rating dari 5';

  // Statistik dan laporan.
  static const String statsTitle = 'Statistik';
  static const String reportTitle = 'Laporan';
  static const String statsSessionHistoryAction = 'Lihat Riwayat Sesi';

  // Layar Statistik (T-071).
  static const String statsLoading = 'Memuat statistik...';
  static const String statsLoadError =
      'Tidak dapat memuat statistik. Coba lagi.';
  static const String statsNetworkError =
      'Tidak ada koneksi internet. Statistik yang tersimpan di perangkat '
      'belum dapat dimuat. Coba lagi.';
  static const String statsPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk melihat statistik. Masuk kembali '
      'lalu coba lagi.';
  static const String statsSignInRequired =
      'Masuk terlebih dahulu untuk melihat statistik.';
  static const String statsStaleNotice =
      'Statistik belum dapat diperbarui. Data terakhir tetap ditampilkan.';
  static const String statsSummaryTitle = 'Ringkasan Membaca';
  static const String statsSummarySubtitle = 'Sepanjang waktu';
  static const String statsTotalMinutesLabel = 'Total Menit';
  static const String statsTotalPagesLabel = 'Total Halaman';
  static const String statsFinishedBooksLabel = 'Buku Selesai';
  static const String statsStreakLabel = 'Hari Beruntun';
  static const String statsChartTitle = 'Aktivitas Membaca';
  static const String statsChartSubtitle = 'Menit membaca per hari';
  static const String statsChartEmptyTitle = 'Belum ada sesi membaca';
  static const String statsChartEmptyMessage =
      'Grafik akan muncul setelah Anda menyelesaikan sesi membaca pertama.';
  static const String statsRangeLabel = 'Rentang';
  static const String statsRange7 = '7 Hari';
  static const String statsRange30 = '30 Hari';

  /// Angka tertinggi pada grafik, contoh: "Tertinggi: 70 menit".
  static String statsChartHighest(int minutes) => 'Tertinggi: $minutes menit';

  /// Keterangan satu batang grafik, contoh: "23 Okt: 45 menit".
  static String statsChartTooltip(String date, int minutes) {
    return '$date: $minutes menit';
  }

  /// Label aksesibilitas grafik, contoh: "Grafik 7 hari terakhir, total 320
  /// menit".
  static String statsChartSemantics(int days, int totalMinutes) {
    return 'Grafik $days hari terakhir, total $totalMinutes menit';
  }

  // Laporan PDF (T-072).
  static const String reportPdfTitle = 'Laporan Membaca';
  static const String reportPdfEyebrow = 'LAPORAN MEMBACA';
  static const String reportPdfSubtitle =
      'Ringkasan kebiasaan membaca pada rentang tanggal yang dipilih.';
  static const String reportPdfSubject =
      'Ringkasan aktivitas membaca pengguna Libria.';
  static const String reportPdfNameLabel = 'Nama';
  static const String reportPdfPeriodLabel = 'Periode';
  static const String reportPdfSummaryTitle = 'Ringkasan';
  static const String reportPdfTotalMinutesLabel = 'Total Menit';
  static const String reportPdfTotalPagesLabel = 'Total Halaman';
  static const String reportPdfFinishedBooksLabel = 'Buku Selesai';
  static const String reportPdfSessionsLabel = 'Sesi Membaca';
  static const String reportPdfBooksTitle = 'Buku yang Dibaca';
  static const String reportPdfBooksEmpty =
      'Belum ada buku yang dibaca pada rentang ini.';
  static const String reportPdfDaysTitle = 'Ringkasan Harian';
  static const String reportPdfDaysEmpty =
      'Belum ada sesi membaca pada rentang ini.';
  static const String reportPdfColumnBook = 'Buku';
  static const String reportPdfColumnAuthor = 'Penulis';
  static const String reportPdfColumnStatus = 'Status';
  static const String reportPdfColumnMinutes = 'Menit';
  static const String reportPdfColumnPages = 'Halaman';
  static const String reportPdfColumnSessions = 'Sesi';
  static const String reportPdfColumnDate = 'Tanggal';
  static const String reportPdfStatusFinished = 'Selesai';
  static const String reportPdfStatusReading = 'Sedang dibaca';
  static const String reportPdfReaderFallback = 'Pembaca Libria';
  static const String reportPdfAuthorUnavailable = 'Penulis tidak tercatat';
  static const String reportPdfUnknownBook = 'Buku tanpa judul';
  static const String reportPdfFooter = 'Libria - Laporan Membaca';

  /// Rentang tanggal laporan, contoh: "1 Oktober 2026 - 31 Oktober 2026".
  static String reportPdfPeriod(String start, String end) => '$start - $end';

  /// Nomor halaman laporan, contoh: "Halaman 1 dari 3".
  static String reportPdfPageNumber(int current, int total) =>
      'Halaman $current dari $total';

  // Layar Laporan dan cetak (T-073).
  static const String reportBack = 'Kembali';
  static const String reportRangeTitle = 'Rentang Laporan';
  static const String reportRangeSubtitle =
      'Pilih tanggal mulai dan tanggal akhir yang akan dicetak.';
  static const String reportStartDateLabel = 'Tanggal Mulai';
  static const String reportEndDateLabel = 'Tanggal Akhir';
  static const String reportDatePickerStartTitle = 'Pilih Tanggal Mulai';
  static const String reportDatePickerEndTitle = 'Pilih Tanggal Akhir';
  static const String reportDatePickerCancel = 'Batal';
  static const String reportDatePickerConfirm = 'Pilih';
  static const String reportDatePickerPreviousMonth = 'Bulan sebelumnya';
  static const String reportDatePickerNextMonth = 'Bulan berikutnya';
  static const String reportDateRangeInvalid =
      'Tanggal akhir tidak boleh mendahului tanggal mulai.';
  static const String reportLoading = 'Menyiapkan pratinjau laporan...';
  static const String reportLoadError =
      'Tidak dapat menyiapkan laporan. Coba lagi.';
  static const String reportNetworkError =
      'Tidak ada koneksi internet. Riwayat membaca yang tersimpan di perangkat '
      'belum dapat dimuat. Coba lagi.';
  static const String reportPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk membuat laporan. Masuk kembali lalu '
      'coba lagi.';
  static const String reportSignInRequired =
      'Masuk terlebih dahulu untuk membuat laporan.';
  static const String reportPreviewTitle = 'Pratinjau Laporan';
  static const String reportPreviewSubtitle =
      'Tampilan ringkas isi PDF A4 sebelum dicetak.';
  static const String reportPreviewBadge = 'PDF A4';
  static const String reportPreviewEmptyTitle = 'Belum ada aktivitas membaca';
  static const String reportPreviewEmptyMessage =
      'Laporan tetap dapat dicetak. PDF akan berisi ringkasan kosong pada '
      'rentang ini.';
  static const String reportPrintAction = 'Cetak Laporan';
  static const String reportPrintHint =
      'Laporan A4 dibuka lewat dialog cetak sistem. Tidak ada pengiriman '
      'berkas.';
  static const String reportPrintError =
      'Tidak dapat membuka dialog cetak. Coba lagi.';

  /// Rentang tanggal laporan pada pratinjau, contoh:
  /// "1 Oktober 2026 - 23 Oktober 2026".
  static String reportPeriod(String start, String end) => '$start - $end';

  /// Ringkasan aktivitas satu buku atau satu hari, contoh:
  /// "2 sesi, 45 menit, 30 halaman".
  static String reportActivitySummary(int sessions, int minutes, int pages) {
    return '$sessions sesi, $minutes menit, $pages halaman';
  }

  /// Nama berkas yang tampil pada dialog cetak sistem.
  static String reportPrintDocumentName(String start, String end) {
    return 'Laporan Membaca $start - $end';
  }

  /// Label aksesibilitas kolom tanggal, contoh:
  /// "Tanggal Mulai, 1 Oktober 2026".
  static String reportDateFieldSemantics(String label, String value) {
    return '$label, $value';
  }

  // Riwayat sesi membaca (T-057).
  static const String sessionHistoryTitle = 'Riwayat Sesi';
  static const String sessionHistoryBack = 'Kembali';
  static const String sessionHistoryLoading = 'Memuat riwayat sesi...';
  static const String sessionHistoryLoadError =
      'Tidak dapat memuat riwayat sesi. Coba lagi.';
  static const String sessionHistoryNetworkError =
      'Tidak ada koneksi internet. Riwayat sesi yang tersimpan belum dapat '
      'dimuat. Coba lagi.';
  static const String sessionHistoryPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk melihat riwayat sesi. Masuk kembali '
      'lalu coba lagi.';
  static const String sessionHistorySignInRequired =
      'Masuk terlebih dahulu untuk melihat riwayat sesi.';
  static const String sessionHistoryEmptyTitle = 'Belum ada riwayat sesi';
  static const String sessionHistoryEmptyMessage =
      'Sesi membaca yang selesai akan muncul di sini.';
  static const String sessionHistoryOfflineTitle =
      'Riwayat sesi belum dapat dimuat';
  static const String sessionHistoryOfflineMessage =
      'Tidak ada koneksi internet dan riwayat sesi belum tersimpan di '
      'perangkat. Sambungkan internet lalu coba lagi.';
  static const String sessionHistoryBookEmptyMessage =
      'Selesaikan sesi membaca untuk buku ini agar riwayatnya tercatat.';
  static const String sessionHistoryBookOfflineMessage =
      'Riwayat sesi buku ini belum tersimpan di perangkat. Sambungkan '
      'internet lalu coba lagi.';
  static const String sessionHistoryLoadMore = 'Muat Lebih Banyak';
  static const String sessionHistoryLoadingMore = 'Memuat sesi lainnya...';
  static const String sessionHistoryLoadMoreError =
      'Riwayat sesi belum dapat diperbarui. Coba lagi.';
  static const String sessionHistoryDateUnavailable =
      'Waktu sesi tidak tersedia';

  /// Jumlah halaman sesi, contoh: "Halaman 40–75".
  static String sessionHistoryPages(int startPage, int endPage) {
    if (startPage == endPage) {
      return 'Halaman $startPage';
    }
    return 'Halaman $startPage–$endPage';
  }

  // Komunitas, kegiatan, tantangan, notifikasi.
  static const String communityTitle = 'Komunitas';
  static const String notificationsTitle = 'Notifikasi';

  // Komunitas: feed dan repository postingan (T-080).
  static const String communityFeedTitle = 'Diskusi Terbaru';
  static const String communityAvatarLabel = 'Avatar pengguna';
  static const String communityLoading = 'Memuat diskusi...';
  static const String communityLoadError =
      'Tidak dapat memuat diskusi. Coba lagi.';
  static const String communityLoadNetworkError =
      'Tidak ada koneksi internet. Diskusi yang tersimpan belum dapat dimuat. '
      'Coba lagi.';
  static const String communityLoadPermissionDenied =
      'Sesi Anda tidak memiliki izin untuk melihat diskusi. Masuk kembali lalu '
      'coba lagi.';
  static const String communitySignInRequired =
      'Masuk terlebih dahulu untuk melihat diskusi komunitas.';
  static const String communityEmptyTitle = 'Belum ada diskusi';
  static const String communityEmptyMessage =
      'Postingan komunitas akan muncul di sini setelah pembaca mulai berbagi.';
  static const String communityOfflineTitle = 'Diskusi belum dapat dimuat';
  static const String communityOfflineMessage =
      'Tidak ada koneksi internet dan diskusi belum tersimpan di perangkat. '
      'Sambungkan internet lalu coba lagi.';
  static const String communityLoadMore = 'Muat Lebih Banyak';
  static const String communityLoadingMore = 'Memuat diskusi lainnya...';
  static const String communityLoadMoreError =
      'Diskusi belum dapat diperbarui. Coba lagi.';
  static const String communityPostAuthorFallback = 'Pembaca Libria';
  static const String communityPostDateUnavailable =
      'Waktu postingan tidak tersedia';
  static const String communityPostContentRequired =
      'Isi postingan tidak boleh kosong.';
  static const String communityPostCreateNetworkError =
      'Tidak ada koneksi internet. Postingan belum tersimpan. Coba lagi.';
  static const String communityPostCreatePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk membuat postingan. Masuk kembali '
      'lalu coba lagi.';
  static const String communityPostCreateError =
      'Gagal membuat postingan. Coba lagi.';
  static const String communityPostDeleteNetworkError =
      'Tidak ada koneksi internet. Postingan belum dihapus. Coba lagi.';
  static const String communityPostDeletePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menghapus postingan. Masuk kembali '
      'lalu coba lagi.';
  static const String communityPostDeleteError =
      'Gagal menghapus postingan. Coba lagi.';

  // Komunitas: formulir postingan baru (T-081).
  static const String communityStartDiscussion = 'Mulai Diskusi';
  static const String communityPostNewTitle = 'Diskusi Baru';
  static const String communityPostFormBack = 'Kembali';
  static const String communityPostNewSubtitle =
      'Bagikan cerita, pertanyaan, atau refleksi untuk komunitas pembaca.';
  static const String communityPostContentLabel = 'Isi Diskusi';
  static const String communityPostContentHint =
      'Tulis pemikiranmu tentang buku atau kebiasaan membaca...';
  static const String communityPostBookTitle = 'Tautkan Buku';
  static const String communityPostBookOptional = 'Opsional';
  static const String communityPostBookChoose = 'Pilih dari Koleksi';
  static const String communityPostBookHint =
      'Diskusi dapat dikirim tanpa menautkan buku.';
  static const String communityPostBookRemove = 'Hapus tautan buku';
  static const String communityPostBookPickerTitle = 'Pilih Buku';
  static const String communityPostBookPickerClose = 'Tutup';
  static const String communityPostBookPickerLoading = 'Memuat koleksi...';
  static const String communityPostBookPickerEmptyTitle =
      'Belum ada buku di koleksi';
  static const String communityPostBookPickerEmptyMessage =
      'Tambahkan buku ke koleksi agar dapat ditautkan ke diskusi.';
  static const String communityPostBookPickerError =
      'Koleksi belum dapat dimuat. Coba lagi.';
  static const String communityPostSubmit = 'Kirim Diskusi';
  static const String communityPostSubmitting = 'Mengirim diskusi...';
  static const String communityPostCreated = 'Diskusi berhasil dibuat.';

  /// Pesan batas panjang isi postingan.
  static String communityPostContentTooLong(int maxLength) =>
      'Isi postingan maksimal $maxLength karakter.';

  // Komunitas: detail postingan dan balasan (T-082).
  static const String communityPostBack = 'Kembali';
  static const String communityPostDetailLoading = 'Memuat postingan...';
  static const String communityPostNotFoundTitle = 'Postingan tidak ditemukan';
  static const String communityPostNotFoundMessage =
      'Postingan ini mungkin sudah dihapus atau tautannya tidak lagi tersedia.';
  static const String communityRepliesTitle = 'Balasan';
  static const String communityRepliesLoading = 'Memuat balasan...';
  static const String communityRepliesLoadError =
      'Balasan belum dapat dimuat. Coba lagi.';
  static const String communityRepliesEmptyTitle = 'Belum ada balasan';
  static const String communityRepliesEmptyMessage =
      'Jadilah yang pertama membalas diskusi ini.';
  static const String communityRepliesLoadMore = 'Muat Balasan Lainnya';
  static const String communityRepliesLoadingMore = 'Memuat balasan lainnya...';
  static const String communityRepliesLoadMoreError =
      'Balasan belum dapat diperbarui. Coba lagi.';
  static const String communityReplyAvatarLabel = 'Avatar penulis balasan';
  static const String communityReplyDateUnavailable =
      'Waktu balasan tidak tersedia';
  static const String communityReplyFieldHint = 'Tulis balasan...';
  static const String communityReplySend = 'Kirim balasan';
  static const String communityReplyContentRequired =
      'Balasan tidak boleh kosong.';
  static const String communityReplyCreateNetworkError =
      'Tidak ada koneksi internet. Balasan belum tersimpan. Coba lagi.';
  static const String communityReplyCreatePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk membalas. Masuk kembali lalu coba '
      'lagi.';
  static const String communityReplyCreateError =
      'Gagal mengirim balasan. Coba lagi.';
  static const String communityReplySent = 'Balasan terkirim.';
  static const String communityReplyDeleteTooltip = 'Hapus balasan';
  static const String communityReplyDeleteDialogTitle = 'Hapus balasan?';
  static const String communityReplyDeleteDialogMessage =
      'Balasan yang dihapus tidak dapat dikembalikan.';
  static const String communityReplyDeleteConfirm = 'Hapus';
  static const String communityReplyDeleteNetworkError =
      'Tidak ada koneksi internet. Balasan belum dihapus. Coba lagi.';
  static const String communityReplyDeletePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menghapus balasan. Masuk kembali '
      'lalu coba lagi.';
  static const String communityReplyDeleteError =
      'Gagal menghapus balasan. Coba lagi.';
  static const String communityReplyDeleteSuccess = 'Balasan dihapus.';
  static const String communityReplyNotFound = 'Balasan sudah tidak ada.';
  static const String communityReplyDeleteNotAllowed =
      'Anda hanya dapat menghapus balasan milik sendiri.';

  // Komunitas: like dan batal like (T-083).
  static const String communityLikeAction = 'Suka postingan';
  static const String communityUnlikeAction = 'Batal suka postingan';
  static const String communityPostNotFound =
      'Postingan ini sudah tidak tersedia.';
  static const String communityLikeNetworkError =
      'Tidak ada koneksi internet. Like belum tersimpan. Coba lagi.';
  static const String communityLikePermissionDenied =
      'Sesi Anda tidak memiliki izin untuk menyukai postingan. Masuk kembali '
      'lalu coba lagi.';
  static const String communityLikeError = 'Gagal memperbarui like. Coba lagi.';
  static const String communityLikeStatusNetworkError =
      'Status like belum dapat dimuat tanpa koneksi internet.';
  static const String communityLikeStatusPermissionDenied =
      'Status like tidak dapat dimuat. Masuk kembali lalu coba lagi.';
  static const String communityLikeStatusError =
      'Status like belum dapat dimuat.';

  // Waktu relatif untuk feed dan notifikasi.
  static const String relativeJustNow = 'Baru saja';
  static const String relativeYesterday = 'Kemarin';

  /// Waktu relatif dalam menit, contoh: "5 menit lalu".
  static String relativeMinutesAgo(int minutes) => '$minutes menit lalu';

  /// Waktu relatif dalam jam, contoh: "2 jam lalu".
  static String relativeHoursAgo(int hours) => '$hours jam lalu';

  /// Waktu relatif dalam hari, contoh: "3 hari lalu".
  static String relativeDaysAgo(int days) => '$days hari lalu';
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
