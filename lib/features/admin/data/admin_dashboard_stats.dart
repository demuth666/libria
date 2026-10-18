/// Angka ringkasan pada Dashboard Admin (T-031).
///
/// Merupakan nilai turunan yang tidak disimpan ke Firestore, sehingga tidak
/// memiliki `fromMap`/`toMap` seperti model data lain.
class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalBooks,
    required this.openReports,
    required this.unhandledIsbnLogs,
    required this.totalUsers,
  });

  /// Jumlah seluruh buku di katalog.
  final int totalBooks;

  /// Jumlah laporan komunitas berstatus terbuka.
  final int openReports;

  /// Jumlah log ISBN yang belum ditandai ditangani.
  final int unhandledIsbnLogs;

  /// Jumlah seluruh dokumen pengguna.
  final int totalUsers;
}
