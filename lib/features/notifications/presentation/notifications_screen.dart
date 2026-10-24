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
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/app_notification.dart';
import '../data/notification_repository.dart';
import 'notification_providers.dart';

/// Layar daftar notifikasi pada rute `/notifications` (T-086, FR-K8).
///
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 7 dan
/// bahasa visual Komunitas: header kaca dengan tombol kembali, ringkasan
/// belum dibaca beserta tombol "Tandai semua dibaca", lalu baris notifikasi
/// berisi ikon jenis, teks singkat, waktu relatif, dan titik belum dibaca.
/// Notifikasi terbaru tampil lebih dulu dan dapat dimuat bertahap.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _markAllRead() async {
    if (_markingAll) {
      return;
    }
    setState(() => _markingAll = true);
    try {
      final int updated = await ref
          .read(notificationRepositoryProvider)
          .markAllRead();
      if (!mounted) {
        return;
      }
      if (updated > 0) {
        _showMessage(AppStrings.notificationsMarkAllSuccess);
      }
    } on NotificationFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.notificationsUpdateError);
    } finally {
      if (mounted) {
        setState(() => _markingAll = false);
      }
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.read) {
      try {
        await ref
            .read(notificationRepositoryProvider)
            .markRead(notification.id);
      } on NotificationFailure catch (failure) {
        if (!mounted) {
          return;
        }
        _showMessage(failure.message);
      } catch (_) {
        if (!mounted) {
          return;
        }
        _showMessage(AppStrings.notificationsUpdateError);
      }
    }
    if (!mounted) {
      return;
    }
    _openTarget(notification);
  }

  void _openTarget(AppNotification notification) {
    final String targetId = notification.refId.trim();
    if (targetId.isEmpty) {
      return;
    }
    switch (notification.refType) {
      case AppNotification.refTypePost:
        context.push(AppRoutes.postDetailPath(targetId));
        return;
      case AppNotification.refTypeEvent:
        context.push(AppRoutes.eventDetailPath(targetId));
        return;
      case AppNotification.refTypeChallenge:
        context.push(AppRoutes.challengeDetailPath(targetId));
        return;
      default:
        return;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<NotificationListState> notifications = ref.watch(
      notificationListProvider,
    );
    final int unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final bool isOffline = ref.watch(connectivityProvider).value == false;
    final NotificationListState? data = notifications.value;
    final bool showActions =
        data != null &&
        data.notifications.isNotEmpty &&
        !notifications.hasError;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.notificationsTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('notifications-back'),
                tooltip: AppStrings.notificationsBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          if (showActions)
            _NotificationActions(
              unread: unread,
              isMarkingAll: _markingAll,
              onMarkAllRead: _markAllRead,
            ),
          Expanded(
            child: notifications.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const LoadingView(message: AppStrings.notificationsLoading),
              error: (Object error, StackTrace stackTrace) => ErrorView(
                message: _errorMessage(error),
                onRetry: () =>
                    ref.read(notificationListProvider.notifier).retry(),
              ),
              data: (NotificationListState state) => _NotificationContent(
                state: state,
                isOffline: isOffline,
                onLoadMore: () =>
                    ref.read(notificationListProvider.notifier).loadMore(),
                onRetry: () =>
                    ref.read(notificationListProvider.notifier).retry(),
                onOpen: _open,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan belum dibaca dan tombol "Tandai semua dibaca".
class _NotificationActions extends StatelessWidget {
  const _NotificationActions({
    required this.unread,
    required this.isMarkingAll,
    required this.onMarkAllRead,
  });

  final int unread;
  final bool isMarkingAll;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.sm,
        horizontalPadding,
        0,
      ),
      child: ContentWidth(
        maxWidth: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              unread > 0
                  ? AppStrings.notificationsUnreadSummary(unread)
                  : AppStrings.notificationsAllRead,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey<String>('notifications-mark-all'),
                onPressed: unread > 0 && !isMarkingAll ? onMarkAllRead : null,
                icon: isMarkingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_rounded, size: 18),
                label: const Text(AppStrings.notificationsMarkAll),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi layar: keadaan kosong/offline atau daftar notifikasi.
class _NotificationContent extends StatelessWidget {
  const _NotificationContent({
    required this.state,
    required this.isOffline,
    required this.onLoadMore,
    required this.onRetry,
    required this.onOpen,
  });

  final NotificationListState state;
  final bool isOffline;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      if (isOffline) {
        return EmptyView(
          title: AppStrings.notificationsOfflineTitle,
          message: AppStrings.notificationsOfflineMessage,
          icon: Icons.wifi_off_rounded,
          action: PrimaryButton(
            label: AppStrings.retry,
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        );
      }
      return const EmptyView(
        title: AppStrings.notificationsEmptyTitle,
        message: AppStrings.notificationsEmptyMessage,
        icon: Icons.notifications_none_rounded,
      );
    }

    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg;

    return CustomScrollView(
      key: const PageStorageKey<String>('notifications-list'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            0,
          ),
          sliver: SliverList.builder(
            itemCount: state.notifications.length,
            itemBuilder: (BuildContext context, int index) {
              final AppNotification notification = state.notifications[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ContentWidth(
                  maxWidth: 760,
                  child: _NotificationTile(
                    notification: notification,
                    onTap: () => onOpen(notification),
                  ),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.xs,
            horizontalPadding,
            bottomInset,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 760,
              child: _NotificationFooter(
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
}

/// Satu baris notifikasi.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool unread = !notification.read;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.allLarge,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('notification-row-${notification.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: AppRadius.allMedium,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _iconFor(notification.type),
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: unread
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _timeLabel(notification),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label: AppStrings.notificationsUnreadLabel,
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: scheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case AppNotification.typeReply:
        return Icons.chat_bubble_outline_rounded;
      case AppNotification.typeLike:
        return Icons.favorite_rounded;
      case AppNotification.typeEvent:
        return Icons.event_outlined;
      case AppNotification.typeChallenge:
        return Icons.emoji_events_outlined;
      case AppNotification.typeReport:
        return Icons.flag_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static String _timeLabel(AppNotification notification) {
    final DateTime? createdAt = notification.createdAt;
    if (createdAt == null) {
      return AppStrings.notificationsDateUnavailable;
    }
    return AppDateFormatter.relativeTime(createdAt);
  }
}

/// Tombol "Muat Lebih Banyak", pemuatan berikutnya, dan galat tambahan.
class _NotificationFooter extends StatelessWidget {
  const _NotificationFooter({
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
  });

  final NotificationListState state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const _InlineLoading(message: AppStrings.notificationsLoadingMore);
    }
    if (state.loadMoreFailed) {
      return _InlineError(
        message: AppStrings.notificationsLoadMoreError,
        onRetry: onRetry,
      );
    }
    if (!state.hasMore) {
      return const SizedBox.shrink();
    }
    return SecondaryButton(
      key: const ValueKey<String>('notifications-load-more'),
      label: AppStrings.notificationsLoadMore,
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
  if (error is NotificationFailure) {
    return error.message;
  }
  return AppStrings.notificationsLoadError;
}
