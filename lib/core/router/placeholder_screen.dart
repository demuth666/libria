import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Layar sementara untuk rute yang layar aslinya belum dibangun.
///
/// Dipakai oleh kerangka router (T-007) sampai setiap rute diganti dengan
/// layar sungguhan pada task fiturnya masing-masing.
class RoutePlaceholderScreen extends StatelessWidget {
  const RoutePlaceholderScreen({required this.title, this.detail, super.key});

  /// Judul layar; juga dipakai sebagai judul bilah aplikasi.
  final String title;

  /// Nilai parameter rute (misalnya id), ditampilkan untuk memudahkan
  /// pemeriksaan bahwa parsing rute sudah benar.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.routeNotBuiltYet(title),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  detail!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
