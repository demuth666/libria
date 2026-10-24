import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/data/report.dart';
import '../../reports/data/report_repository.dart';

/// Aksi moderasi yang sedang diproses pada satu laporan.
enum AdminReportAction { deleteContent, dismiss }

/// Data laporan terbuka yang berhasil dimuat.
///
/// Status loading dan galat disimpan oleh [AsyncValue] pada
/// [adminReportsProvider]; kelas ini hanya memuat isi halaman, penanda
/// paginasi, dan aksi yang sedang berjalan.
class AdminReportsState {
  const AdminReportsState({
    this.reports = const <Report>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.processingActions = const <String, AdminReportAction>{},
  });

  final List<Report> reports;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  /// Aksi moderasi per ID laporan yang sedang menunggu respons Firestore.
  final Map<String, AdminReportAction> processingActions;

  bool get isEmpty => reports.isEmpty;

  bool get canLoadMore => hasMore && !isLoadingMore;

  bool isProcessing(String reportId) => processingActions.containsKey(reportId);

  AdminReportAction? actionFor(String reportId) => processingActions[reportId];

  AdminReportsState copyWith({
    List<Report>? reports,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    Map<String, AdminReportAction>? processingActions,
  }) {
    return AdminReportsState(
      reports: reports ?? this.reports,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      processingActions: processingActions ?? this.processingActions,
    );
  }
}

/// Pengendali daftar laporan terbuka pada rute `/admin/reports`.
///
/// Semua akses data lewat [ReportRepository]. Setiap muat ulang menaikkan
/// penghitung generasi sehingga respons halaman lama yang datang terlambat
/// tidak menimpa hasil terbaru. Laporan yang sudah diproses dibuang dari daftar
/// dan tidak dimasukkan lagi bila muncul pada respons paginasi yang terlambat.
class AdminReportsController extends Notifier<AsyncValue<AdminReportsState>> {
  late ReportRepository _repository;
  ReportCursor? _nextCursor;
  int _generation = 0;
  bool _started = false;

  final Set<String> _processedReportIds = <String>{};

  @override
  AsyncValue<AdminReportsState> build() {
    _repository = ref.watch(reportRepositoryProvider);
    return const AsyncLoading<AdminReportsState>();
  }

  /// Memuat halaman pertama sekali saja saat layar pertama kali dibuka.
  Future<void> ensureLoaded() {
    if (_started) {
      return Future<void>.value();
    }
    _started = true;
    return _loadFirstPage();
  }

  /// Memuat ulang halaman pertama dari awal.
  Future<void> reload() {
    _started = true;
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final int generation = ++_generation;
    final Map<String, AdminReportAction> processingActions =
        state.value?.processingActions ?? const <String, AdminReportAction>{};
    _nextCursor = null;
    state = const AsyncLoading<AdminReportsState>();

    try {
      final ReportPage page = await _repository.fetchOpenReportsPage(
        limit: reportPageSize,
      );
      if (generation != _generation) {
        return;
      }
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminReportsState>(
        AdminReportsState(
          reports: page.reports
              .where(
                (Report report) => !_processedReportIds.contains(report.id),
              )
              .toList(growable: false),
          hasMore: page.hasMore,
          processingActions: processingActions,
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _generation) {
        return;
      }
      state = AsyncError<AdminReportsState>(error, stackTrace);
    }
  }

  /// Memuat halaman berikutnya dan menambahkannya tanpa duplikat.
  Future<void> loadMore() async {
    final AdminReportsState? current = state.value;
    if (current == null || !current.canLoadMore) {
      return;
    }
    final int generation = _generation;
    state = AsyncData<AdminReportsState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final ReportPage page = await _repository.fetchOpenReportsPage(
        limit: reportPageSize,
        cursor: _nextCursor,
      );
      if (generation != _generation) {
        return;
      }
      final AdminReportsState? latest = state.value;
      if (latest == null) {
        return;
      }
      final Set<String> existingIds = latest.reports
          .map((Report report) => report.id)
          .toSet();
      final List<Report> appended = page.reports
          .where(
            (Report report) =>
                !existingIds.contains(report.id) &&
                !_processedReportIds.contains(report.id),
          )
          .toList(growable: false);
      _nextCursor = page.nextCursor;
      state = AsyncData<AdminReportsState>(
        latest.copyWith(
          reports: <Report>[...latest.reports, ...appended],
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (generation != _generation) {
        return;
      }
      final AdminReportsState? latest = state.value;
      if (latest != null) {
        state = AsyncData<AdminReportsState>(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }

  /// Menghapus konten laporan lalu menutup laporannya (FR-K7).
  ///
  /// Nilai `true` berarti aksi dijalankan; `false` berarti ketukan diabaikan
  /// karena laporan yang sama masih diproses. Baris tetap ada bila repository
  /// gagal. Bila halaman yang terlihat menjadi kosong padahal masih ada halaman
  /// lain, halaman pertama dimuat ulang agar sisa laporan tetap terjangkau.
  Future<bool> deleteContent(Report report) {
    return _process(report, AdminReportAction.deleteContent);
  }

  /// Mengabaikan laporan tanpa menghapus kontennya (FR-K7).
  Future<bool> dismiss(Report report) {
    return _process(report, AdminReportAction.dismiss);
  }

  Future<bool> _process(Report report, AdminReportAction action) async {
    final AdminReportsState? current = state.value;
    if (current == null || current.isProcessing(report.id)) {
      return false;
    }
    state = AsyncData<AdminReportsState>(
      current.copyWith(
        processingActions: <String, AdminReportAction>{
          ...current.processingActions,
          report.id: action,
        },
      ),
    );

    try {
      if (action == AdminReportAction.deleteContent) {
        await _repository.deleteReportedContent(report);
      } else {
        await _repository.dismissReport(report);
      }
      _processedReportIds.add(report.id);

      final AdminReportsState? latest = state.value;
      if (latest == null) {
        return true;
      }
      final AdminReportsState updated = latest.copyWith(
        reports: latest.reports
            .where((Report item) => item.id != report.id)
            .toList(growable: false),
        processingActions: <String, AdminReportAction>{
          ...latest.processingActions,
        }..remove(report.id),
      );
      state = AsyncData<AdminReportsState>(updated);

      if (updated.isEmpty && updated.hasMore) {
        await reload();
      }
      return true;
    } catch (_) {
      final AdminReportsState? latest = state.value;
      if (latest != null && latest.isProcessing(report.id)) {
        state = AsyncData<AdminReportsState>(
          latest.copyWith(
            processingActions: <String, AdminReportAction>{
              ...latest.processingActions,
            }..remove(report.id),
          ),
        );
      }
      rethrow;
    }
  }
}

/// Daftar laporan terbuka pada rute `/admin/reports`.
///
/// Dibuang saat tidak ada lagi layar yang mendengarkan, sehingga membuka
/// kembali layar moderasi selalu memuat laporan terbaru.
final NotifierProvider<AdminReportsController, AsyncValue<AdminReportsState>>
adminReportsProvider =
    NotifierProvider.autoDispose<
      AdminReportsController,
      AsyncValue<AdminReportsState>
    >(AdminReportsController.new);
