/// Path rute aplikasi Libria.
///
/// Daftar lengkap dan aksesnya ada di `docs/PRD.md` bagian 4. Dikumpulkan di
/// sini supaya rute tidak ditulis sebagai literal string berulang di
/// `app_router.dart` dan pada redirect (T-015) atau navigasi layar lain.
abstract final class AppRoutes {
  const AppRoutes._();

  // Autentikasi dan permulaan.
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Shell user dengan navigasi bawah.
  static const String home = '/home';
  static const String homeLibrary = '/home/library';
  static const String homeLibrarySearchSegment = 'search';
  static const String homeLibrarySearch = '/home/library/search';
  static const String homeCommunity = '/home/community';
  static const String homeStats = '/home/stats';
  static const String homeStatsHistorySegment = 'history';
  static const String homeStatsHistory = '/home/stats/history';
  static const String homeSettings = '/home/settings';

  // Detail dan alur user lain.
  static const String bookDetail = '/book/:id';
  static const String isbnScan = '/scan';

  /// Parameter kueri yang membuat `/scan` mengembalikan buku terpilih ke
  /// pemanggil, bukan membuka halaman detail.
  static const String isbnScanPickerParam = 'pick';

  static const String isbnScanPickerPath = '$isbnScan?$isbnScanPickerParam=1';

  static const String sessionSetup = '/session/setup';

  /// Nama parameter ID buku yang diteruskan ke layar pengaturan sesi.
  static const String sessionSetupBookIdParam = 'bookId';

  static const String sessionRun = '/session/run';
  static const String sessionFinish = '/session/finish';
  static const String journal = '/journal';
  static const String journalNew = '/journal/new';

  /// Nama parameter ID buku yang mengisi awal formulir jurnal baru.
  static const String journalBookIdParam = 'bookId';

  /// Nama parameter ID jurnal yang dibuka untuk diubah.
  static const String journalIdParam = 'journalId';

  /// Nama parameter ID sesi yang ditautkan ke jurnal baru (T-061).
  static const String journalSessionIdParam = 'sessionId';

  static const String report = '/report';
  static const String notifications = '/notifications';
  static const String events = '/events';
  static const String eventDetail = '/events/:id';
  static const String challenges = '/challenges';
  static const String challengeDetail = '/challenges/:id';

  /// Formulir postingan komunitas baru (T-081).
  static const String postNew = '/post/new';
  static const String postDetail = '/post/:id';

  // Admin.
  static const String admin = '/admin';
  static const String adminBooks = '/admin/books';
  static const String adminBookNew = '/admin/books/new';
  static const String adminBookEdit = '/admin/books/:id/edit';
  static const String adminIsbnLogs = '/admin/isbn-logs';
  static const String adminReports = '/admin/reports';
  static const String adminEvents = '/admin/events';
  static const String adminEventNew = '/admin/events/new';
  static const String adminEventEdit = '/admin/events/:id/edit';
  static const String adminChallenges = '/admin/challenges';

  /// Path `/book/:id` dengan [id] terisi, untuk `context.go`/`context.push`.
  static String bookDetailPath(String id) => '/book/$id';

  /// Path `/session/setup?bookId=...` dengan buku yang sudah dipilih.
  ///
  /// Kontrak ini dipakai tombol "Mulai Sesi" di Detail Buku dan alur sesi
  /// T-052, sehingga layar pengaturan sesi dapat langsung memilih [bookId].
  static String sessionSetupPath(String bookId) {
    return Uri(
      path: sessionSetup,
      queryParameters: <String, String>{sessionSetupBookIdParam: bookId},
    ).toString();
  }

  /// Path `/journal/new` untuk jurnal baru, opsional dengan [bookId] yang
  /// sudah dipilih dan [sessionId] yang ditautkan (T-060 dan T-061).
  static String journalNewPath({String? bookId, String? sessionId}) {
    final Map<String, String> query = <String, String>{
      if (bookId != null && bookId.isNotEmpty) journalBookIdParam: bookId,
      if (sessionId != null && sessionId.isNotEmpty)
        journalSessionIdParam: sessionId,
    };
    if (query.isEmpty) {
      return journalNew;
    }
    return Uri(path: journalNew, queryParameters: query).toString();
  }

  /// Path `/journal/new?journalId=...` untuk mengubah jurnal yang sudah ada.
  static String journalEditPath(String journalId) {
    return Uri(
      path: journalNew,
      queryParameters: <String, String>{journalIdParam: journalId},
    ).toString();
  }

  /// Path `/events/:id` dengan [id] terisi.
  static String eventDetailPath(String id) => '/events/$id';

  /// Path `/challenges/:id` dengan [id] terisi.
  static String challengeDetailPath(String id) => '/challenges/$id';

  /// Path `/post/:id` dengan [id] terisi.
  static String postDetailPath(String id) => '/post/$id';

  /// Path `/admin/books/:id/edit` dengan [id] terisi.
  static String adminBookEditPath(String id) => '/admin/books/$id/edit';

  /// Path `/admin/events/:id/edit` dengan [id] terisi.
  static String adminEventEditPath(String id) => '/admin/events/$id/edit';

  /// Path formulir tambah buku dengan ISBN awal dari Log ISBN.
  static String adminBookNewPath(String isbn) {
    return Uri(
      path: adminBookNew,
      queryParameters: <String, String>{'isbn': isbn},
    ).toString();
  }
}
