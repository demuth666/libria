import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_dashboard_stats.dart';
import 'admin_dashboard_providers.dart';

/// Dashboard Admin pada rute `/admin` (T-031).
///
/// Menampilkan empat kartu angka dari agregasi `count()` lewat
/// [adminDashboardStatsProvider], menu ke seluruh layar admin, dan aksi
/// Keluar dengan dialog konfirmasi sesuai FR-A6.
///
/// Layar ini belum punya desain Stitch. Susunannya mengikuti PRD bagian 7 dan
/// memakai token tema yang sudah ada, sehingga otomatis mendukung mode terang
/// dan gelap. Kartu angka memakai dua kolom di ponsel dan empat kolom di layar
/// lebar.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
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
    // berubah. Tidak ada navigasi manual agar rute tetap satu sumber. Status
    // tombol direset bila widget masih hidup agar tidak tertahan spinner.
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
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.adminDashboardTitle)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.lg,
            horizontalPadding,
            AppSpacing.xl,
          ),
          child: ContentWidth(
            maxWidth: 960,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.adminDashboardSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _DashboardStats(),
                const SizedBox(height: AppSpacing.lg),
                _DashboardMenu(
                  isSigningOut: _isSigningOut,
                  onSignOut: _confirmSignOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bagian kartu angka dengan keadaan loading, galat, dan data.
class _DashboardStats extends ConsumerWidget {
  const _DashboardStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminDashboardStats> stats = ref.watch(
      adminDashboardStatsProvider,
    );

    return stats.when(
      data: (AdminDashboardStats value) => _StatsGrid(stats: value),
      loading: () => const _StatsPanel(
        child: LoadingView(message: AppStrings.adminDashboardLoading),
      ),
      error: (Object error, StackTrace stackTrace) => _StatsPanel(
        child: ErrorView(
          message: AppStrings.adminDashboardLoadError,
          onRetry: () => ref.invalidate(adminDashboardStatsProvider),
        ),
      ),
    );
  }
}

/// Permukaan kartu untuk keadaan loading dan galat bagian angka.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: child,
    );
  }
}

/// Permukaan kartu bersama untuk angka ringkasan dan keadaan loading/galat.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: child,
    );
  }
}

/// Grid kartu angka: dua kolom di ponsel dan tablet portrait, empat kolom di
/// layar lebar.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final int columns = Breakpoints.of(context) == ScreenSize.expanded ? 4 : 2;
    final List<_StatItem> items = <_StatItem>[
      _StatItem(
        icon: Icons.menu_book_outlined,
        label: AppStrings.adminStatBooksLabel,
        value: stats.totalBooks,
      ),
      _StatItem(
        icon: Icons.flag_outlined,
        label: AppStrings.adminStatOpenReportsLabel,
        value: stats.openReports,
      ),
      _StatItem(
        icon: Icons.qr_code_scanner,
        label: AppStrings.adminStatUnhandledIsbnLogsLabel,
        value: stats.unhandledIsbnLogs,
      ),
      _StatItem(
        icon: Icons.people_alt_outlined,
        label: AppStrings.adminStatUsersLabel,
        value: stats.totalUsers,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.gridGutter;
        final double cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final _StatItem item in items)
              SizedBox(
                width: cardWidth,
                child: _StatCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

/// Satu angka ringkasan pada grid.
class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return _DashboardCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: AppRadius.allMedium,
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${item.value}',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu menuju layar admin lain dan aksi Keluar.
class _DashboardMenu extends ConsumerWidget {
  const _DashboardMenu({required this.isSigningOut, required this.onSignOut});

  final bool isSigningOut;
  final VoidCallback onSignOut;

  static const List<_MenuItem> _items = <_MenuItem>[
    _MenuItem(
      icon: Icons.menu_book_outlined,
      label: AppStrings.adminMenuBooks,
      route: AppRoutes.adminBooks,
    ),
    _MenuItem(
      icon: Icons.qr_code_scanner,
      label: AppStrings.adminMenuIsbnLogs,
      route: AppRoutes.adminIsbnLogs,
    ),
    _MenuItem(
      icon: Icons.flag_outlined,
      label: AppStrings.adminMenuReports,
      route: AppRoutes.adminReports,
    ),
    _MenuItem(
      icon: Icons.event_outlined,
      label: AppStrings.adminMenuEvents,
      route: AppRoutes.adminEvents,
    ),
    _MenuItem(
      icon: Icons.emoji_events_outlined,
      label: AppStrings.adminMenuChallenges,
      route: AppRoutes.adminChallenges,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.adminDashboardMenuTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
          const Divider(),
          for (final _MenuItem item in _items) ...[
            ListTile(
              leading: Icon(item.icon, color: scheme.secondary),
              title: Text(item.label),
              trailing: Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
              onTap: () async {
                await context.push(item.route);
                if (context.mounted) {
                  // Angka dapat berubah setelah aksi di layar admin lain.
                  ref.invalidate(adminDashboardStatsProvider);
                }
              },
            ),
            const Divider(),
          ],
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(
              AppStrings.adminMenuLogout,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: isSigningOut
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.error,
                    ),
                  )
                : Icon(Icons.chevron_right, color: scheme.error),
            onTap: isSigningOut ? null : onSignOut,
          ),
        ],
      ),
    );
  }
}

/// Satu baris menu admin.
class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}
