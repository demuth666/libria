import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Layar sementara untuk rute yang layar aslinya belum dibangun.
///
/// Dipakai oleh kerangka router (T-007) sampai setiap rute diganti dengan
/// layar sungguhan pada task fiturnya masing-masing. Isi dibatasi lebarnya di
/// tablet dan dapat digulir bila tinggi layar terbatas.
///
/// Di dalam `AdminShell`, AppBar disediakan oleh shell sehingga layar ini
/// dipanggil dengan [showAppBar] bernilai `false`.
class RoutePlaceholderScreen extends StatelessWidget {
  const RoutePlaceholderScreen({
    required this.title,
    this.detail,
    this.action,
    this.showAppBar = true,
    super.key,
  });

  /// Judul layar; juga dipakai sebagai judul bilah aplikasi.
  final String title;

  /// Nilai parameter rute (misalnya id), ditampilkan untuk memudahkan
  /// pemeriksaan bahwa parsing rute sudah benar.
  final String? detail;

  /// Aksi opsional untuk membuka bagian fitur yang sudah selesai, misalnya
  /// pintasan riwayat sesi dari layar Statistik sementara.
  final Widget? action;

  /// Menampilkan AppBar sendiri. Matikan bila layar berada di dalam shell yang
  /// sudah menyediakan AppBar.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    const EdgeInsets padding = EdgeInsets.all(AppSpacing.lg);

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double minHeight = math.max(
            0,
            constraints.maxHeight - padding.vertical,
          );

          return SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
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
                      if (action != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        action!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
