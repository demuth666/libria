import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import 'notification_providers.dart';

/// Tombol lonceng dengan lencana jumlah notifikasi belum dibaca (FR-K8).
///
/// Dipakai pada header Beranda. Lencana hanya tampil bila jumlahnya lebih
/// dari nol; kegagalan memuat jumlah tidak menampilkan galat di header.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        key: const ValueKey<String>('home-notification-slot'),
        tooltip: AppStrings.notificationsTitle,
        padding: EdgeInsets.zero,
        onPressed: () => context.push(AppRoutes.notifications),
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(AppStrings.notificationBadgeCount(unread)),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
    );
  }
}
