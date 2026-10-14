import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_strings.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Banner kecil "Anda sedang offline".
///
/// Hanya menampilkan tampilan; pemasangannya berdasarkan status koneksi
/// dilakukan oleh [OfflineBannerHost].
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

/// Memasang [OfflineBanner] di atas [child] selama perangkat tanpa koneksi.
///
/// Dipakai lewat `MaterialApp.builder` agar banner tampil di seluruh layar,
/// termasuk di atas shell aplikasi dengan navigasi bawah. Saat banner muncul,
/// konten digeser turun: inset atas dihapus dari [MediaQuery] milik [child]
/// supaya bilah aplikasi tidak menambahkan jarak bilah status dua kali, dan
/// area bilah status diwarnai sama dengan banner agar ikonnya tetap kontras.
class OfflineBannerHost extends ConsumerWidget {
  const OfflineBannerHost({required this.child, super.key});

  /// Isi aplikasi yang ditampilkan saat perangkat terhubung.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOffline = ref.watch(connectivityProvider).value == false;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDarkBanner =
        ThemeData.estimateBrightnessForColor(scheme.inverseSurface) ==
        Brightness.dark;

    // Susunan tetap seperti ini supaya [child] tidak pernah dipindah posisi
    // saat banner muncul atau hilang; hanya bilah banner yang disisipkan.
    return Column(
      children: [
        if (isOffline)
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarIconBrightness: isDarkBanner
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDarkBanner
                  ? Brightness.dark
                  : Brightness.light,
            ),
            child: ColoredBox(
              color: scheme.inverseSurface,
              child: SafeArea(bottom: false, child: const OfflineBanner()),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: isOffline,
            child: child,
          ),
        ),
      ],
    );
  }
}
