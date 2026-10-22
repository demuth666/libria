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
