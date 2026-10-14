import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Banner kecil "Anda sedang offline".
///
/// Hanya menampilkan tampilan; pemasangan berdasarkan status koneksi ada pada
/// task layanan konektivitas.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.inverseSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: scheme.onInverseSurface,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              AppStrings.offlineBanner,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onInverseSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
