import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_repository.dart';

/// Ringkasan menit dan halaman membaca untuk hari ini.
///
/// Dibuang saat Beranda tidak lagi mendengarkan agar membuka kembali tab
/// Beranda mengambil snapshot terbaru, termasuk data cache saat offline.
final StreamProvider<HomeTodaySummary> todayReadingSummaryProvider =
    StreamProvider.autoDispose<HomeTodaySummary>((Ref ref) {
      final HomeRepository repository = ref.watch(homeRepositoryProvider);
      return repository.watchTodaySummary();
    }, retry: (int retryCount, Object error) => null);
