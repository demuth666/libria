import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_dashboard_repository.dart';
import '../data/admin_dashboard_stats.dart';

/// Angka ringkasan Dashboard Admin, dimuat dari [AdminDashboardRepository].
///
/// `ref.invalidate` pada provider ini dipakai tombol "Coba Lagi" untuk
/// mengulang seluruh agregasi setelah galat.
final FutureProvider<AdminDashboardStats> adminDashboardStatsProvider =
    FutureProvider<AdminDashboardStats>(
      (Ref ref) {
        return ref.watch(adminDashboardRepositoryProvider).fetchStats();
      },
      // Galat ditampilkan bersama tombol "Coba Lagi" agar pengguna yang
      // memutuskan kapan mencoba ulang, bukan retry otomatis Riverpod.
      retry: (int retryCount, Object error) => null,
    );
