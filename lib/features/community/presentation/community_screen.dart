import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/post.dart';
import '../data/post_repository.dart';
import 'community_providers.dart';

/// Tab Komunitas pada rute `/home/community` (T-080, FR-K1).
///
/// Susunan mengikuti desain Stitch "Libria - Komunitas Literasi"
/// (`docs/design/stitch/komunitas.*`): header kaca dengan ikon buku, judul
/// "Diskusi Terbaru", dan kartu postingan berisi penulis, waktu relatif, isi,
/// penautan buku, serta jumlah tanggapan dan like. Filter kategori, sorotan
/// tantangan, dan diskusi mingguan pada desain belum ditampilkan karena belum
/// ada pada model data atau PRD bagian 5.8.
///
/// Layar berada di dalam shell user sehingga navigasi bawah tetap tampil.
/// Mengetuk kartu membuka Detail Postingan (`/post/:id`). Tombol melayang
/// "Mulai Diskusi" mengikuti desain Stitch dan membuka formulir postingan baru
/// pada `/post/new` (T-081). Like belum dibuat karena milik T-083.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CommunityFeedState> feed = ref.watch(
      communityFeedProvider,
    );
    final bool isOffline = ref.watch(connectivityProvider).value == false;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Stack(
      children: [
        Column(
          children: [
            const _CommunityHeader(),
            Expanded(
              child: _CommunityContent(
                feed: feed,
                isOffline: isOffline,
                onLoadMore: () =>
                    ref.read(communityFeedProvider.notifier).loadMore(),
                onRetry: () => ref.read(communityFeedProvider.notifier).retry(),
              ),
            ),
          ],
        ),
        Positioned(
          right: horizontalPadding,
          bottom:
              MediaQuery.paddingOf(context).bottom +
              AppBottomNavBar.height +
              AppSpacing.md,
          child: _StartDiscussionButton(
            onPressed: () => context.push(AppRoutes.postNew),
          ),
        ),
      ],
    );
  }
}

/// Tombol melayang "Mulai Diskusi" pada feed Komunitas.
class _StartDiscussionButton extends StatelessWidget {
  const _StartDiscussionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: AppStrings.communityStartDiscussion,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey<String>('community-start-discussion'),
          onTap: onPressed,
          borderRadius: AppRadius.allFull,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: AppRadius.allFull,
              boxShadow: AppShadows.level2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: scheme.onPrimary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.communityStartDiscussion,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header tetap Komunitas: ikon buku, judul, dan avatar pengguna.
class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ScreenHeader(
      title: AppStrings.communityTitle,
      leading: Icon(
        Icons.auto_stories_outlined,
        size: 24,
        color: scheme.secondary,
      ),
      actions: <Widget>[
        Semantics(
          label: AppStrings.communityAvatarLabel,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.person, size: 18, color: scheme.onPrimary),
          ),
        ),
      ],
    );
  }
}

/// Isi tab: keadaan memuat, galat, kosong/offline, atau daftar postingan.
class _CommunityContent extends StatelessWidget {
  const _CommunityContent({
    required this.feed,
    required this.isOffline,
    required this.onLoadMore,
    required this.onRetry,
  });

  final AsyncValue<CommunityFeedState> feed;
  final bool isOffline;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return feed.when(
      skipLoadingOnReload: true,
      loading: () => const LoadingView(message: AppStrings.communityLoading),
      error: (Object error, StackTrace stackTrace) =>
          ErrorView(message: _errorMessage(error), onRetry: onRetry),
      data: (CommunityFeedState state) => _CommunityFeedList(
        state: state,
        isOffline: isOffline,
        onLoadMore: onLoadMore,
        onRetry: onRetry,
      ),
    );
  }
}

/// Daftar postingan yang dapat digulir, atau keadaan kosong/offline.
class _CommunityFeedList extends StatelessWidget {
  const _CommunityFeedList({
    required this.state,
    required this.isOffline,
    required this.onLoadMore,
    required this.onRetry,
  });

  final CommunityFeedState state;
  final bool isOffline;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    // Ruang bawah menyisakan tempat untuk bilah navigasi dan tombol melayang
    // "Mulai Diskusi" agar tombol muat berikutnya tidak tertutup.
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom +
        AppBottomNavBar.height +
        AppSpacing.xl +
        AppSpacing.xl;

    if (state.isEmpty) {
      if (isOffline) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: EmptyView(
            title: AppStrings.communityOfflineTitle,
            message: AppStrings.communityOfflineMessage,
            icon: Icons.wifi_off_rounded,
            action: PrimaryButton(
              label: AppStrings.retry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: const EmptyView(
          title: AppStrings.communityEmptyTitle,
          message: AppStrings.communityEmptyMessage,
          icon: Icons.forum_outlined,
        ),
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('community-feed'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 760,
              child: Text(
                AppStrings.communityFeedTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            0,
          ),
          sliver: SliverList.builder(
            itemCount: state.posts.length,
            itemBuilder: (BuildContext context, int index) {
              final Post post = state.posts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ContentWidth(
                  maxWidth: 760,
                  child: PostCard(
                    key: ValueKey<String>('community-post-${post.id}'),
                    authorName: _authorName(post),
                    authorPhotoUrl: post.authorPhotoUrl,
                    timeLabel: _timeLabel(post),
                    content: post.content,
                    bookTitle: _bookTitle(post),
                    replyCount: post.replyCount,
                    likeCount: post.likeCount,
                    onTap: () =>
                        context.push(AppRoutes.postDetailPath(post.id)),
                  ),
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
              child: _CommunityFeedFooter(
                state: state,
                onLoadMore: onLoadMore,
                onRetry: onRetry,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _authorName(Post post) {
    final String name = post.authorName.trim();
    return name.isEmpty ? AppStrings.communityPostAuthorFallback : name;
  }

  static String? _bookTitle(Post post) {
    final String? title = post.bookTitle?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  static String _timeLabel(Post post) {
    final DateTime? createdAt = post.createdAt;
    if (createdAt == null) {
      return AppStrings.communityPostDateUnavailable;
    }
    return AppDateFormatter.relativeTime(createdAt);
  }
}

/// Tombol "Muat Lebih Banyak", pemuatan berikutnya, dan galat pemuatan
/// tambahan.
class _CommunityFeedFooter extends StatelessWidget {
  const _CommunityFeedFooter({
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
  });

  final CommunityFeedState state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const _InlineLoading(message: AppStrings.communityLoadingMore);
    }
    if (state.loadMoreFailed) {
      return _InlineError(
        message: AppStrings.communityLoadMoreError,
        onRetry: onRetry,
      );
    }
    if (!state.hasMore) {
      return const SizedBox.shrink();
    }
    return SecondaryButton(
      key: const ValueKey<String>('community-load-more'),
      label: AppStrings.communityLoadMore,
      icon: Icons.expand_more_rounded,
      expand: true,
      onPressed: onLoadMore,
    );
  }
}

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

String _errorMessage(Object error) {
  if (error is PostFailure) {
    return error.message;
  }
  return AppStrings.communityLoadError;
}
