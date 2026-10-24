import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/data/app_user.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/settings_repository.dart';
import '../data/theme_preference.dart';
import 'settings_providers.dart';

/// Layar Pengaturan pengguna pada rute `/home/settings` (T-095).
///
/// Susunan mengikuti desain Stitch "Libria - Profil & Ringkasan Pengguna" dan
/// PRD bagian 5.11 serta 7: kartu profil, pilihan tampilan, pintasan Jurnal dan
/// Laporan, versi aplikasi, serta tombol Keluar dengan konfirmasi. Ringkasan
/// statistik pada desain tidak ditampilkan karena sudah tersedia di Beranda dan
/// layar Statistik.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _selectTheme(ThemePreference preference) async {
    try {
      await ref.read(themePreferenceProvider.notifier).select(preference);
    } on SettingsFailure catch (failure) {
      _showMessage(failure.message);
    } catch (_) {
      _showMessage(AppStrings.settingsThemeSaveError);
    }
  }

  Future<void> _confirmSignOut() async {
    if (_isSigningOut) {
      return;
    }

    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.settingsLogoutDialogTitle,
      message: AppStrings.settingsLogoutDialogMessage,
      confirmLabel: AppStrings.settingsLogoutConfirm,
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
      _showSignOutFailure(AppStrings.settingsLogoutError);
      return;
    }

    // Redirect router memindahkan pengguna ke `/login` setelah status auth
    // berubah. Status tombol direset bila widget masih hidup.
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
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AsyncValue<AppUser?> user = ref.watch(currentUserProvider);
    final ThemePreference themePreference =
        ref.watch(themePreferenceProvider).value ?? ThemePreference.system;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom +
        AppBottomNavBar.height +
        AppSpacing.lg;

    return Column(
      children: [
        ScreenHeader(
          title: AppStrings.profileTitle,
          leading: Icon(
            Icons.auto_stories_outlined,
            size: 24,
            color: scheme.secondary,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey<String>('settings'),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              bottomInset,
            ),
            child: ContentWidth(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileCard(
                    user: user,
                    onRetry: () => ref.invalidate(currentUserProvider),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(
                    title: AppStrings.settingsDisplaySectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DisplayModeCard(
                    current: themePreference,
                    onChanged: _selectTheme,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(
                    title: AppStrings.settingsShortcutsSectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _ShortcutCard(),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(
                    title: AppStrings.settingsAboutSectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _AboutCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _LogoutButton(
                    isLoading: _isSigningOut,
                    onPressed: _confirmSignOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartu identitas pengguna dengan keadaan memuat, galat, dan kosong.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onRetry});

  final AsyncValue<AppUser?> user;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: user.when(
        data: (AppUser? value) {
          if (value == null) {
            return const EmptyView(
              title: AppStrings.settingsProfileEmptyTitle,
              message: AppStrings.settingsProfileEmptyMessage,
              icon: Icons.person_off_outlined,
            );
          }
          return _ProfileIdentity(user: value);
        },
        loading: () =>
            const LoadingView(message: AppStrings.settingsProfileLoading),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          message: AppStrings.settingsProfileLoadError,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

/// Avatar, nama, dan email pengguna.
class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String name = user.displayName.trim();
    final String email = user.email.trim();

    return Column(
      children: [
        _ProfileAvatar(user: user),
        const SizedBox(height: AppSpacing.md),
        Text(
          name.isEmpty ? AppStrings.settingsProfileFallbackName : name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          email.isEmpty ? AppStrings.settingsProfileEmailEmpty : email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Avatar bulat: foto akun Google bila ada, atau huruf awal nama.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String initial = _avatarInitial(user);
    final Widget fallback = _AvatarInitial(initial: initial);
    final String? photoUrl = user.photoUrl;

    return Semantics(
      label: AppStrings.settingsAvatarLabel,
      image: true,
      child: Container(
        width: 104,
        height: 104,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.secondaryFixed,
        ),
        child: ClipOval(
          child: ColoredBox(
            color: scheme.primaryContainer,
            child: photoUrl == null || photoUrl.isEmpty
                ? fallback
                : CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) => fallback,
                    errorWidget: (
                      BuildContext context,
                      String url,
                      Object error,
                    ) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Huruf awal nama pada avatar, atau ikon orang bila nama kosong.
class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (initial.isEmpty) {
      return Icon(
        Icons.person_outline,
        size: 44,
        color: scheme.onPrimaryContainer,
      );
    }
    return Center(
      child: Text(
        initial,
        style: theme.textTheme.headlineLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Pilihan tampilan: Ikuti sistem, Terang, dan Gelap.
class _DisplayModeCard extends StatelessWidget {
  const _DisplayModeCard({required this.current, required this.onChanged});

  final ThemePreference current;
  final ValueChanged<ThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.settingsDisplayDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          RadioGroup<ThemePreference>(
            groupValue: current,
            onChanged: (ThemePreference? value) {
              if (value != null) {
                onChanged(value);
              }
            },
            child: Column(
              children: [
                for (
                  int index = 0;
                  index < ThemePreference.values.length;
                  index++
                ) ...[
                  if (index > 0) const Divider(height: 1),
                  _ThemeOptionTile(
                    preference: ThemePreference.values[index],
                    selected: ThemePreference.values[index] == current,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris pilihan tampilan.
class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({required this.preference, required this.selected});

  final ThemePreference preference;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return RadioListTile<ThemePreference>(
      value: preference,
      selected: selected,
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? scheme.secondaryContainer : scheme.surfaceContainer,
          borderRadius: AppRadius.allMedium,
        ),
        child: Icon(
          _icon,
          size: 20,
          color: selected
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(_label),
      subtitle: Text(_description),
    );
  }

  String get _label {
    return switch (preference) {
      ThemePreference.system => AppStrings.settingsThemeSystem,
      ThemePreference.light => AppStrings.settingsThemeLight,
      ThemePreference.dark => AppStrings.settingsThemeDark,
    };
  }

  String get _description {
    return switch (preference) {
      ThemePreference.system => AppStrings.settingsThemeSystemDescription,
      ThemePreference.light => AppStrings.settingsThemeLightDescription,
      ThemePreference.dark => AppStrings.settingsThemeDarkDescription,
    };
  }

  IconData get _icon {
    return switch (preference) {
      ThemePreference.system => Icons.brightness_auto_outlined,
      ThemePreference.light => Icons.light_mode_outlined,
      ThemePreference.dark => Icons.dark_mode_outlined,
    };
  }
}

/// Pintasan menuju Jurnal dan Laporan.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _SettingsMenuTile(
            icon: Icons.edit_note,
            iconBackground: scheme.secondaryContainer,
            iconForeground: scheme.onSecondaryContainer,
            title: AppStrings.settingsJournalTitle,
            subtitle: AppStrings.settingsJournalSubtitle,
            onTap: () => context.push(AppRoutes.journal),
          ),
          const Divider(height: 1),
          _SettingsMenuTile(
            icon: Icons.picture_as_pdf_outlined,
            iconBackground: scheme.primaryContainer,
            iconForeground: scheme.onPrimaryContainer,
            title: AppStrings.settingsReportTitle,
            subtitle: AppStrings.settingsReportSubtitle,
            onTap: () => context.push(AppRoutes.report),
          ),
        ],
      ),
    );
  }
}

/// Baris menu dengan ikon berwarna, judul, keterangan, dan tanda panah.
class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: AppRadius.allMedium,
        ),
        child: Icon(icon, size: 22, color: iconForeground),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: scheme.outline),
    );
  }
}

/// Kartu versi aplikasi.
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: AppRadius.allMedium,
          ),
          child: Icon(
            Icons.info_outline,
            size: 22,
            color: scheme.onSurfaceVariant,
          ),
        ),
        title: const Text(AppStrings.settingsAboutTitle),
        subtitle: Text(AppStrings.settingsAboutVersion(AppInfo.version)),
      ),
    );
  }
}

/// Tombol Keluar dengan gaya bahaya yang lembut sesuai desain Stitch.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey<String>('settings-logout'),
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
          disabledBackgroundColor: scheme.errorContainer.withValues(alpha: 0.6),
          disabledForegroundColor: scheme.onErrorContainer.withValues(
            alpha: 0.6,
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout, size: 20),
        label: const Text(AppStrings.settingsLogout),
      ),
    );
  }
}

/// Judul bagian di atas kartu pengaturan.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Permukaan kartu bersama untuk seluruh bagian Pengaturan.
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.level1,
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLarge,
          side: BorderSide(color: extras.cardBorder),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

String _avatarInitial(AppUser user) {
  final String name = user.displayName.trim();
  if (name.isEmpty) {
    return '';
  }
  return String.fromCharCode(name.runes.first).toUpperCase();
}
