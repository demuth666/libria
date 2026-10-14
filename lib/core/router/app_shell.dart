import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_routes.dart';

/// Shell layar user: badan halaman aktif ditambah bilah navigasi bawah
/// mengambang.
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

/// Indeks cabang shell, harus sesuai urutan `branches` di `app_router.dart`.
///
/// Indeks 3 (Statistik) sengaja tidak punya konstanta di sini karena tidak
/// mendapat ikon bilah navigasi tersendiri (lihat dokumentasi kelas di atas).
abstract final class _ShellBranch {
  static const int home = 0;
  static const int library = 1;
  static const int community = 2;
  static const int settings = 4;
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final int currentIndex = navigationShell.currentIndex;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
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
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: _NavItem(
                      icon: Icons.home_rounded,
                      label: AppStrings.homeTitle,
                      selected: currentIndex == _ShellBranch.home,
                      onTap: () => navigationShell.goBranch(_ShellBranch.home),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _NavItem(
                      icon: Icons.menu_book_rounded,
                      label: AppStrings.libraryTitle,
                      selected: currentIndex == _ShellBranch.library,
                      onTap: () =>
                          navigationShell.goBranch(_ShellBranch.library),
                    ),
                  ),
                ),
                _SessionButton(
                  onTap: () => context.push(AppRoutes.sessionSetup),
                ),
                Expanded(
                  child: Center(
                    child: _NavItem(
                      icon: Icons.groups_rounded,
                      label: AppStrings.communityTitle,
                      selected: currentIndex == _ShellBranch.community,
                      onTap: () =>
                          navigationShell.goBranch(_ShellBranch.community),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _NavItem(
                      icon: Icons.person_rounded,
                      label: AppStrings.profileTitle,
                      selected: currentIndex == _ShellBranch.settings,
                      onTap: () =>
                          navigationShell.goBranch(_ShellBranch.settings),
                    ),
                  ),
                ),
              ],
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
          padding: EdgeInsets.symmetric(
            horizontal: selected ? AppSpacing.md : AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: AppRadius.allFull,
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
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onPrimary),
                ),
              ],
            ],
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
