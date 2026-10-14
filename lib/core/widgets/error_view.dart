import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Tampilan kesalahan dengan tombol coba lagi.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.onRetry,
    this.message = AppStrings.genericError,
    this.icon = Icons.cloud_off_outlined,
    super.key,
  });

  /// Aksi saat tombol "Coba Lagi" ditekan.
  final VoidCallback onRetry;

  /// Pesan kesalahan yang ramah pengguna; ambil dari `AppStrings`.
  final String message;

  /// Ikon keadaan kesalahan.
  final IconData icon;

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
                color: scheme.errorContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 30, color: scheme.onErrorContainer),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: AppStrings.retry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
