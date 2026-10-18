import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Satu tujuan pada [AppBottomNavBar].
class AppBottomNavDestination {
  const AppBottomNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  /// Ikon saat item tidak aktif.
  final IconData icon;

  /// Ikon saat item aktif; memakai [icon] bila tidak diisi.
  final IconData? selectedIcon;

  /// Label singkat yang tampil di bawah ikon.
  final String label;
}

/// Bilah navigasi bawah bersama untuk shell user dan admin.
///
/// Susunan dan gaya mengikuti desain Stitch di `docs/stitch-screens.md`
/// bagian "Bilah navigasi bawah (redesain)": bilah penuh selebar layar yang
/// menempel di tepi bawah, latar kaca 85% dengan blur, dan bayangan ke atas.
/// Setiap item menampilkan ikon 22 px di atas label 11 px dalam satu baris.
/// Item aktif memakai kotak `primaryContainer` radius 12 px dengan ikon dan
/// label putih; item tidak aktif memakai `onSurfaceVariant`.
///
/// [centerAction] dipakai shell user untuk tombol "Sesi Baca" di tengah
/// bilah. Widget itu bukan tujuan navigasi, sehingga tidak mengubah
/// [selectedIndex] dan tidak memanggil [onDestinationSelected].
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.centerAction,
    this.centerActionIndex,
    super.key,
  });

  /// Daftar tab, berurutan dari kiri ke kanan.
  final List<AppBottomNavDestination> destinations;

  /// Indeks tujuan aktif, atau -1 bila tidak ada tab yang aktif.
  final int selectedIndex;

  /// Dipanggil dengan indeks tujuan saat item ditekan.
  final ValueChanged<int> onDestinationSelected;

  /// Widget aksi khusus yang disisipkan di antara tujuan, misalnya tombol
  /// "Sesi Baca" pada shell user.
  final Widget? centerAction;

  /// Posisi [centerAction] pada baris, dihitung sebelum tujuan ke-n.
  final int? centerActionIndex;

  /// Tinggi isi bilah tanpa inset bawah (padanan h-16 Stitch).
  static const double height = 64;

  /// Tinggi tiap item (padanan h-11 Stitch).
  static const double itemHeight = 44;

  /// Jarak tepi isi bilah ke layar.
  static const double _contentPadding = AppSpacing.sm;

  /// Lebar maksimum isi bilah pada tablet agar item tidak melebar terlalu
  /// jauh.
  static const double _contentMaxWidth = 640;

  /// Lebar minimum item biasa (padanan min-w Stitch).
  static const double _itemMinWidth = 56;

  /// Ukuran ikon item (padanan ikon Stitch).
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final int actionIndex = centerActionIndex ?? destinations.length;
    final List<Widget> items = <Widget>[];

    for (int index = 0; index <= destinations.length; index++) {
      if (centerAction != null && index == actionIndex) {
        items.add(Flexible(child: centerAction!));
      }
      if (index == destinations.length) {
        break;
      }

      final AppBottomNavDestination destination = destinations[index];
      items.add(
        Flexible(
          child: _NavItem(
            destination: destination,
            selected: index == selectedIndex,
            onTap: () => onDestinationSelected(index),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: AppShadows.navigationBar),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppShadows.glassBlurSigma,
            sigmaY: AppShadows.glassBlurSigma,
          ),
          child: ColoredBox(
            color: extras.glassSurface,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: height,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _contentPadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: items,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu item bilah navigasi: kotak navy berisi ikon dan label putih saat
/// aktif, ikon dan label `onSurfaceVariant` saat tidak aktif.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color foreground = selected
        ? (theme.brightness == Brightness.dark
              ? scheme.onPrimaryContainer
              : scheme.onPrimary)
        : scheme.onSurfaceVariant;
    final IconData icon = selected
        ? (destination.selectedIcon ?? destination.icon)
        : destination.icon;
    final TextStyle? labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: foreground,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    // Tinggi label dikunci agar semua ikon berada pada garis yang sama,
    // termasuk saat teks diperkecil oleh FittedBox.
    final double labelHeight =
        (labelStyle?.fontSize ?? 0) * (labelStyle?.height ?? 1);

    return Tooltip(
      message: destination.label,
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: AppBottomNavBar.itemHeight,
          constraints: const BoxConstraints(
            minWidth: AppBottomNavBar._itemMinWidth,
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: AppRadius.allMedium,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.allMedium,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    size: AppBottomNavBar._iconSize,
                    color: foreground,
                  ),
                  SizedBox(
                    height: labelHeight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        style: labelStyle,
                      ),
                    ),
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
