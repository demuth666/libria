import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/admin/data/admin_dashboard_repository.dart';
import 'package:libria/features/admin/data/admin_dashboard_stats.dart';
import 'package:libria/features/auth/data/user_repository.dart';
import 'package:libria/features/books/data/book_repository.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';
import 'package:libria/features/reports/data/report_repository.dart';

void main() {
  test(
    'fetchStats menggabungkan empat angka dari repository masing-masing',
    () async {
      final _FakeBookRepository books = _FakeBookRepository(12);
      final _FakeReportRepository reports = _FakeReportRepository(3);
      final _FakeIsbnLogRepository isbnLogs = _FakeIsbnLogRepository(5);
      final _FakeUserRepository users = _FakeUserRepository(40);
      final AdminDashboardRepository repository = AdminDashboardRepository(
        bookRepository: books,
        reportRepository: reports,
        isbnLogRepository: isbnLogs,
        userRepository: users,
      );

      final AdminDashboardStats stats = await repository.fetchStats();

      expect(stats.totalBooks, 12);
      expect(stats.openReports, 3);
      expect(stats.unhandledIsbnLogs, 5);
      expect(stats.totalUsers, 40);
      expect(books.countCalls, 1);
      expect(reports.countCalls, 1);
      expect(isbnLogs.countCalls, 1);
      expect(users.countCalls, 1);
    },
  );

  test('fetchStats mempertahankan angka 0 sebagai nilai valid', () async {
    final AdminDashboardRepository repository = AdminDashboardRepository(
      bookRepository: _FakeBookRepository(0),
      reportRepository: _FakeReportRepository(0),
      isbnLogRepository: _FakeIsbnLogRepository(0),
      userRepository: _FakeUserRepository(0),
    );

    final AdminDashboardStats stats = await repository.fetchStats();

    expect(stats.totalBooks, 0);
    expect(stats.openReports, 0);
    expect(stats.unhandledIsbnLogs, 0);
    expect(stats.totalUsers, 0);
  });
}

class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(this.value);

  final int value;
  int countCalls = 0;

  @override
  Future<int> countBooks() async {
    countCalls++;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this.value);

  final int value;
  int countCalls = 0;

  @override
  Future<int> countOpenReports() async {
    countCalls++;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIsbnLogRepository implements IsbnLogRepository {
  _FakeIsbnLogRepository(this.value);

  final int value;
  int countCalls = 0;

  @override
  Future<int> countUnhandledIsbnLogs() async {
    countCalls++;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository(this.value);

  final int value;
  int countCalls = 0;

  @override
  Future<int> countUsers() async {
    countCalls++;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
