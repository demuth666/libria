import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_repository.dart';
import '../../books/data/book_repository.dart';
import '../../isbn_logs/data/isbn_log_repository.dart';
import '../../reports/data/report_repository.dart';
import 'admin_dashboard_stats.dart';

/// Mengambil empat angka ringkasan Dashboard Admin (T-031).
///
/// Setiap angka berasal dari repository fiturnya masing-masing dan memakai
/// agregasi Firestore `count()`. Data buku tetap lewat [BookRepository].
class AdminDashboardRepository {
  AdminDashboardRepository({
    required this.bookRepository,
    required this.reportRepository,
    required this.isbnLogRepository,
    required this.userRepository,
  });

  final BookRepository bookRepository;
  final ReportRepository reportRepository;
  final IsbnLogRepository isbnLogRepository;
  final UserRepository userRepository;

  /// Mengambil seluruh angka ringkasan secara paralel.
  Future<AdminDashboardStats> fetchStats() async {
    final (
      int totalBooks,
      int openReports,
      int unhandledIsbnLogs,
      int totalUsers,
    ) = await (
      bookRepository.countBooks(),
      reportRepository.countOpenReports(),
      isbnLogRepository.countUnhandledIsbnLogs(),
      userRepository.countUsers(),
    ).wait;

    return AdminDashboardStats(
      totalBooks: totalBooks,
      openReports: openReports,
      unhandledIsbnLogs: unhandledIsbnLogs,
      totalUsers: totalUsers,
    );
  }
}

/// Akses [AdminDashboardRepository] bersama lewat Riverpod.
final Provider<AdminDashboardRepository> adminDashboardRepositoryProvider =
    Provider<AdminDashboardRepository>(
      (Ref ref) => AdminDashboardRepository(
        bookRepository: ref.watch(bookRepositoryProvider),
        reportRepository: ref.watch(reportRepositoryProvider),
        isbnLogRepository: ref.watch(isbnLogRepositoryProvider),
        userRepository: ref.watch(userRepositoryProvider),
      ),
    );
