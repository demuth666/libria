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
import '../../../core/widgets/screen_header.dart';
import '../data/app_event.dart';
import '../data/event_repository.dart';
import 'event_providers.dart';

/// Daftar kegiatan mendatang pada rute `/events` (T-088, FR-E2).
///
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 5.9 dan 7
/// serta bahasa visual kartu Komunitas/Koleksi: header kaca dengan tombol
/// kembali, penjelasan singkat, satu kartu per kegiatan berisi judul, jadwal,
/// lokasi, dan jumlah peserta, lalu tombol "Muat Lebih Banyak". Seluruh warna,
/// tipografi, radius, dan jarak berasal dari token tema sehingga mode terang,
/// gelap, ponsel, dan tablet memakai tampilan yang sama.
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EventsListState> eventsState = ref.watch(
      eventsListProvider,
    );

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.eventsTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('events-back'),
                tooltip: AppStrings.eventsBack,
                padding: EdgeInsets.zero,
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: eventsState.when(
              loading: () =>
                  const LoadingView(message: AppStrings.eventsLoading),
              error: (Object error, StackTrace stackTrace) => ErrorView(
                message: _errorMessage(error),
                onRetry: () => ref.read(eventsListProvider.notifier).retry(),
              ),
              data: (EventsListState data) {
                if (data.isEmpty) {
                  return const EmptyView(
                    title: AppStrings.eventsEmptyTitle,
                    message: AppStrings.eventsEmptyMessage,
                    icon: Icons.event_outlined,
                  );
                }
                return _EventsList(
                  state: data,
                  onLoadMore: () =>
                      ref.read(eventsListProvider.notifier).loadMore(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Daftar kartu kegiatan yang dapat digulir.
class _EventsList extends StatelessWidget {
  const _EventsList({required this.state, required this.onLoadMore});

  final EventsListState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomPadding =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

    return CustomScrollView(
      key: const PageStorageKey<String>('events-list'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 960,
              child: Text(
                AppStrings.eventsSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            bottomPadding,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final Widget child;
              if (index == state.events.length) {
                child = _LoadMoreFooter(state: state, onLoadMore: onLoadMore);
              } else {
                child = _EventCard(event: state.events[index]);
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == state.events.length ? 0 : AppSpacing.sm,
                ),
                child: ContentWidth(maxWidth: 960, child: child),
              );
            }, childCount: state.events.length + (state.hasMore ? 1 : 0)),
          ),
        ),
      ],
    );
  }
}

/// Kartu satu kegiatan mendatang.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startAt = event.startAt;
    final String location = event.location.trim();

    return Card(
      key: ValueKey<String>('event-card-${event.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.eventDetailPath(event.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: AppRadius.allMedium,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.event_available_outlined,
                  size: 24,
                  color: scheme.onSecondaryContainer,
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
                    _MetaRow(
                      icon: Icons.schedule_outlined,
                      text: startAt == null
                          ? AppStrings.eventsTimeUnavailable
                          : AppDateFormatter.dateTime(startAt),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MetaRow(
                      icon: Icons.place_outlined,
                      text: location.isEmpty
                          ? AppStrings.eventsLocationUnavailable
                          : location,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MetaRow(
                      icon: Icons.group_outlined,
                      text: AppStrings.eventsParticipantCount(
                        event.participantCount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
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

/// Tombol "Muat Lebih Banyak" dan pesan bila pemuatan gagal.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final EventsListState state;
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
            AppStrings.eventsLoadMoreError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: state.loadMoreFailed
              ? AppStrings.retry
              : AppStrings.eventsLoadMore,
          icon: state.loadMoreFailed ? Icons.refresh : Icons.expand_more,
          isLoading: state.isLoadingMore,
          expand: true,
          onPressed: state.isLoadingMore ? null : onLoadMore,
        ),
      ],
    );
  }
}

String _errorMessage(Object error) {
  return error is EventFailure ? error.message : AppStrings.eventsLoadError;
}
