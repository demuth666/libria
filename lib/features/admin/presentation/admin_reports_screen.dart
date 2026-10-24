import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../reports/data/report.dart';
import '../../reports/data/report_repository.dart';
import 'admin_reports_providers.dart';

/// Moderasi laporan komunitas pada rute `/admin/reports` (T-085).
///
/// Layar ini belum punya desain Stitch. Susunannya mengikuti PRD bagian 5.8
/// (FR-K7) dan 7 serta bahasa visual layar admin lain: satu kartu per laporan
/// terbuka berisi jenis konten, alasan, cuplikan isi, waktu laporan, serta aksi
/// "Hapus Konten" dan "Abaikan". Warna, tipografi, radius, dan jarak berasal
/// dari token tema sehingga mode terang, gelap, ponsel, dan tablet memakai
/// tampilan yang sama.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(adminReportsProvider.notifier).ensureLoaded());
      }
    });
  }

  void _retry() {
    unawaited(ref.read(adminReportsProvider.notifier).reload());
  }

  void _loadMore() {
    unawaited(ref.read(adminReportsProvider.notifier).loadMore());
  }

  /// Pesan galat dari repository sudah ramah pengguna; galat lain memakai
  /// pesan umum tanpa membocorkan detail teknis.
  String _messageFor(Object error, String fallback) {
    if (error is ReportFailure) {
      return error.message;
    }
    return fallback;
  }

  String _errorMessage(Object error) {
    return _messageFor(error, AppStrings.adminReportsLoadError);
  }

  Future<void> _confirmDelete(Report report) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.adminReportsDeleteDialogTitle,
      message: AppStrings.adminReportsDeleteDialogMessage,
      confirmLabel: AppStrings.adminReportsDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      final bool didWrite = await ref
          .read(adminReportsProvider.notifier)
          .deleteContent(report);
      if (!didWrite || !mounted) {
        return;
      }
      _showMessage(AppStrings.adminReportsDeleteSuccess);
    } catch (error) {
      if (mounted) {
        _showMessage(_messageFor(error, AppStrings.adminReportsActionError));
      }
    }
  }

  Future<void> _dismiss(Report report) async {
    try {
      final bool didWrite = await ref
          .read(adminReportsProvider.notifier)
          .dismiss(report);
      if (!didWrite || !mounted) {
        return;
      }
      _showMessage(AppStrings.adminReportsDismissSuccess);
    } catch (error) {
      if (mounted) {
        _showMessage(_messageFor(error, AppStrings.adminReportsActionError));
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
    final AsyncValue<AdminReportsState> reportsState = ref.watch(
      adminReportsProvider,
    );

    return SafeArea(
      top: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-reports-list'),
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
                  AppStrings.adminReportsSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          _buildBody(reportsState, horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<AdminReportsState> state,
    double horizontalPadding,
  ) {
    return state.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: const ContentWidth(
          maxWidth: 960,
          child: LoadingView(message: AppStrings.adminReportsLoading),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: ContentWidth(
          maxWidth: 960,
          child: ErrorView(message: _errorMessage(error), onRetry: _retry),
        ),
      ),
      data: (AdminReportsState data) {
        if (data.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: ContentWidth(
              maxWidth: 960,
              child: EmptyView(
                title: AppStrings.adminReportsEmptyTitle,
                message: AppStrings.adminReportsEmptyMessage,
                icon: Icons.verified_outlined,
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
              if (index == data.reports.length) {
                child = _LoadMoreFooter(state: data, onLoadMore: _loadMore);
              } else {
                final Report report = data.reports[index];
                child = _ReportCard(
                  key: ValueKey<String>('admin-report-${report.id}'),
                  report: report,
                  action: data.actionFor(report.id),
                  onDelete: () => unawaited(_confirmDelete(report)),
                  onDismiss: () => unawaited(_dismiss(report)),
                );
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == data.reports.length ? 0 : AppSpacing.sm,
                ),
                child: ContentWidth(maxWidth: 960, child: child),
              );
            }, childCount: data.reports.length + (data.hasMore ? 1 : 0)),
          ),
        );
      },
    );
  }
}

/// Satu kartu laporan terbuka beserta aksi moderasinya.
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.action,
    required this.onDelete,
    required this.onDismiss,
    super.key,
  });

  final Report report;

  /// Aksi yang sedang diproses untuk laporan ini, atau `null`.
  final AdminReportAction? action;

  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String preview = report.targetPreview.trim().isEmpty
        ? AppStrings.adminReportsContentUnavailable
        : report.targetPreview.trim();
    final bool isDeleting = action == AdminReportAction.deleteContent;
    final bool isDismissing = action == AdminReportAction.dismiss;
    final bool isProcessing = action != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _InfoChip(
                  icon: _targetIcon(report.targetType),
                  label: _targetLabel(report.targetType),
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                ),
                _InfoChip(
                  icon: Icons.flag_outlined,
                  label: AppStrings.adminReportsReason(
                    _reasonLabel(report.reason),
                  ),
                  background: scheme.surfaceContainerHigh,
                  foreground: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: AppRadius.allMedium,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote, size: 20, color: scheme.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      preview,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _reportedAtLabel(report.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                SecondaryButton(
                  key: ValueKey<String>('admin-report-dismiss-${report.id}'),
                  label: isDismissing
                      ? AppStrings.adminReportsDismissing
                      : AppStrings.adminReportsDismiss,
                  icon: Icons.close,
                  isLoading: isDismissing,
                  onPressed: isProcessing ? null : onDismiss,
                ),
                PrimaryButton(
                  key: ValueKey<String>('admin-report-delete-${report.id}'),
                  label: isDeleting
                      ? AppStrings.adminReportsDeletingContent
                      : AppStrings.adminReportsDeleteContent,
                  icon: Icons.delete_outline,
                  isLoading: isDeleting,
                  onPressed: isProcessing ? null : onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _targetLabel(String targetType) {
    switch (targetType) {
      case Report.targetPost:
        return AppStrings.adminReportsTargetPost;
      case Report.targetReply:
        return AppStrings.adminReportsTargetReply;
      default:
        return AppStrings.adminReportsTargetUnknown;
    }
  }

  IconData _targetIcon(String targetType) {
    switch (targetType) {
      case Report.targetPost:
        return Icons.article_outlined;
      case Report.targetReply:
        return Icons.chat_bubble_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _reasonLabel(String reason) {
    final String trimmed = reason.trim();
    return trimmed.isEmpty ? AppStrings.adminReportsReasonUnavailable : trimmed;
  }

  String _reportedAtLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return AppStrings.adminReportsTimeUnavailable;
    }
    return AppStrings.adminReportsReportedAt(
      AppDateFormatter.relativeTime(createdAt),
    );
  }
}

/// Pil informasi kecil pada kartu laporan.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
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

  final AdminReportsState state;
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
            AppStrings.adminReportsLoadMoreError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: state.loadMoreFailed
              ? AppStrings.retry
              : AppStrings.adminReportsLoadMore,
          icon: state.loadMoreFailed ? Icons.refresh : Icons.expand_more,
          isLoading: state.isLoadingMore,
          expand: true,
          onPressed: state.isLoadingMore ? null : onLoadMore,
        ),
      ],
    );
  }
}
