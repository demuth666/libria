import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_routes.dart';

/// Shell layar user: badan halaman aktif ditambah bilah navigasi bawah.
///
/// Susunan dan gaya bilah mengikuti desain Stitch di
/// `docs/stitch-screens.md` bagian "Bilah navigasi bawah (redesain)": bilah
/// penuh selebar layar yang menempel di tepi bawah, latar kaca 85% dengan
/// blur, dan bayangan ke atas. Setiap item menampilkan ikon di atas label.
/// Item aktif memakai kotak `primaryContainer` radius 12 px dengan ikon dan
/// label putih; item tidak aktif memakai `onSurfaceVariant`.
///
/// "Sesi Baca" adalah tombol tengah bergaya khusus (lingkaran
/// `secondaryContainer`) dan bukan tab shell.
///
/// Cabang shell mengikuti urutan tab pada `docs/PRD.md` bagian 4: Beranda,
/// Koleksi, Komunitas, Statistik, Profil. Tab Statistik tidak punya item
/// navigasi tersendiri karena Stitch tidak memuatnya (ringkasan statistik
/// tampil di Beranda dan Profil); rutenya tetap bisa dibuka lewat kode
/// (`context.go(AppRoutes.homeStats)`).
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  /// Shell navigasi dari `StatefulShellRoute.indexedStack` di `app_router.dart`.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _BottomNavBar(navigationShell: navigationShell),
    );
  }
}

/// Satu tujuan navigasi shell.
///
/// Daftar [_shellNavItems] adalah satu-satunya sumber ikon, label, dan cabang
/// untuk bilah navigasi bawah.
class _ShellNavItem {
  const _ShellNavItem({
    required this.branchIndex,
    required this.icon,
    required this.label,
  });

  final int branchIndex;
  final IconData icon;
  final String label;
}

const List<_ShellNavItem> _shellNavItems = <_ShellNavItem>[
  _ShellNavItem(
    branchIndex: 0,
    icon: Icons.home_outlined,
    label: AppStrings.homeTitle,
  ),
  _ShellNavItem(
    branchIndex: 1,
    icon: Icons.local_library_outlined,
    label: AppStrings.libraryTitle,
  ),
  _ShellNavItem(
    branchIndex: 2,
    icon: Icons.forum_outlined,
    label: AppStrings.communityTitle,
  ),
  _ShellNavItem(
    branchIndex: 4,
    icon: Icons.person_outline,
    label: AppStrings.profileTitle,
  ),
];

/// Tinggi isi bilah tanpa inset bawah (padanan h-16 Stitch).
const double _navBarHeight = 64;

/// Lebar maksimum isi bilah pada tablet agar item tidak melebar terlalu jauh.
const double _navBarContentMaxWidth = 640;

/// Lebar minimum item biasa dan item "Sesi Baca" (padanan min-w Stitch).
const double _navItemMinWidth = 56;
const double _sessionItemMinWidth = 58;

/// Ukuran item, ikon, dan lencana "Sesi Baca" (padanan h-11 dan ikon Stitch).
const double _navItemHeight = 44;
const double _navIconSize = 22;
const double _sessionBadgeSize = 24;
const double _sessionIconSize = 18;

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final int currentIndex = navigationShell.currentIndex;

    final List<Widget> items = <Widget>[];
    for (int index = 0; index < _shellNavItems.length; index++) {
      final _ShellNavItem item = _shellNavItems[index];
      if (index == 2) {
        items.add(
          Flexible(
            child: _SessionButton(
              onTap: () => context.push(AppRoutes.sessionSetup),
            ),
          ),
        );
      }
      items.add(
        Flexible(
          child: _NavItem(
            icon: item.icon,
            label: item.label,
            selected: currentIndex == item.branchIndex,
            onTap: () => navigationShell.goBranch(item.branchIndex),
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
                height: _navBarHeight,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _navBarContentMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.gridGutterSmall,
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _navItemHeight,
          constraints: const BoxConstraints(minWidth: _navItemMinWidth),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: AppRadius.allMedium,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.allMedium,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: _navIconSize, color: foreground),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol "Sesi Baca" di tengah bilah navigasi; membuka alur sesi membaca dan
/// bukan bagian dari cabang shell.
class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Tooltip(
      message: AppStrings.sessionNavLabel,
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.allMedium,
            child: Container(
              height: _navItemHeight,
              constraints: const BoxConstraints(minWidth: _sessionItemMinWidth),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: _sessionBadgeSize,
                    height: _sessionBadgeSize,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: _sessionIconSize,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    AppStrings.sessionNavLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w600,
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
