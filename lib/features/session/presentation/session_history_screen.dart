import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/reading_session.dart';
import '../data/session_repository.dart';
import 'session_history_providers.dart';

/// Layar daftar seluruh riwayat sesi membaca pada rute `/home/stats/history`
/// (T-057, FR-S10).
///
/// Layar dibuka dari pintasan di tab Statistik. Daftar memakai stream cache
/// Firestore sehingga tetap tampil saat offline, dan sesi yang baru disimpan
/// langsung muncul. Layar ini tidak ada di Stitch; susunannya mengikuti PRD
/// bagian 5.4 dan 5.6b serta bahasa visual Koleksi/Detail Buku.
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeStats);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionHistoryScope scope = (bookId: null);
    final AsyncValue<SessionHistoryState> asyncHistory = ref.watch(
      sessionHistoryProvider(scope),
    );
    final bool isOffline = ref.watch(connectivityProvider).value == false;

    return Column(
      children: [
        ScreenHeader(
          title: AppStrings.sessionHistoryTitle,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              key: const ValueKey<String>('session-history-back'),
              tooltip: AppStrings.sessionHistoryBack,
              padding: EdgeInsets.zero,
              onPressed: () => _goBack(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        Expanded(
          child: asyncHistory.when(
            skipLoadingOnReload: true,
            loading: () =>
                const LoadingView(message: AppStrings.sessionHistoryLoading),
            error: (Object error, StackTrace stackTrace) => ErrorView(
              message: _historyErrorMessage(error),
              onRetry: () =>
                  ref.read(sessionHistoryProvider(scope).notifier).retry(),
            ),
            data: (SessionHistoryState history) => _SessionHistoryContent(
              history: history,
              isOffline: isOffline,
              onLoadMore: () =>
                  ref.read(sessionHistoryProvider(scope).notifier).loadMore(),
              onRetry: () =>
                  ref.read(sessionHistoryProvider(scope).notifier).retry(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Daftar keseluruhan sesi membaca yang dapat digulir.
class _SessionHistoryContent extends StatelessWidget {
  const _SessionHistoryContent({
    required this.history,
    required this.isOffline,
    required this.onLoadMore,
    required this.onRetry,
  });

  final SessionHistoryState history;
  final bool isOffline;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      if (isOffline) {
        return EmptyView(
          title: AppStrings.sessionHistoryOfflineTitle,
          message: AppStrings.sessionHistoryOfflineMessage,
          icon: Icons.wifi_off_rounded,
          action: PrimaryButton(
            label: AppStrings.retry,
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        );
      }
      return const EmptyView(
        title: AppStrings.sessionHistoryEmptyTitle,
        message: AppStrings.sessionHistoryEmptyMessage,
        icon: Icons.history_rounded,
      );
    }

    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom +
        AppBottomNavBar.height +
        AppSpacing.lg;

    return CustomScrollView(
      key: const PageStorageKey<String>('session-history'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            0,
          ),
          sliver: SliverList.builder(
            itemCount: history.sessions.length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ContentWidth(
                  maxWidth: 760,
                  child: _SessionHistoryEntry(session: history.sessions[index]),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            bottomInset,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 760,
              child: _SessionHistoryFooter(
                history: history,
                onLoadMore: onLoadMore,
                onRetry: onRetry,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu sesi pada daftar keseluruhan.
class _SessionHistoryEntry extends StatelessWidget {
  const _SessionHistoryEntry({required this.session});

  final ReadingSession session;

  @override
  Widget build(BuildContext context) {
    return _HistorySurface(
      child: SessionHistoryTile(session: session, showBookTitle: true),
    );
  }
}

/// Footer paginasi, pemuatan berikutnya, dan galat pemuatan tambahan.
class _SessionHistoryFooter extends StatelessWidget {
  const _SessionHistoryFooter({
    required this.history,
    required this.onLoadMore,
    required this.onRetry,
  });

  final SessionHistoryState history;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (history.isLoadingMore) {
      return const _InlineLoading(
        message: AppStrings.sessionHistoryLoadingMore,
      );
    }
    if (history.loadMoreFailed) {
      return _InlineError(
        message: AppStrings.sessionHistoryLoadMoreError,
        onRetry: onRetry,
      );
    }
    if (!history.hasMore) {
      return const SizedBox.shrink();
    }
    return SecondaryButton(
      key: const ValueKey<String>('session-history-load-more'),
      label: AppStrings.sessionHistoryLoadMore,
      icon: Icons.expand_more_rounded,
      expand: true,
      onPressed: onLoadMore,
    );
  }
}

/// Kartu riwayat sesi untuk satu buku pada layar Detail Buku.
///
/// Menampilkan sesi terbaru lebih dulu dengan paginasi bertahap. Data cache
/// Firestore dipakai sehingga riwayat tetap terbaca saat offline.
class BookSessionHistoryCard extends ConsumerWidget {
  const BookSessionHistoryCard({required this.bookId, super.key});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionHistoryScope scope = (bookId: bookId);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AsyncValue<SessionHistoryState> asyncHistory = ref.watch(
      sessionHistoryProvider(scope),
    );
    final bool isOffline = ref.watch(connectivityProvider).value == false;

    return _HistorySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: scheme.secondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.sessionHistoryTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          asyncHistory.when(
            skipLoadingOnReload: true,
            loading: () =>
                const _InlineLoading(message: AppStrings.sessionHistoryLoading),
            error: (Object error, StackTrace stackTrace) => _InlineError(
              message: _historyErrorMessage(error),
              onRetry: () =>
                  ref.read(sessionHistoryProvider(scope).notifier).retry(),
            ),
            data: (SessionHistoryState history) => _BookHistoryContent(
              history: history,
              isOffline: isOffline,
              onLoadMore: () =>
                  ref.read(sessionHistoryProvider(scope).notifier).loadMore(),
              onRetry: () =>
                  ref.read(sessionHistoryProvider(scope).notifier).retry(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Isi kartu riwayat untuk satu buku.
class _BookHistoryContent extends StatelessWidget {
  const _BookHistoryContent({
    required this.history,
    required this.isOffline,
    required this.onLoadMore,
    required this.onRetry,
  });

  final SessionHistoryState history;
  final bool isOffline;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _InlineNotice(
        icon: isOffline ? Icons.wifi_off_rounded : Icons.history_rounded,
        message: isOffline
            ? AppStrings.sessionHistoryBookOfflineMessage
            : AppStrings.sessionHistoryBookEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < history.sessions.length; index++) ...[
          if (index > 0) const Divider(height: AppSpacing.lg),
          SessionHistoryTile(session: history.sessions[index]),
        ],
        if (history.isLoadingMore) ...[
          const SizedBox(height: AppSpacing.md),
          const _InlineLoading(message: AppStrings.sessionHistoryLoadingMore),
        ] else if (history.loadMoreFailed) ...[
          const SizedBox(height: AppSpacing.md),
          _InlineError(
            message: AppStrings.sessionHistoryLoadMoreError,
            onRetry: onRetry,
          ),
        ] else if (history.hasMore) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey<String>('book-session-history-load-more'),
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text(AppStrings.sessionHistoryLoadMore),
            ),
          ),
        ],
      ],
    );
  }
}

/// Baris satu sesi: waktu, judul buku (opsional), durasi, dan halaman.
class SessionHistoryTile extends StatelessWidget {
  const SessionHistoryTile({
    required this.session,
    this.showBookTitle = false,
    super.key,
  });

  final ReadingSession session;
  final bool showBookTitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startedAt = session.startedAt;
    final String bookTitle = session.bookTitle.trim().isEmpty
        ? AppStrings.sessionSetupUntitledBook
        : session.bookTitle.trim();
    final String duration = AppDurationFormatter.timer(
      Duration(
        seconds: session.durationSeconds < 0 ? 0 : session.durationSeconds,
      ),
    );
    final String pages = AppStrings.sessionHistoryPages(
      session.startPage,
      session.endPage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                startedAt == null
                    ? AppStrings.sessionHistoryDateUnavailable
                    : AppDateFormatter.dateTime(startedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (session.targetReached) ...[
              const SizedBox(width: AppSpacing.sm),
              const _TargetReachedPill(),
            ],
          ],
        ),
        if (showBookTitle) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            bookTitle,
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            _SessionMeta(icon: Icons.timer_outlined, text: duration),
            _SessionMeta(icon: Icons.menu_book_outlined, text: pages),
          ],
        ),
      ],
    );
  }
}

/// Satu keterangan kecil pada baris sesi.
class _SessionMeta extends StatelessWidget {
  const _SessionMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Pil kecil penanda target sesi sudah tercapai.
class _TargetReachedPill extends StatelessWidget {
  const _TargetReachedPill();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppStrings.sessionFinishTargetReached,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Permukaan kartu yang sama dengan kartu Detail Buku dan penyelesaian sesi.
class _HistorySurface extends StatelessWidget {
  const _HistorySurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors extras = Theme.of(context)
        .extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

/// Baris loading kecil di dalam kartu.
class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pesan galat ringkas dengan tombol coba lagi.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off_outlined, size: 20, color: scheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }
}

/// Pesan ringkas untuk keadaan kosong atau offline.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _historyErrorMessage(Object error) {
  if (error is SessionFailure) {
    return error.message;
  }
  return AppStrings.sessionHistoryLoadError;
}
