import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';
import '../responsive/breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_routes.dart';

/// Shell layar user: badan halaman aktif ditambah bilah navigasi bawah
/// mengambang.
///
/// Navigasi tetap berada di bawah pada semua ukuran layar sesuai desain
/// Stitch. Di tablet, lebar bilah dibatasi agar tidak melebar mengikuti layar;
/// susunan item, warna, dan tombol Sesi Baca tidak berubah.
///
/// Susunan dan gaya bilah mengikuti redesain Stitch yang sudah tercatat di
/// `docs/stitch-screens.md` bagian "Bilah navigasi bawah (redesain)": lima
/// item dengan "Sesi Baca" sebagai tombol lingkaran di tengah (bukan tab),
/// item aktif tampil sebagai pil navy berisi ikon dan label putih, item
/// tidak aktif memakai ikon slate tanpa label.
///
/// Cabang shell mengikuti urutan tab pada `docs/PRD.md` bagian 4: Beranda,
/// Koleksi, Komunitas, Statistik, Profil. Tab Statistik tidak punya ikon
/// bilah navigasi tersendiri karena Stitch tidak memuatnya (ringkasan
/// statistik tampil di Beranda dan Profil); rutenya tetap bisa dibuka lewat
/// kode (`context.go(AppRoutes.homeStats)`).
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  /// Shell navigasi dari `StatefulShellRoute.indexedStack` di `app_router.dart`.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(navigationShell: navigationShell),
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
    icon: Icons.home_rounded,
    label: AppStrings.homeTitle,
  ),
  _ShellNavItem(
    branchIndex: 1,
    icon: Icons.menu_book_rounded,
    label: AppStrings.libraryTitle,
  ),
  _ShellNavItem(
    branchIndex: 2,
    icon: Icons.groups_rounded,
    label: AppStrings.communityTitle,
  ),
  _ShellNavItem(
    branchIndex: 4,
    icon: Icons.person_rounded,
    label: AppStrings.profileTitle,
  ),
];

/// Lebar maksimum bilah navigasi pada tablet agar tidak melebar penuh.
const double _navBarMaxWidth = 640;

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final int currentIndex = navigationShell.currentIndex;
    final bool isCompact = Breakpoints.of(context) == ScreenSize.compact;

    final List<Widget> items = <Widget>[];
    for (int index = 0; index < _shellNavItems.length; index++) {
      final _ShellNavItem item = _shellNavItems[index];
      if (index == 2) {
        items.add(
          _SessionButton(onTap: () => context.push(AppRoutes.sessionSetup)),
        );
      }
      items.add(
        Expanded(
          flex: isCompact && currentIndex == item.branchIndex ? 3 : 1,
          child: Center(
            child: _NavItem(
              icon: item.icon,
              label: item.label,
              selected: currentIndex == item.branchIndex,
              onTap: () => navigationShell.goBranch(item.branchIndex),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _navBarMaxWidth),
          child: ClipRRect(
            borderRadius: AppRadius.allExtraLarge,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: AppShadows.glassBlurSigma,
                sigmaY: AppShadows.glassBlurSigma,
              ),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: extras.glassSurface,
                  borderRadius: AppRadius.allExtraLarge,
                  boxShadow: AppShadows.navigationBar,
                ),
                child: Row(children: items),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu item bilah navigasi: pil navy berisi ikon dan label saat aktif,
/// ikon slate saja saat tidak aktif.
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
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allFull,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: AppRadius.allFull,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: selected ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? scheme.onPrimary : AppColors.slateIcon,
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onPrimary),
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
}

/// Tombol lingkaran teal "Sesi Baca" di tengah bilah navigasi; membuka alur
/// sesi membaca dan bukan bagian dari cabang shell.
class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: AppStrings.sessionNavLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.secondary,
            shape: BoxShape.circle,
            boxShadow: AppShadows.cover,
          ),
          child: Icon(Icons.timer_rounded, color: scheme.onSecondary, size: 24),
        ),
      ),
    );
  }
}
