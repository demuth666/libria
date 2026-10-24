import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'app_routes.dart';

/// Shell layar user: badan halaman aktif ditambah bilah navigasi bawah.
///
/// Bilah memakai [AppBottomNavBar] agar gayanya sama dengan shell admin.
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
    final int selectedIndex = _shellNavItems.indexWhere(
      (_ShellNavItem item) => item.branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: AppBottomNavBar(
        destinations: <AppBottomNavDestination>[
          for (final _ShellNavItem item in _shellNavItems)
            AppBottomNavDestination(icon: item.icon, label: item.label),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) {
          navigationShell.goBranch(_shellNavItems[index].branchIndex);
        },
        centerAction: _SessionButton(
          onTap: () => context.push(AppRoutes.sessionSetup),
        ),
        centerActionIndex: 2,
      ),
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

/// Lebar minimum item "Sesi Baca" (padanan min-w Stitch).
const double _sessionItemMinWidth = 58;

/// Ukuran lencana dan ikon "Sesi Baca" (padanan ikon Stitch).
const double _sessionBadgeSize = 24;
const double _sessionIconSize = 18;

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
              height: AppBottomNavBar.itemHeightFor(context),
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
                    style: AppTextStyles.navLabel.copyWith(
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
