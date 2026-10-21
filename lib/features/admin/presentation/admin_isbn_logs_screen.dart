import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../isbn_logs/data/isbn_log.dart';
import '../../isbn_logs/data/isbn_log_repository.dart';
import 'admin_isbn_logs_providers.dart';

/// Antrean log ISBN yang belum ditangani pada rute `/admin/isbn-logs`
/// (T-035a) beserta aksi "Tambah buku" dan "Tandai ditangani" (T-035b).
///
/// Layar ini belum punya desain Stitch. Susunannya mengikuti PRD bagian 7 dan
/// bahasa visual layar admin lain: satu kartu per log berisi ISBN, jumlah
/// pemindaian, waktu terakhir dipindai, status belum ditangani, dan aksi per
/// baris. Warna, tipografi, radius, dan jarak berasal dari token tema sehingga
/// mode terang, gelap, ponsel, dan tablet memakai tampilan yang sama.
class AdminIsbnLogsScreen extends ConsumerStatefulWidget {
  const AdminIsbnLogsScreen({super.key});

  @override
  ConsumerState<AdminIsbnLogsScreen> createState() =>
      _AdminIsbnLogsScreenState();
}

class _AdminIsbnLogsScreenState extends ConsumerState<AdminIsbnLogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(adminIsbnLogsProvider.notifier).ensureLoaded());
      }
    });
  }

  void _retry() {
    unawaited(ref.read(adminIsbnLogsProvider.notifier).reload());
  }

  void _loadMore() {
    unawaited(ref.read(adminIsbnLogsProvider.notifier).loadMore());
  }

  /// Pesan galat dari repository sudah ramah pengguna; galat lain memakai
  /// pesan umum tanpa membocorkan detail teknis.
  String _messageFor(Object error, String fallback) {
    if (error is IsbnLogFailure) {
      return error.message;
    }
    return fallback;
  }

  String _errorMessage(Object error) {
    return _messageFor(error, AppStrings.adminIsbnLogsLoadError);
  }

  /// Membuka formulir tambah buku T-033 dengan ISBN log sebagai nilai awal.
  void _openNewBook(IsbnLog log) {
    unawaited(context.push<void>(AppRoutes.adminBookNewPath(log.isbn)));
  }

  /// Menandai log sudah ditangani lalu menampilkan konfirmasi singkat.
  ///
  /// Angka Dashboard Admin tidak diubah dari sini: tab Dashboard sudah memuat
  /// ulang agregasinya setiap kali dipilih kembali (T-031).
  Future<void> _markHandled(IsbnLog log) async {
    try {
      final bool didWrite = await ref
          .read(adminIsbnLogsProvider.notifier)
          .markHandled(log);
      if (!didWrite || !mounted) {
        return;
      }
      _showMessage(AppStrings.adminIsbnLogsMarkHandledSuccess);
    } catch (error) {
      if (mounted) {
        _showMessage(
          _messageFor(error, AppStrings.adminIsbnLogsMarkHandledError),
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final AsyncValue<AdminIsbnLogsState> logsState = ref.watch(
      adminIsbnLogsProvider,
    );

    return SafeArea(
      top: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-isbn-logs-list'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.sm,
              ),
              child: ContentWidth(
                maxWidth: 960,
                child: Text(
                  AppStrings.adminIsbnLogsSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          _buildBody(logsState, horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<AdminIsbnLogsState> state,
    double horizontalPadding,
  ) {
    return state.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: const ContentWidth(
          maxWidth: 960,
          child: LoadingView(message: AppStrings.adminIsbnLogsLoading),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: ContentWidth(
          maxWidth: 960,
          child: ErrorView(message: _errorMessage(error), onRetry: _retry),
        ),
      ),
      data: (AdminIsbnLogsState data) {
        if (data.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: ContentWidth(
              maxWidth: 960,
              child: EmptyView(
                title: AppStrings.adminIsbnLogsEmptyTitle,
                message: AppStrings.adminIsbnLogsEmptyMessage,
                icon: Icons.qr_code_scanner,
              ),
            ),
          );
        }
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            AppSpacing.xl,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final Widget child;
              if (index == data.logs.length) {
                child = _LoadMoreFooter(state: data, onLoadMore: _loadMore);
              } else {
                final IsbnLog log = data.logs[index];
                child = _IsbnLogCard(
                  log: log,
                  isMarkingHandled: data.markingHandledIsbns.contains(log.isbn),
                  onAddBook: () => _openNewBook(log),
                  onMarkHandled: () => unawaited(_markHandled(log)),
                );
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == data.logs.length ? 0 : AppSpacing.sm,
                ),
                child: ContentWidth(maxWidth: 960, child: child),
              );
            }, childCount: data.logs.length + (data.hasMore ? 1 : 0)),
          ),
        );
      },
    );
  }
}

/// Satu baris antrean log ISBN beserta aksinya.
class _IsbnLogCard extends StatelessWidget {
  const _IsbnLogCard({
    required this.log,
    required this.isMarkingHandled,
    required this.onAddBook,
    required this.onMarkHandled,
  });

  final IsbnLog log;

  /// `true` bila log ini sedang ditandai ditangani.
  final bool isMarkingHandled;

  final VoidCallback onAddBook;
  final VoidCallback onMarkHandled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: AppRadius.allMedium,
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppStrings.isbnLabel(log.isbn),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _MetaRow(
                        icon: Icons.qr_code_scanner,
                        label: AppStrings.adminIsbnLogsScanCount(log.scanCount),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _MetaRow(
                        icon: Icons.schedule,
                        label: _lastScannedLabel(log.lastScannedAt),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _UnhandledStatusChip(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                SecondaryButton(
                  label: AppStrings.adminIsbnLogsAddBook,
                  icon: Icons.add,
                  onPressed: isMarkingHandled ? null : onAddBook,
                ),
                SecondaryButton(
                  label: isMarkingHandled
                      ? AppStrings.adminIsbnLogsMarkingHandled
                      : AppStrings.adminIsbnLogsMarkHandled,
                  icon: Icons.check,
                  isLoading: isMarkingHandled,
                  onPressed: isMarkingHandled ? null : onMarkHandled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _lastScannedLabel(DateTime? lastScannedAt) {
    if (lastScannedAt == null) {
      return AppStrings.adminIsbnLogsLastScannedUnavailable;
    }
    return AppStrings.adminIsbnLogsLastScanned(
      AppDateFormatter.dateTime(lastScannedAt),
    );
  }
}

/// Baris ikon dan teks pendukung pada kartu log.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pil status yang menandai log belum ditangani.
class _UnhandledStatusChip extends StatelessWidget {
  const _UnhandledStatusChip();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pending_outlined,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              AppStrings.adminIsbnLogsStatusUnhandled,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol "Muat Lebih Banyak" dan pesan bila pemuatan gagal.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final AdminIsbnLogsState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.loadMoreFailed) ...[
          Text(
            AppStrings.adminIsbnLogsLoadMoreError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: state.loadMoreFailed
              ? AppStrings.retry
              : AppStrings.adminIsbnLogsLoadMore,
          icon: state.loadMoreFailed ? Icons.refresh : Icons.expand_more,
          isLoading: state.isLoadingMore,
          expand: true,
          onPressed: state.isLoadingMore ? null : onLoadMore,
        ),
      ],
    );
  }
}
