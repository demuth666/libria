import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/report_menu_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../reports/data/report.dart';
import '../data/post.dart';
import '../data/post_repository.dart';
import '../data/reply.dart';
import 'post_detail_providers.dart';
import 'report_sheet.dart';

/// Layar detail postingan pada rute `/post/:id` (T-082, FR-K3 dan FR-K6).
///
/// Layar ini tidak ada di Stitch; susunannya mengikuti PRD bagian 5.8 dan
/// bahasa visual kartu feed Komunitas: header kaca dengan tombol kembali,
/// kartu postingan, daftar balasan terbaru lebih dulu, serta kolom balas tetap
/// di bagian bawah. Jumlah balasan dibaca dari stream postingan sehingga
/// langsung sinkron dengan `replyCount` setelah balasan ditambah atau dihapus.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _deletingReplyIds = <String>{};

  bool _isSending = false;
  String? _replyError;

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeCommunity);
  }

  void _retryPost() {
    ref.invalidate(postDetailProvider(widget.postId));
  }

  void _onReplyChanged(String value) {
    if (_replyError != null && value.trim().isNotEmpty) {
      setState(() => _replyError = null);
    }
  }

  Future<void> _sendReply() async {
    final String content = _replyController.text.trim();
    if (content.isEmpty) {
      setState(() => _replyError = AppStrings.communityReplyContentRequired);
      return;
    }

    setState(() {
      _isSending = true;
      _replyError = null;
    });

    try {
      await ref
          .read(postRepositoryProvider)
          .addReply(postId: widget.postId, content: content);
      if (!mounted) {
        return;
      }
      _replyController.clear();
      _replyFocusNode.unfocus();
      setState(() => _isSending = false);
      _showMessage(AppStrings.communityReplySent);

      // Balasan terbaru berada di urutan teratas daftar. Gulir kembali ke awal
      // agar balasan yang baru dikirim langsung terlihat.
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on PostFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() => _isSending = false);
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSending = false);
      _showMessage(AppStrings.communityReplyCreateError);
    }
  }

  Future<void> _confirmDeleteReply(Reply reply) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.communityReplyDeleteDialogTitle,
      message: AppStrings.communityReplyDeleteDialogMessage,
      confirmLabel: AppStrings.communityReplyDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _deletingReplyIds.add(reply.id));
    try {
      await ref
          .read(postRepositoryProvider)
          .deleteReply(postId: widget.postId, replyId: reply.id);
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.communityReplyDeleteSuccess);
    } on PostFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.communityReplyDeleteError);
    } finally {
      if (mounted) {
        setState(() => _deletingReplyIds.remove(reply.id));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reportPost(Post post) {
    return openReportSheet(
      context,
      targetType: Report.targetPost,
      postId: post.id,
      targetAuthorId: post.authorId,
      targetContent: post.content,
    );
  }

  Future<void> _reportReply(Reply reply) {
    return openReportSheet(
      context,
      targetType: Report.targetReply,
      postId: widget.postId,
      replyId: reply.id,
      targetAuthorId: reply.authorId,
      targetContent: reply.content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Post?> post = ref.watch(postDetailProvider(widget.postId));
    final AsyncValue<ReplyListState> replies = ref.watch(
      replyListProvider(widget.postId),
    );
    final String? currentUserId = ref.watch(currentUserProvider).value?.uid;
    final Post? loadedPost = post.value;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.postDetailTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('post-detail-back'),
                tooltip: AppStrings.communityPostBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: post.when(
              skipLoadingOnReload: true,
              loading: () => const LoadingView(
                message: AppStrings.communityPostDetailLoading,
              ),
              error: (Object error, StackTrace stackTrace) => ErrorView(
                message: _postErrorMessage(error),
                onRetry: _retryPost,
              ),
              data: (Post? value) {
                if (value == null) {
                  return _PostNotFoundView(onBack: _goBack);
                }
                return _PostDetailContent(
                  post: value,
                  replies: replies,
                  currentUserId: currentUserId,
                  deletingReplyIds: _deletingReplyIds,
                  scrollController: _scrollController,
                  onLoadMore: () => ref
                      .read(replyListProvider(widget.postId).notifier)
                      .loadMore(),
                  onRetryReplies: () => ref
                      .read(replyListProvider(widget.postId).notifier)
                      .retry(),
                  onDeleteReply: _confirmDeleteReply,
                  onReportPost: () => _reportPost(value),
                  onReportReply: _reportReply,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: loadedPost == null
          ? null
          : _ReplyComposer(
              controller: _replyController,
              focusNode: _replyFocusNode,
              errorText: _replyError,
              isSending: _isSending,
              onChanged: _onReplyChanged,
              onSend: _sendReply,
            ),
    );
  }
}

String _postErrorMessage(Object error) {
  if (error is PostFailure) {
    return error.message;
  }
  return AppStrings.communityLoadError;
}

String _repliesErrorMessage(Object error) {
  if (error is PostFailure) {
    return error.message;
  }
  return AppStrings.communityRepliesLoadError;
}

/// Keadaan postingan tidak ditemukan atau sudah dihapus.
class _PostNotFoundView extends StatelessWidget {
  const _PostNotFoundView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ContentWidth(
          maxWidth: 640,
          child: EmptyView(
            title: AppStrings.communityPostNotFoundTitle,
            message: AppStrings.communityPostNotFoundMessage,
            icon: Icons.forum_outlined,
            action: SecondaryButton(
              label: AppStrings.communityPostBack,
              icon: Icons.arrow_back,
              onPressed: onBack,
            ),
          ),
        ),
      ),
    );
  }
}

/// Isi detail: kartu postingan, judul bagian balasan, daftar balasan, dan
/// tombol muat lebih banyak.
class _PostDetailContent extends StatelessWidget {
  const _PostDetailContent({
    required this.post,
    required this.replies,
    required this.currentUserId,
    required this.deletingReplyIds,
    required this.scrollController,
    required this.onLoadMore,
    required this.onRetryReplies,
    required this.onDeleteReply,
    required this.onReportPost,
    required this.onReportReply,
  });

  final Post post;
  final AsyncValue<ReplyListState> replies;
  final String? currentUserId;
  final Set<String> deletingReplyIds;
  final ScrollController scrollController;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryReplies;
  final ValueChanged<Reply> onDeleteReply;
  final VoidCallback onReportPost;
  final ValueChanged<Reply> onReportReply;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return CustomScrollView(
      key: const PageStorageKey<String>('post-detail'),
      controller: scrollController,
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
              child: PostCard(
                key: const ValueKey<String>('post-detail-card'),
                authorName: _authorName(post.authorName),
                authorPhotoUrl: post.authorPhotoUrl,
                timeLabel: _timeLabel(post.createdAt),
                content: post.content,
                bookTitle: _bookTitle(post.bookTitle),
                replyCount: post.replyCount,
                likeCount: post.likeCount,
                onReport: onReportPost,
                reportButtonKey: const ValueKey<String>('post-detail-report'),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.lg,
            horizontalPadding,
            AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 760,
              child: _RepliesHeader(count: post.replyCount),
            ),
          ),
        ),
        ..._replySlivers(context, horizontalPadding),
      ],
    );
  }

  List<Widget> _replySlivers(BuildContext context, double horizontalPadding) {
    return replies.when(
      skipLoadingOnReload: true,
      loading: () => <Widget>[
        SliverToBoxAdapter(
          child: ContentWidth(
            maxWidth: 760,
            child: const LoadingView(
              message: AppStrings.communityRepliesLoading,
            ),
          ),
        ),
      ],
      error: (Object error, StackTrace stackTrace) => <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 760,
              child: _InlineError(
                message: _repliesErrorMessage(error),
                onRetry: onRetryReplies,
              ),
            ),
          ),
        ),
      ],
      data: (ReplyListState state) {
        if (state.isEmpty) {
          return <Widget>[
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 760,
                child: const EmptyView(
                  title: AppStrings.communityRepliesEmptyTitle,
                  message: AppStrings.communityRepliesEmptyMessage,
                  icon: Icons.chat_bubble_outline,
                ),
              ),
            ),
          ];
        }

        return <Widget>[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: SliverList.builder(
              itemCount: state.replies.length,
              itemBuilder: (BuildContext context, int index) {
                final Reply reply = state.replies[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ContentWidth(
                    maxWidth: 760,
                    child: _ReplyCard(
                      reply: reply,
                      canDelete:
                          currentUserId != null &&
                          reply.authorId == currentUserId,
                      isDeleting: deletingReplyIds.contains(reply.id),
                      onDelete: () => onDeleteReply(reply),
                      onReport: () => onReportReply(reply),
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
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 760,
                child: _ReplyFooter(
                  state: state,
                  onLoadMore: onLoadMore,
                  onRetry: onRetryReplies,
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  static String _authorName(String value) {
    final String name = value.trim();
    return name.isEmpty ? AppStrings.communityPostAuthorFallback : name;
  }

  static String? _bookTitle(String? value) {
    final String? title = value?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  static String _timeLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return AppStrings.communityPostDateUnavailable;
    }
    return AppDateFormatter.relativeTime(createdAt);
  }
}

/// Judul bagian balasan beserta jumlah balasan dari postingan.
class _RepliesHeader extends StatelessWidget {
  const _RepliesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 20, color: scheme.secondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.communityRepliesTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),
        Text(
          AppStrings.replyCountLabel(count),
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Satu balasan: avatar, nama penulis, waktu, isi, dan tombol hapus untuk
/// balasan milik sendiri.
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.reply,
    required this.canDelete,
    required this.isDeleting,
    required this.onDelete,
    required this.onReport,
  });

  final Reply reply;
  final bool canDelete;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final String authorName = reply.authorName.trim().isEmpty
        ? AppStrings.communityPostAuthorFallback
        : reply.authorName.trim();
    final DateTime? createdAt = reply.createdAt;

    return Container(
      key: ValueKey<String>('post-reply-${reply.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReplyAvatar(name: authorName, photoUrl: reply.authorPhotoUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      createdAt == null
                          ? AppStrings.communityReplyDateUnavailable
                          : AppDateFormatter.relativeTime(createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canDelete)
                _DeleteReplyButton(
                  replyId: reply.id,
                  isDeleting: isDeleting,
                  onPressed: onDelete,
                ),
              ReportMenuButton(
                key: ValueKey<String>('post-reply-report-${reply.id}'),
                onReport: onReport,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            reply.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteReplyButton extends StatelessWidget {
  const _DeleteReplyButton({
    required this.replyId,
    required this.isDeleting,
    required this.onPressed,
  });

  final String replyId;
  final bool isDeleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (isDeleting) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      key: ValueKey<String>('post-reply-delete-$replyId'),
      tooltip: AppStrings.communityReplyDeleteTooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(Icons.delete_outline, color: scheme.error),
    );
  }
}

/// Avatar bulat penulis balasan dengan foto atau huruf awal nama.
class _ReplyAvatar extends StatelessWidget {
  const _ReplyAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  String get _initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    final String first = parts.first.substring(0, 1);
    final String second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Semantics(
      label: AppStrings.communityReplyAvatarLabel,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                width: 36,
                height: 36,
                placeholder: (BuildContext context, String url) =>
                    _initialsText(theme, scheme),
                errorWidget: (BuildContext context, String url, Object error) =>
                    _initialsText(theme, scheme),
              )
            : _initialsText(theme, scheme),
      ),
    );
  }

  Widget _initialsText(ThemeData theme, ColorScheme scheme) {
    if (_initials.isEmpty) {
      return Icon(Icons.person, size: 18, color: scheme.onPrimary);
    }
    return Text(
      _initials,
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Tombol "Muat Balasan Lainnya", pemuatan berikutnya, dan galat pemuatan
/// tambahan.
class _ReplyFooter extends StatelessWidget {
  const _ReplyFooter({
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
  });

  final ReplyListState state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const _InlineLoading(
        message: AppStrings.communityRepliesLoadingMore,
      );
    }
    if (state.loadMoreFailed) {
      return _InlineError(
        message: AppStrings.communityRepliesLoadMoreError,
        onRetry: onRetry,
      );
    }
    if (!state.hasMore) {
      return const SizedBox.shrink();
    }
    return SecondaryButton(
      key: const ValueKey<String>('post-replies-load-more'),
      label: AppStrings.communityRepliesLoadMore,
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

/// Kolom balas tetap di bagian bawah layar.
class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.isSending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return DecoratedBox(
      key: const ValueKey<String>('post-reply-composer'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      key: const ValueKey<String>('post-reply-field'),
                      controller: controller,
                      focusNode: focusNode,
                      hint: AppStrings.communityReplyFieldHint,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      errorText: errorText,
                      onChanged: onChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    key: const ValueKey<String>('post-reply-send'),
                    tooltip: AppStrings.communityReplySend,
                    onPressed: isSending ? null : onSend,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
