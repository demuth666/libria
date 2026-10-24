import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/library_shelves.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../data/home_repository.dart';
import 'home_providers.dart';

/// Layar Beranda pengguna pada rute `/home` (T-045).
///
/// Susunan mengikuti desain Stitch "Libria - Beranda & Dasbor Membaca" dan
/// PRD bagian 7: sapaan, kartu buku yang sedang dibaca, ringkasan hari ini,
/// dan aksi cepat. Slot tantangan, kegiatan, serta lencana notifikasi masih
/// berupa keadaan kosong dan diisi pada task fase 8.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider).value;
    final AsyncValue<LibraryShelfData> shelf = ref.watch(libraryShelfProvider);
    final AsyncValue<HomeTodaySummary> today = ref.watch(
      todayReadingSummaryProvider,
    );
    final bool isOffline = ref.watch(connectivityProvider).value == false;

    return Column(
      children: [
        const _HomeHeader(),
        Expanded(
          child: _HomeContent(
            user: user,
            shelf: shelf,
            today: today,
            isOffline: isOffline,
            onRetryReading: () =>
                ref.read(libraryShelfProvider.notifier).retry(),
            onRetryToday: () => ref.invalidate(todayReadingSummaryProvider),
          ),
        ),
      ],
    );
  }
}

/// Header tetap Beranda: judul, pencarian katalog, dan slot notifikasi.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ScreenHeader(
      title: AppStrings.homeTitle,
      leading: Icon(
        Icons.auto_stories_outlined,
        size: 24,
        color: scheme.secondary,
      ),
      actions: <Widget>[
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: AppStrings.catalogSearchTitle,
            padding: EdgeInsets.zero,
            onPressed: () => context.push(AppRoutes.homeLibrarySearch),
            icon: const Icon(Icons.search),
          ),
        ),
        // Lencana jumlah notifikasi mengikuti stream subkoleksi notifikasi
        // pengguna (T-086).
        const NotificationBellButton(),
      ],
    );
  }
}

/// Isi Beranda yang dapat digulir.
class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
    required this.shelf,
    required this.today,
    required this.isOffline,
    required this.onRetryReading,
    required this.onRetryToday,
  });

  final AppUser? user;
  final AsyncValue<LibraryShelfData> shelf;
  final AsyncValue<HomeTodaySummary> today;
  final bool isOffline;
  final VoidCallback onRetryReading;
  final VoidCallback onRetryToday;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom +
        AppBottomNavBar.height +
        AppSpacing.lg;

    return CustomScrollView(
      key: const PageStorageKey<String>('home'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            bottomInset,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 960,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Greeting(user: user),
                  const SizedBox(height: AppSpacing.md),
                  _CurrentReadingSection(
                    shelf: shelf,
                    isOffline: isOffline,
                    onRetry: onRetryReading,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(title: AppStrings.homeTodayTitle),
                  const SizedBox(height: AppSpacing.sm),
                  _TodaySummaryCard(
                    today: today,
                    isOffline: isOffline,
                    onRetry: onRetryToday,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(title: AppStrings.homeQuickActionsTitle),
                  const SizedBox(height: AppSpacing.sm),
                  const _QuickActions(),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(title: AppStrings.homeChallengesTitle),
                  const SizedBox(height: AppSpacing.sm),
                  const _EmptySlotCard(
                    key: ValueKey<String>('home-challenges-empty'),
                    icon: Icons.flag_outlined,
                    message: AppStrings.homeChallengesEmpty,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(title: AppStrings.homeEventsTitle),
                  const SizedBox(height: AppSpacing.sm),
                  const _EmptySlotCard(
                    key: ValueKey<String>('home-events-empty'),
                    icon: Icons.event_outlined,
                    message: AppStrings.homeEventsEmpty,
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

/// Sapaan dan avatar pengguna.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String initial = _avatarInitial(user);

    return Row(
      children: [
        Semantics(
          label: AppStrings.libraryAvatarLabel,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 2),
            ),
            alignment: Alignment.center,
            child: initial.isEmpty
                ? Icon(
                    Icons.person_outline,
                    size: 24,
                    color: scheme.onPrimaryContainer,
                  )
                : Text(
                    initial,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            AppStrings.homeGreeting(_firstName(user)),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.primary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Bagian buku yang sedang dibaca, dengan keadaan memuat, galat, dan kosong.
class _CurrentReadingSection extends StatelessWidget {
  const _CurrentReadingSection({
    required this.shelf,
    required this.isOffline,
    required this.onRetry,
  });

  final AsyncValue<LibraryShelfData> shelf;
  final bool isOffline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final LibraryShelfData? data = shelf.value;
    if (data != null) {
      final LibraryEntry? reading = _readingEntry(data.entries);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reading != null)
            _ReadingHero(entry: reading)
          else
            _NoReadingCard(
              onChooseBook: () => context.go(AppRoutes.homeLibrary),
            ),
          if (data.streamError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineNotice(
              message: AppStrings.homeReadingStale,
              onRetry: onRetry,
              retryKey: const ValueKey<String>('home-reading-stale-retry'),
            ),
          ],
        ],
      );
    }

    if (shelf.hasError) {
      return _InlineErrorCard(
        message: _libraryErrorMessage(shelf.error),
        onRetry: onRetry,
        retryKey: const ValueKey<String>('home-reading-retry'),
      );
    }

    if (isOffline) {
      return _InlineErrorCard(
        message: AppStrings.homeReadingOffline,
        onRetry: onRetry,
        retryKey: const ValueKey<String>('home-reading-retry'),
      );
    }

    return const _LoadingCard(message: AppStrings.homeReadingLoading);
  }
}

/// Kartu hero buku yang sedang dibaca.
class _ReadingHero extends StatelessWidget {
  const _ReadingHero({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    // Hero gelap navy pada mode terang; primaryContainer dipakai di mode gelap
    // agar latarnya tetap navy dan teksnya tetap kontras.
    final Color background = isDark ? scheme.primaryContainer : scheme.primary;
    final Color foreground = isDark
        ? scheme.onPrimaryContainer
        : scheme.onPrimary;
    final Color accent = scheme.secondaryFixed;
    final double ratio = libraryProgressRatio(entry);
    final int percent = libraryProgressPercent(entry);

    return Container(
      key: ValueKey<String>('home-reading-${entry.bookId}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.homeReadingLabel,
                  style: theme.textTheme.labelMedium?.copyWith(color: accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppStrings.homeReadingPercent(percent),
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCoverImage(
                coverUrl: entry.bookCoverUrl,
                width: 80,
                height: 112,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.bookTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.bookAuthor,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.78),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.homeReadingProgress,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: foreground.withValues(alpha: 0.78),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            AppStrings.pagesRead(
                              entry.currentPage,
                              entry.bookTotalPages,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: AppRadius.allFull,
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: AppSpacing.sm,
                        backgroundColor: foreground.withValues(alpha: 0.22),
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey<String>('home-continue-reading'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
            ),
            onPressed: () =>
                context.push(AppRoutes.sessionSetupPath(entry.bookId)),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(AppStrings.homeContinueReading),
          ),
        ],
      ),
    );
  }
}

/// Ajakan memilih buku ketika belum ada buku berstatus Sedang Dibaca.
class _NoReadingCard extends StatelessWidget {
  const _NoReadingCard({required this.onChooseBook});

  final VoidCallback onChooseBook;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      key: const ValueKey<String>('home-reading-empty'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_stories_outlined,
              size: 28,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.homeReadingEmptyTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.homeReadingEmptyMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: AppStrings.homeChooseBook,
            icon: Icons.local_library_outlined,
            onPressed: onChooseBook,
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkasan menit dan halaman hari ini.
class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.today,
    required this.isOffline,
    required this.onRetry,
  });

  final AsyncValue<HomeTodaySummary> today;
  final bool isOffline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool waitingOffline = isOffline && today.isLoading && !today.hasValue;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: waitingOffline
          ? _InlineErrorContent(
              message: AppStrings.homeTodayOffline,
              onRetry: onRetry,
              retryKey: const ValueKey<String>('home-today-retry'),
            )
          : today.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const _LoadingContent(message: AppStrings.homeTodayLoading),
              error: (Object error, StackTrace stackTrace) =>
                  _InlineErrorContent(
                    message: _todayErrorMessage(error),
                    onRetry: onRetry,
                    retryKey: const ValueKey<String>('home-today-retry'),
                  ),
              data: (HomeTodaySummary summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: Icons.schedule_rounded,
                          value: AppStrings.homeMinutesValue(summary.minutes),
                          label: AppStrings.homeMinutesLabel,
                          iconBackground: scheme.secondaryContainer,
                          iconColor: scheme.onSecondaryContainer,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 64,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        color: scheme.outlineVariant,
                      ),
                      Expanded(
                        child: _Metric(
                          icon: Icons.auto_stories_rounded,
                          value: AppStrings.homePagesValue(summary.pages),
                          label: AppStrings.homePagesLabel,
                          iconBackground: scheme.surfaceContainerHigh,
                          iconColor: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (summary.minutes == 0 && summary.pages == 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.homeTodayEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Satu angka pada kartu ringkasan hari ini.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconBackground,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: AppRadius.allMedium,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: scheme.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Dua aksi cepat: memulai sesi dan memindai ISBN.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickActionCard(
              key: const ValueKey<String>('home-action-session'),
              icon: Icons.play_circle_outline_rounded,
              label: AppStrings.homeStartSession,
              onTap: () => context.push(AppRoutes.sessionSetup),
              highlighted: true,
            ),
          ),
          const SizedBox(width: AppSpacing.gridGutterSmall),
          Expanded(
            child: _QuickActionCard(
              key: const ValueKey<String>('home-action-scan'),
              icon: Icons.qr_code_scanner_rounded,
              label: AppStrings.homeScanIsbn,
              onTap: () => context.push(AppRoutes.isbnScan),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu kartu aksi cepat.
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color background = highlighted
        ? scheme.secondary
        : scheme.surfaceContainerLowest;
    final Color foreground = highlighted ? scheme.onSecondary : scheme.primary;
    final Color iconBackground = highlighted
        ? foreground.withValues(alpha: 0.14)
        : scheme.surfaceContainerHigh;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.allLarge,
        boxShadow: highlighted ? AppShadows.level1 : AppShadows.card,
      ),
      child: Material(
        color: background,
        borderRadius: AppRadius.allLarge,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: AppRadius.allMedium,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 22, color: foreground),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

/// Slot keadaan kosong untuk tantangan dan kegiatan (diisi pada fase 8).
class _EmptySlotCard extends StatelessWidget {
  const _EmptySlotCard({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul bagian Beranda.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// Kartu pemuatan ringkas.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: _LoadingContent(message: message),
    );
  }
}

/// Isi pemuatan dengan indikator dan pesan.
class _LoadingContent extends StatelessWidget {
  const _LoadingContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartu galat ringkas dengan tombol coba lagi.
class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({
    required this.message,
    required this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: _InlineErrorContent(
        message: message,
        onRetry: onRetry,
        retryKey: retryKey,
      ),
    );
  }
}

/// Isi galat yang dipakai di dalam kartu.
class _InlineErrorContent extends StatelessWidget {
  const _InlineErrorContent({
    required this.message,
    required this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off_outlined, size: 20, color: scheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          key: retryKey,
          onPressed: onRetry,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }
}

/// Pemberitahuan ringan ketika data rak tidak dapat diperbarui.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.sync_problem_rounded,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          key: retryKey,
          onPressed: onRetry,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }
}

LibraryEntry? _readingEntry(List<LibraryEntry> entries) {
  for (final LibraryEntry entry in entries) {
    if (entry.status == LibraryEntry.statusReading) {
      return entry;
    }
  }
  return null;
}

String _libraryErrorMessage(Object? error) {
  return error is LibraryFailure
      ? error.message
      : AppStrings.homeReadingLoadError;
}

String _todayErrorMessage(Object error) {
  return error is HomeFailure ? error.message : AppStrings.homeTodayLoadError;
}

String _firstName(AppUser? user) {
  final String name = user?.displayName.trim() ?? '';
  if (name.isEmpty) {
    return AppStrings.homeReaderFallback;
  }
  return name.split(RegExp(r'\s+')).first;
}

String _avatarInitial(AppUser? user) {
  final String name = user?.displayName.trim() ?? '';
  if (name.isEmpty) {
    return '';
  }
  return String.fromCharCode(name.runes.first).toUpperCase();
}
