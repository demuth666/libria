import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../books/data/book.dart';
import '../../challenges/data/challenge.dart';
import '../../challenges/data/challenge_participant.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../challenges/presentation/challenge_providers.dart';
import '../../challenges/presentation/challenge_widgets.dart';
import '../../events/data/app_event.dart';
import '../../events/data/event_repository.dart';
import '../../events/presentation/event_providers.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/library_shelves.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../data/home_activity.dart';
import '../data/home_repository.dart';
import 'home_providers.dart';

/// Layar Beranda pengguna pada rute `/home` (T-045).
///
/// Susunan mengikuti desain Stitch "Libria - Beranda & Dasbor Membaca" dan
/// PRD bagian 7: sapaan, target harian, kartu buku yang sedang dibaca,
/// statistik pekan ini, grafik tujuh hari, rekomendasi, kutipan, tantangan
/// aktif, kegiatan terdekat, dan lencana notifikasi.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider).value;
    final AsyncValue<LibraryShelfData> shelf = ref.watch(libraryShelfProvider);
    final bool isOffline = ref.watch(connectivityProvider).value == false;

    return Column(
      children: [
        const _HomeHeader(),
        Expanded(
          child: _HomeContent(
            user: user,
            shelf: shelf,
            isOffline: isOffline,
            onRetryReading: () =>
                ref.read(libraryShelfProvider.notifier).retry(),
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
    required this.isOffline,
    required this.onRetryReading,
  });

  final AppUser? user;
  final AsyncValue<LibraryShelfData> shelf;
  final bool isOffline;
  final VoidCallback onRetryReading;

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
                  _DailyTargetSection(isOffline: isOffline),
                  const SizedBox(height: AppSpacing.lg),
                  _CurrentReadingSection(
                    shelf: shelf,
                    isOffline: isOffline,
                    onRetry: onRetryReading,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _HomeActivitySection(),
                  const SizedBox(height: AppSpacing.lg),
                  const _HomeRecommendationsSection(),
                  const SizedBox(height: AppSpacing.lg),
                  const _HomeDailyQuote(),
                  const SizedBox(height: AppSpacing.lg),
                  const _HomeChallengesSection(),
                  const SizedBox(height: AppSpacing.lg),
                  const _UpcomingEventsSection(),
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
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String initial = _avatarInitial(user);
    final DateTime now = ref.watch(homeClockProvider)();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _salutation(now),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                AppStrings.homeGreeting(_firstName(user)),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: scheme.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

/// Kartu target harian beserta pil streak.
class _DailyTargetSection extends ConsumerWidget {
  const _DailyTargetSection({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeTodaySummary> today = ref.watch(
      todayReadingSummaryProvider,
    );
    final AsyncValue<HomeActivitySummary> activity = ref.watch(
      homeActivityProvider,
    );
    final bool waitingOffline = isOffline && today.isLoading && !today.hasValue;
    void retry() => ref.invalidate(todayReadingSummaryProvider);

    if (waitingOffline) {
      return _InlineErrorCard(
        message: AppStrings.homeTodayOffline,
        onRetry: retry,
        retryKey: const ValueKey<String>('home-today-retry'),
      );
    }

    return today.when(
      skipLoadingOnReload: true,
      loading: () => const _LoadingCard(message: AppStrings.homeTodayLoading),
      error: (Object error, StackTrace stackTrace) => _InlineErrorCard(
        message: _todayErrorMessage(error),
        onRetry: retry,
        retryKey: const ValueKey<String>('home-today-retry'),
      ),
      data: (HomeTodaySummary summary) => _DailyTargetCard(
        summary: summary,
        streak: activity.value?.streak ?? 0,
      ),
    );
  }
}

/// Isi kartu target harian.
class _DailyTargetCard extends StatelessWidget {
  const _DailyTargetCard({required this.summary, required this.streak});

  final HomeTodaySummary summary;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int target = homeDailyTargetMinutes;
    final int percent = target <= 0
        ? 0
        : ((summary.minutes / target) * 100).round().clamp(0, 100);

    return Container(
      key: const ValueKey<String>('home-daily-target'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          _TargetProgressRing(percent: percent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.homeDailyTargetTitle.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${summary.minutes}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: ' / $target ${AppStrings.homeDailyTargetUnit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.homeDailyTargetPages(summary.pages),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StreakPill(days: streak),
        ],
      ),
    );
  }
}

/// Cincin progres target harian.
class _TargetProgressRing extends StatelessWidget {
  const _TargetProgressRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox.square(
      dimension: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
            backgroundColor: scheme.surfaceContainerHigh,
            color: scheme.secondary,
          ),
          Center(
            child: Text(
              AppStrings.homeReadingPercent(percent),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pil jumlah hari membaca berturut-turut.
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: AppRadius.allFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppStrings.homeStreakValue(days),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Kartu statistik aktivitas pekan ini dan grafik tujuh hari.
class _HomeActivitySection extends ConsumerWidget {
  const _HomeActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeActivitySummary> activity = ref.watch(
      homeActivityProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  const _SectionTitle(title: AppStrings.homeActivityTitle),
                  Text(
                    AppStrings.homeActivitySubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey<String>('home-activity-detail'),
              onPressed: () => context.push(AppRoutes.homeStats),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppStrings.homeActivitySeeAll),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        activity.when(
          skipLoadingOnReload: true,
          loading: () =>
              const _LoadingCard(message: AppStrings.homeActivityLoading),
          error: (Object error, StackTrace stackTrace) => _InlineErrorCard(
            message: _activityErrorMessage(error),
            onRetry: () {
              ref.invalidate(homeRecentSessionsProvider);
              ref.read(libraryShelfProvider.notifier).retry();
            },
            retryKey: const ValueKey<String>('home-activity-retry'),
          ),
          data: (HomeActivitySummary summary) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActivityGrid(summary: summary),
              const SizedBox(height: AppSpacing.md),
              _HomeActivityChart(summary: summary),
            ],
          ),
        ),
      ],
    );
  }
}

/// Empat kartu ringkasan aktivitas pekan ini.
class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({required this.summary});

  final HomeActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String trend = summary.finishedBooksDelta == 0
        ? AppStrings.homeActivityTrendSame
        : AppStrings.homeActivityTrend(summary.finishedBooksDelta);
    final Color trendColor = summary.finishedBooksDelta > 0
        ? scheme.secondary
        : summary.finishedBooksDelta < 0
        ? scheme.error
        : scheme.onSurfaceVariant;
    final String durationNote = summary.minutes <= 0
        ? AppStrings.homeActivityDurationEmpty
        : AppStrings.homeActivityTarget(summary.targetPercent);

    final List<Widget> cards = <Widget>[
      _ActivityCard(
        valueKey: const ValueKey<String>('home-activity-finished'),
        label: AppStrings.homeActivityFinishedBooks,
        value: '${summary.finishedBooks}',
        icon: Icons.check_circle_outline_rounded,
        iconBackground: scheme.secondaryContainer,
        iconColor: scheme.onSecondaryContainer,
        note: trend,
        noteColor: trendColor,
      ),
      _ActivityCard(
        valueKey: const ValueKey<String>('home-activity-sessions'),
        label: AppStrings.homeActivitySessions,
        value: '${summary.sessions}',
        icon: Icons.play_circle_outline_rounded,
        iconBackground: scheme.surfaceContainerHigh,
        iconColor: scheme.primary,
        note: AppStrings.homeActivityAverage(summary.averageSessionsPerDay),
        noteColor: scheme.onSurfaceVariant,
      ),
      _ActivityCard(
        valueKey: const ValueKey<String>('home-activity-minutes'),
        label: AppStrings.homeActivityDurationLabel,
        value: AppStrings.homeActivityDuration(summary.minutes),
        icon: Icons.schedule_rounded,
        iconBackground: scheme.surfaceContainerHigh,
        iconColor: scheme.primary,
        note: durationNote,
        noteColor: summary.minutes <= 0
            ? scheme.onSurfaceVariant
            : scheme.secondary,
      ),
      _ActivityCard(
        valueKey: const ValueKey<String>('home-activity-streak'),
        label: AppStrings.homeActivityStreak,
        value: AppStrings.homeStreakValue(summary.streak),
        icon: Icons.local_fire_department_rounded,
        iconBackground: scheme.tertiaryContainer,
        iconColor: scheme.onTertiaryContainer,
        note: summary.streak > 0
            ? AppStrings.homeActivityStreakActive
            : AppStrings.homeActivityStreakEmpty,
        noteColor: summary.streak > 0
            ? scheme.secondary
            : scheme.onSurfaceVariant,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 640 ? 4 : 2;
        final List<Widget> rows = <Widget>[];
        for (int start = 0; start < cards.length; start += columns) {
          final List<Widget> rowCards = cards.sublist(
            start,
            math.min(start + columns, cards.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int index = 0; index < rowCards.length; index++) ...[
                    if (index > 0)
                      const SizedBox(width: AppSpacing.gridGutterSmall),
                    Expanded(child: rowCards[index]),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.gridGutterSmall),
              rows[index],
            ],
          ],
        );
      },
    );
  }
}

/// Satu kartu ringkasan aktivitas.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.valueKey,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.note,
    required this.noteColor,
  });

  final Key valueKey;
  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      key: valueKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: AppRadius.allMedium,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.primary,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(color: noteColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Kartu grafik menit membaca tujuh hari terakhir.
class _HomeActivityChart extends StatelessWidget {
  const _HomeActivityChart({required this.summary});

  final HomeActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isEmpty = summary.sessions == 0 && summary.minutes == 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.homeChartTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      AppStrings.homeChartSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.highestMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: AppRadius.allSmall,
                  ),
                  child: Text(
                    AppStrings.homeChartHighest(summary.highestMinutes),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isEmpty)
            Container(
              key: const ValueKey<String>('home-chart-empty'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: AppRadius.allMedium,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 28,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.homeChartEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Semantics(
              label: AppStrings.statsChartSemantics(
                homeActivityDayCount,
                summary.minutes,
              ),
              child: SizedBox(
                key: const ValueKey<String>('home-activity-chart'),
                height: 168,
                child: ExcludeSemantics(
                  child: _HomeBarChart(daily: summary.daily),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grafik batang ringkas untuk Beranda.
class _HomeBarChart extends StatelessWidget {
  const _HomeBarChart({required this.daily});

  final List<HomeDailyMinutes> daily;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int highest = daily.fold<int>(
      0,
      (int value, HomeDailyMinutes day) => math.max(value, day.minutes),
    );
    final double maxY = math.max(highest * 1.25, 1);

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceBetween,
        barGroups: List<BarChartGroupData>.generate(daily.length, (int index) {
          final HomeDailyMinutes day = daily[index];
          final bool isToday = index == daily.length - 1;
          return BarChartGroupData(
            x: index,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: day.minutes <= 0 ? 1 : day.minutes.toDouble(),
                width: 20,
                color: day.minutes <= 0
                    ? scheme.surfaceContainerHigh
                    : isToday
                    ? scheme.secondary
                    : scheme.secondaryFixedDim.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.extraSmall),
                ),
              ),
            ],
          );
        }),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.round();
                if (index < 0 || index >= daily.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: AppSpacing.xs,
                  child: Text(
                    AppDateFormatter.weekdayShort(daily[index].date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: index == daily.length - 1
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (BarChartGroupData group) => scheme.inverseSurface,
            tooltipBorderRadius: AppRadius.allSmall,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            getTooltipItem:
                (
                  BarChartGroupData group,
                  int groupIndex,
                  BarChartRodData rod,
                  int rodIndex,
                ) {
                  final HomeDailyMinutes day = daily[group.x];
                  return BarTooltipItem(
                    AppStrings.statsChartTooltip(
                      AppDateFormatter.dayMonthShort(day.date),
                      day.minutes,
                    ),
                    theme.textTheme.labelSmall!.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  );
                },
          ),
        ),
      ),
    );
  }
}

/// Bagian rekomendasi buku dari katalog.
class _HomeRecommendationsSection extends ConsumerWidget {
  const _HomeRecommendationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Book>> books = ref.watch(
      homeRecommendedBooksProvider,
    );
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    title: AppStrings.homeRecommendationsTitle,
                  ),
                  Text(
                    AppStrings.homeRecommendationsSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey<String>('home-recommendations-see-all'),
              onPressed: () => context.push(AppRoutes.homeLibrarySearch),
              child: const Text(AppStrings.homeRecommendationsSeeAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        books.when(
          skipLoadingOnReload: true,
          loading: () => const _LoadingCard(
            message: AppStrings.homeRecommendationsLoading,
          ),
          error: (Object error, StackTrace stackTrace) => _InlineErrorCard(
            message: AppStrings.homeRecommendationsLoadError,
            onRetry: () => ref.invalidate(homeRecommendedBooksProvider),
            retryKey: const ValueKey<String>('home-recommendations-retry'),
          ),
          data: (List<Book> data) {
            if (data.isEmpty) {
              return const _EmptySlotCard(
                key: ValueKey<String>('home-recommendations-empty'),
                icon: Icons.menu_book_outlined,
                message: AppStrings.homeRecommendationsEmpty,
              );
            }
            return SizedBox(
              height: 322,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: data.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: AppSpacing.gridGutterSmall),
                itemBuilder: (BuildContext context, int index) =>
                    _HomeBookCard(book: data[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Satu kartu buku pada carousel rekomendasi.
class _HomeBookCard extends StatelessWidget {
  const _HomeBookCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String category = book.category.trim();

    return SizedBox(
      width: 148,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.allLarge,
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('home-book-${book.id}'),
            onTap: () => context.push(AppRoutes.bookDetailPath(book.id)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      BookCoverImage(
                        coverUrl: book.coverUrl,
                        width: 132,
                        height: 176,
                        borderRadius: AppRadius.allMedium,
                      ),
                      if (category.isNotEmpty)
                        Positioned(
                          top: AppSpacing.xs,
                          left: AppSpacing.xs,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 110),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLowest.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: AppRadius.allSmall,
                            ),
                            child: Text(
                              category,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    book.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    book.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          AppStrings.homeBookPages(book.totalPages),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

/// Kartu kutipan harian.
class _HomeDailyQuote extends ConsumerWidget {
  const _HomeDailyQuote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ({String text, String source}) quote = ref.watch(
      homeDailyQuoteProvider,
    );

    return Container(
      key: const ValueKey<String>('home-daily-quote'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: scheme.secondary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 24,
                          color: scheme.secondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            quote.text,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: scheme.primary,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.homeQuoteAttribution(quote.source),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

/// Tantangan aktif di Beranda dengan maksimal dua tantangan (T-090).
class _HomeChallengesSection extends ConsumerWidget {
  const _HomeChallengesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Challenge>> challenges = ref.watch(
      homeActiveChallengesProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle(title: AppStrings.homeChallengesTitle),
            ),
            TextButton(
              key: const ValueKey<String>('home-challenges-see-all'),
              onPressed: () => context.push(AppRoutes.challenges),
              child: const Text(AppStrings.challengesSeeAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        challenges.when(
          skipLoadingOnReload: true,
          loading: () =>
              const _LoadingCard(message: AppStrings.challengesLoading),
          error: (Object error, StackTrace stackTrace) => _InlineErrorCard(
            message: _challengesErrorMessage(error),
            onRetry: () => ref.invalidate(homeActiveChallengesProvider),
            retryKey: const ValueKey<String>('home-challenges-retry'),
          ),
          data: (List<Challenge> data) {
            if (data.isEmpty) {
              return const _EmptySlotCard(
                key: ValueKey<String>('home-challenges-empty'),
                icon: Icons.flag_outlined,
                message: AppStrings.homeChallengesEmpty,
              );
            }
            return Column(
              children: [
                for (int index = 0; index < data.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.sm),
                  _HomeChallengeTile(challenge: data[index]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Satu tantangan aktif pada Beranda beserta bar progres pengguna.
class _HomeChallengeTile extends ConsumerWidget {
  const _HomeChallengeTile({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startDate = challenge.startDate;
    final DateTime? endDate = challenge.endDate;
    final AsyncValue<ChallengeParticipant?> participation = ref.watch(
      challengeParticipationProvider(challenge.id),
    );
    final ChallengeParticipant? participant = participation.value;

    return Card(
      key: ValueKey<String>('home-challenge-${challenge.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.challengeDetailPath(challenge.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: AppRadius.allMedium,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.emoji_events_outlined,
                      size: 20,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ChallengeTypeBadge(type: challenge.type),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          startDate == null || endDate == null
                              ? AppStrings.challengesDateUnavailable
                              : AppStrings.challengesDateRange(
                                  AppDateFormatter.date(startDate),
                                  AppDateFormatter.date(endDate),
                                ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (participation.isLoading && !participation.hasValue)
                Text(
                  AppStrings.challengeProgressLoading,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else if (participation.hasError)
                Text(
                  AppStrings.challengeParticipationLoadError,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.error,
                  ),
                )
              else
                ChallengeProgressBar(
                  challenge: challenge,
                  progress: participant?.progress ?? 0,
                  label: participant == null
                      ? AppStrings.challengeNotJoined
                      : AppStrings.challengeProgressLabel,
                  dense: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kegiatan terdekat di Beranda dengan maksimal dua kegiatan (T-088).
class _UpcomingEventsSection extends ConsumerWidget {
  const _UpcomingEventsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppEvent>> eventsState = ref.watch(
      homeUpcomingEventsProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle(title: AppStrings.homeEventsTitle),
            ),
            TextButton(
              key: const ValueKey<String>('home-events-see-all'),
              onPressed: () => context.push(AppRoutes.events),
              child: const Text(AppStrings.homeEventsSeeAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        eventsState.when(
          skipLoadingOnReload: true,
          loading: () =>
              const _LoadingCard(message: AppStrings.homeEventsLoading),
          error: (Object error, StackTrace stackTrace) => _InlineErrorCard(
            message: _eventsErrorMessage(error),
            onRetry: () => ref.invalidate(homeUpcomingEventsProvider),
            retryKey: const ValueKey<String>('home-events-retry'),
          ),
          data: (List<AppEvent> events) {
            if (events.isEmpty) {
              return const _EmptySlotCard(
                key: ValueKey<String>('home-events-empty'),
                icon: Icons.event_outlined,
                message: AppStrings.homeEventsEmpty,
              );
            }
            return Column(
              children: [
                for (int index = 0; index < events.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.sm),
                  _HomeEventTile(event: events[index]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Satu kegiatan terdekat pada Beranda.
class _HomeEventTile extends StatelessWidget {
  const _HomeEventTile({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startAt = event.startAt;

    return Card(
      key: ValueKey<String>('home-event-${event.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.eventDetailPath(event.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: AppRadius.allMedium,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.event_available_outlined,
                  size: 20,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      startAt == null
                          ? AppStrings.eventsTimeUnavailable
                          : AppDateFormatter.dateTime(startAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppStrings.eventsParticipantCount(event.participantCount),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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

String _activityErrorMessage(Object error) {
  if (error is HomeFailure) {
    return error.message;
  }
  if (error is LibraryFailure) {
    return error.message;
  }
  return AppStrings.homeActivityLoadError;
}

String _salutation(DateTime now) {
  if (now.hour < 11) {
    return AppStrings.homeSalutationMorning;
  }
  if (now.hour < 15) {
    return AppStrings.homeSalutationNoon;
  }
  if (now.hour < 19) {
    return AppStrings.homeSalutationAfternoon;
  }
  return AppStrings.homeSalutationEvening;
}

String _eventsErrorMessage(Object error) {
  return error is EventFailure ? error.message : AppStrings.homeEventsLoadError;
}

String _challengesErrorMessage(Object error) {
  return error is ChallengeFailure
      ? error.message
      : AppStrings.challengesLoadError;
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
