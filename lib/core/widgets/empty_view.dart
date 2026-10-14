import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tampilan keadaan kosong: ikon, judul, pesan opsional, dan aksi opsional.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    this.message,
    this.icon = Icons.menu_book_outlined,
    this.action,
    super.key,
  });

  /// Judul keadaan kosong; ambil dari `AppStrings`.
  final String title;

  /// Penjelasan tambahan; ambil dari `AppStrings`.
  final String? message;

  /// Ikon keadaan kosong.
  final IconData icon;

  /// Aksi opsional di bawah pesan, misalnya `PrimaryButton`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
