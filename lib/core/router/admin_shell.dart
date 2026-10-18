import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_providers.dart';
import '../../features/auth/data/auth_repository.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';

/// Shell area admin: AppBar dengan aksi Keluar dan bottom navigation tetap.
///
/// Bottom navigation menggantikan kartu menu pada Dashboard Admin. Tab yang
/// tersedia mengikuti urutan layar admin: Dashboard, Buku, Log ISBN, Laporan,
/// Kegiatan, dan Tantangan. Setiap tab adalah cabang
/// `StatefulShellRoute.indexedStack`, sehingga posisi gulir dan tumpukan
/// halaman tiap tab dipertahankan saat berpindah.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({required this.navigationShell, super.key});

  /// Shell navigasi dari `StatefulShellRoute.indexedStack` di `app_router.dart`.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  static const List<_AdminDestination> _destinations = <_AdminDestination>[
    _AdminDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: AppStrings.adminNavDashboard,
      title: AppStrings.adminDashboardTitle,
    ),
    _AdminDestination(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: AppStrings.adminNavBooks,
      title: AppStrings.adminBooksTitle,
    ),
    _AdminDestination(
      icon: Icons.qr_code_scanner,
      selectedIcon: Icons.qr_code_scanner,
      label: AppStrings.adminNavIsbnLogs,
      title: AppStrings.adminIsbnLogsTitle,
    ),
    _AdminDestination(
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag,
      label: AppStrings.adminNavReports,
      title: AppStrings.adminReportsTitle,
    ),
    _AdminDestination(
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
      label: AppStrings.adminNavEvents,
      title: AppStrings.adminEventsTitle,
    ),
    _AdminDestination(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
      label: AppStrings.adminNavChallenges,
      title: AppStrings.adminChallengesTitle,
    ),
  ];

  bool _isSigningOut = false;

  Future<void> _confirmSignOut() async {
    if (_isSigningOut) {
      return;
    }

    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.adminLogoutDialogTitle,
      message: AppStrings.adminLogoutDialogMessage,
      confirmLabel: AppStrings.adminLogoutConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AuthFailure catch (failure) {
      _showSignOutFailure(failure.message);
      return;
    } catch (_) {
      _showSignOutFailure(AppStrings.adminLogoutError);
      return;
    }

    // Redirect router memindahkan pengguna ke `/login` setelah status auth
    // berubah. Status tombol direset bila widget masih hidup agar tidak
    // tertahan spinner.
    if (mounted) {
      setState(() {
        _isSigningOut = false;
      });
    }
  }

  void _showSignOutFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSigningOut = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int currentIndex = widget.navigationShell.currentIndex;
    final _AdminDestination current = _destinations[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        actions: [
          IconButton(
            tooltip: AppStrings.adminLogoutLabel,
            onPressed: _isSigningOut ? null : _confirmSignOut,
            icon: _isSigningOut
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.logout),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: AppShadows.navigationBar),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (int index) {
            if (index == 0) {
              // Segarkan angka dashboard setiap tab Dashboard dipilih kembali.
              ref.invalidate(adminDashboardStatsProvider);
            }
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == currentIndex,
            );
          },
          destinations: <Widget>[
            for (final _AdminDestination destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Satu tab bottom navigation admin beserta judul AppBar-nya.
class _AdminDestination {
  const _AdminDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String title;
}
