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
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../events/data/app_event.dart';
import '../../events/data/event_repository.dart';
import 'admin_events_providers.dart';

/// Daftar kegiatan admin pada rute `/admin/events` (T-087, FR-E1).
///
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 5.9 dan 7
/// serta bahasa visual layar admin lain: header ringkas dengan tombol tambah,
/// satu kartu per kegiatan berisi judul, jadwal, lokasi, jumlah peserta, dan
/// aksi hapus. Ketuk kartu untuk mengubah. Semua warna, tipografi, radius, dan
/// jarak berasal dari token tema sehingga mode terang dan gelap serta ponsel
/// dan tablet memakai tampilan yang sama.
class AdminEventsScreen extends ConsumerStatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  ConsumerState<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends ConsumerState<AdminEventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(adminEventsProvider.notifier).ensureLoaded());
      }
    });
  }

  void _retry() {
    unawaited(ref.read(adminEventsProvider.notifier).reload());
  }

  void _loadMore() {
    unawaited(ref.read(adminEventsProvider.notifier).loadMore());
  }

  /// Membuka formulir tambah atau ubah di luar shell admin.
  Future<void> _openForm(String location) {
    return context.push<void>(location);
  }

  Future<void> _confirmDelete(AppEvent event) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.adminEventsDeleteDialogTitle,
      message: AppStrings.adminEventsDeleteDialogMessage(event.title),
      confirmLabel: AppStrings.adminEventsDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref.read(adminEventsProvider.notifier).deleteEvent(event);
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.adminEventsDeleteSuccess);
    } on EventFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.adminEventsDeleteError);
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
    // Formulir menaikkan penanda ini setelah simpan berhasil. Bila layar
    // daftar masih hidup di bawah formulir, halaman pertama dimuat ulang.
    ref.listen<int>(adminEventsReloadProvider, (int? previous, int next) {
      if (previous != null && previous != next) {
        unawaited(ref.read(adminEventsProvider.notifier).reload());
      }
    });
    final AsyncValue<AdminEventsState> eventsState = ref.watch(
      adminEventsProvider,
    );
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SafeArea(
      top: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-events-list'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.adminEventsSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrimaryButton(
                        label: AppStrings.adminEventsAdd,
                        icon: Icons.add,
                        onPressed: () {
                          unawaited(_openForm(AppRoutes.adminEventNew));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBody(eventsState, horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<AdminEventsState> state,
    double horizontalPadding,
  ) {
    return state.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: const ContentWidth(
          maxWidth: 960,
          child: LoadingView(message: AppStrings.adminEventsLoading),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: ContentWidth(
          maxWidth: 960,
          child: ErrorView(
            message: error is EventFailure
                ? error.message
                : AppStrings.adminEventsLoadError,
            onRetry: _retry,
          ),
        ),
      ),
      data: (AdminEventsState data) {
        if (data.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: ContentWidth(
              maxWidth: 960,
              child: EmptyView(
                title: AppStrings.adminEventsEmptyTitle,
                message: AppStrings.adminEventsEmptyMessage,
                icon: Icons.event_outlined,
                action: SecondaryButton(
                  label: AppStrings.adminEventsAdd,
                  icon: Icons.add,
                  onPressed: () {
                    unawaited(_openForm(AppRoutes.adminEventNew));
                  },
                ),
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
              if (index == data.events.length) {
                child = _LoadMoreFooter(state: data, onLoadMore: _loadMore);
              } else {
                final AppEvent event = data.events[index];
                child = _EventCard(
                  event: event,
                  isDeleting: data.deletingEventIds.contains(event.id),
                  onTap: () {
                    unawaited(
                      _openForm(AppRoutes.adminEventEditPath(event.id)),
                    );
                  },
                  onDelete: () {
                    unawaited(_confirmDelete(event));
                  },
                );
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == data.events.length ? 0 : AppSpacing.sm,
                ),
                child: ContentWidth(maxWidth: 960, child: child),
              );
            }, childCount: data.events.length + (data.hasMore ? 1 : 0)),
          ),
        );
      },
    );
  }
}

/// Kartu satu kegiatan pada daftar admin.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  final AppEvent event;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startAt = event.startAt;
    final String description = event.description.trim();
    final String location = event.location.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDeleting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: AppRadius.allMedium,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.event_available_outlined,
                      size: 24,
                      color: scheme.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          startAt == null
                              ? AppStrings.eventsTimeUnavailable
                              : AppDateFormatter.dateTime(startAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _DeleteEventButton(
                    eventTitle: event.title,
                    isDeleting: isDeleting,
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _MetaRow(
                icon: Icons.place_outlined,
                text: location.isEmpty
                    ? AppStrings.eventsLocationUnavailable
                    : location,
              ),
              const SizedBox(height: AppSpacing.xs),
              _MetaRow(
                icon: Icons.group_outlined,
                text: AppStrings.eventsParticipantCount(event.participantCount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris ikon dan keterangan pendek pada kartu kegiatan.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Tombol hapus per baris dengan indikator selama penghapusan berjalan.
class _DeleteEventButton extends StatelessWidget {
  const _DeleteEventButton({
    required this.eventTitle,
    required this.isDeleting,
    required this.onPressed,
  });

  final String eventTitle;
  final bool isDeleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (isDeleting) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.error,
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: AppStrings.adminEventsDeleteTooltip(eventTitle),
      onPressed: onPressed,
      icon: Icon(Icons.delete_outline, color: scheme.error),
    );
  }
}

/// Tombol "Muat Lebih Banyak" dan pesan bila pemuatan gagal.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final AdminEventsState state;
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
            AppStrings.adminEventsLoadMoreError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: state.loadMoreFailed
              ? AppStrings.retry
              : AppStrings.adminEventsLoadMore,
          icon: state.loadMoreFailed ? Icons.refresh : Icons.expand_more,
          isLoading: state.isLoadingMore,
          expand: true,
          onPressed: state.isLoadingMore ? null : onLoadMore,
        ),
      ],
    );
  }
}
