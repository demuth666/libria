import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/reading_stats.dart';
import '../data/reading_stats_repository.dart';
import 'reading_stats_providers.dart';

/// Layar Statistik pada rute `/home/stats` (T-071, FR-T1 dan FR-T2).
///
/// Menampilkan kartu ringkasan, grafik batang menit membaca per hari dengan
/// pilihan 7 atau 30 hari, serta tautan ke riwayat sesi. Layar ini tidak ada
/// di Stitch; susunannya mengikuti PRD bagian 5.6b dan bahasa visual kartu
/// Beranda. Data sesi dan buku selesai dibaca lewat [ReadingStatsRepository]
/// agar widget tidak menyentuh Firestore secara langsung.
class ReadingStatsScreen extends ConsumerStatefulWidget {
  const ReadingStatsScreen({this.today, super.key});

  /// Tanggal acuan untuk streak dan grafik. Bila kosong, memakai waktu
  /// perangkat. Parameter ini dipakai uji agar hasilnya deterministik.
  final DateTime? today;

  @override
  ConsumerState<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends ConsumerState<ReadingStatsScreen> {
  int _dayCount = 7;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<ReadingStatsData> stats = ref.watch(readingStatsProvider);
    final DateTime today = widget.today ?? DateTime.now();

    return Column(
      children: [
        ScreenHeader(
          title: AppStrings.statsTitle,
          leading: Icon(
            Icons.insights_rounded,
            size: 24,
            color: theme.colorScheme.secondary,
          ),
        ),
        Expanded(
          child: stats.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(message: AppStrings.statsLoading),
            error: (Object error, StackTrace stackTrace) => ErrorView(
              message: _statsErrorMessage(error),
              onRetry: () => ref.read(readingStatsProvider.notifier).retry(),
            ),
            data: (ReadingStatsData data) => _StatsContent(
              data: data,
              today: today,
              dayCount: _dayCount,
              onDayCountChanged: (int value) {
                if (value == _dayCount) {
                  return;
                }
                setState(() => _dayCount = value);
              },
              onRetry: () => ref.read(readingStatsProvider.notifier).retry(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Isi tab Statistik yang dapat digulir.
class _StatsContent extends StatelessWidget {
  const _StatsContent({
    required this.data,
    required this.today,
    required this.dayCount,
    required this.onDayCountChanged,
    required this.onRetry,
  });

  final ReadingStatsData data;
  final DateTime today;
  final int dayCount;
  final ValueChanged<int> onDayCountChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ReadingStats summary = ReadingStatsCalculator.summary(
      sessions: data.sessions,
      today: today,
      libraryEntries: data.finishedBooks,
    );
    final List<DailyReadingMinutes> daily =
        ReadingStatsCalculator.minutesPerDay(
          data.sessions,
          endDay: today,
          dayCount: dayCount,
        );
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom +
        AppBottomNavBar.height +
        AppSpacing.lg;

    return CustomScrollView(
      key: const PageStorageKey<String>('reading-stats'),
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
                  if (data.streamError != null) ...[
                    _StaleNotice(message: data.streamError!, onRetry: onRetry),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const _SectionHeading(
                    title: AppStrings.statsSummaryTitle,
                    subtitle: AppStrings.statsSummarySubtitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryGrid(stats: summary),
                  const SizedBox(height: AppSpacing.lg),
                  _ChartCard(
                    daily: daily,
                    dayCount: dayCount,
                    isEmpty: data.isEmpty,
                    onDayCountChanged: onDayCountChanged,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SecondaryButton(
                    key: const ValueKey<String>('stats-session-history'),
                    label: AppStrings.statsSessionHistoryAction,
                    icon: Icons.history_rounded,
                    expand: true,
                    onPressed: () => context.push(AppRoutes.homeStatsHistory),
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

/// Judul bagian beserta keterangan singkat.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Empat kartu ringkasan dalam grid dua atau empat kolom.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final List<Widget> cards = <Widget>[
      _MetricCard(
        label: AppStrings.statsTotalMinutesLabel,
        value: '${stats.totalMinutes}',
        valueKey: const ValueKey<String>('stats-total-minutes'),
        icon: Icons.timer_outlined,
        iconBackground: scheme.secondaryContainer,
        iconColor: scheme.onSecondaryContainer,
      ),
      _MetricCard(
        label: AppStrings.statsTotalPagesLabel,
        value: '${stats.totalPages}',
        valueKey: const ValueKey<String>('stats-total-pages'),
        icon: Icons.auto_stories_rounded,
        iconBackground: scheme.surfaceContainerHigh,
        iconColor: scheme.primary,
      ),
      _MetricCard(
        label: AppStrings.statsFinishedBooksLabel,
        value: '${stats.finishedBooks}',
        valueKey: const ValueKey<String>('stats-finished-books'),
        icon: Icons.check_circle_outline_rounded,
        iconBackground: scheme.secondaryContainer,
        iconColor: scheme.onSecondaryContainer,
      ),
      _MetricCard(
        label: AppStrings.statsStreakLabel,
        value: '${stats.currentStreak}',
        valueKey: const ValueKey<String>('stats-streak'),
        icon: Icons.local_fire_department_rounded,
        iconBackground: scheme.tertiaryContainer,
        iconColor: scheme.onTertiaryContainer,
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

/// Satu kartu ringkasan statistik.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String label;
  final String value;
  final Key valueKey;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return _StatsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: AppRadius.allMedium,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: valueKey,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: scheme.primary,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu grafik batang dengan pemilih rentang 7 atau 30 hari.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.daily,
    required this.dayCount,
    required this.isEmpty,
    required this.onDayCountChanged,
  });

  final List<DailyReadingMinutes> daily;
  final int dayCount;
  final bool isEmpty;
  final ValueChanged<int> onDayCountChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int highest = daily.fold<int>(
      0,
      (int value, DailyReadingMinutes day) => math.max(value, day.minutes),
    );
    final int totalMinutes = daily.fold<int>(
      0,
      (int value, DailyReadingMinutes day) => value + day.minutes,
    );

    return _StatsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.allMedium,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.statsChartTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      AppStrings.statsChartSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (!isEmpty && highest > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.statsChartHighest(highest),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.statsRangeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _RangeSelector(dayCount: dayCount, onChanged: onDayCountChanged),
          const SizedBox(height: AppSpacing.md),
          if (isEmpty)
            const _ChartEmptyState()
          else
            Semantics(
              label: AppStrings.statsChartSemantics(dayCount, totalMinutes),
              child: SizedBox(
                height: 232,
                child: ExcludeSemantics(
                  child: _StatsBarChart(daily: daily, dayCount: dayCount),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pemilih rentang grafik 7 atau 30 hari.
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.dayCount, required this.onChanged});

  final int dayCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Widget chip({required int days, required String label, required Key key}) {
      final bool selected = dayCount == days;
      return ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        onSelected: (bool value) {
          if (value) {
            onChanged(days);
          }
        },
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        chip(
          days: 7,
          label: AppStrings.statsRange7,
          key: const ValueKey<String>('stats-range-7'),
        ),
        chip(
          days: 30,
          label: AppStrings.statsRange30,
          key: const ValueKey<String>('stats-range-30'),
        ),
      ],
    );
  }
}

/// Grafik batang menit membaca per hari.
class _StatsBarChart extends StatelessWidget {
  const _StatsBarChart({required this.daily, required this.dayCount});

  final List<DailyReadingMinutes> daily;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int highest = daily.fold<int>(
      0,
      (int value, DailyReadingMinutes day) => math.max(value, day.minutes),
    );
    final int step = _axisStep(highest);
    final double maxY =
        ((math.max(highest, 1) * 1.2) / step).ceilToDouble() * step;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double barWidth =
            (((constraints.maxWidth - 40) / math.max(daily.length, 1)) * 0.55)
                .clamp(3.0, 20.0)
                .toDouble();

        return BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceBetween,
            barGroups: List<BarChartGroupData>.generate(daily.length, (
              int index,
            ) {
              final DailyReadingMinutes day = daily[index];
              final bool isToday = index == daily.length - 1;
              return BarChartGroupData(
                x: index,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: day.minutes.toDouble(),
                    width: barWidth,
                    color: day.minutes <= 0
                        ? scheme.surfaceContainerHigh
                        : isToday
                        ? scheme.secondary
                        : scheme.secondaryFixedDim.withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.extraSmall),
                    ),
                  ),
                ],
              );
            }),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: step.toDouble(),
              getDrawingHorizontalLine: (double value) =>
                  FlLine(color: scheme.outlineVariant, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: step.toDouble(),
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return SideTitleWidget(
                      meta: meta,
                      space: AppSpacing.xs,
                      child: Text(
                        value.round().toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.round();
                    if (index < 0 || index >= daily.length) {
                      return const SizedBox.shrink();
                    }
                    if (dayCount > 7 &&
                        index % 5 != 0 &&
                        index != daily.length - 1) {
                      return const SizedBox.shrink();
                    }
                    final String label = dayCount <= 7
                        ? AppDateFormatter.weekdayShort(daily[index].date)
                        : '${daily[index].date.day}';
                    return SideTitleWidget(
                      meta: meta,
                      space: AppSpacing.xs,
                      child: Text(
                        label,
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
                getTooltipColor: (BarChartGroupData group) =>
                    scheme.inverseSurface,
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
                      final DailyReadingMinutes day = daily[group.x];
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
      },
    );
  }

  /// Langkah sumbu Y yang menghasilkan paling banyak lima garis.
  static int _axisStep(int highest) {
    if (highest <= 20) {
      return 5;
    }
    if (highest <= 60) {
      return 15;
    }
    if (highest <= 120) {
      return 30;
    }
    if (highest <= 300) {
      return 60;
    }
    if (highest <= 600) {
      return 120;
    }
    return ((highest / 4) / 60).ceil() * 60;
  }
}

/// Keadaan grafik ketika belum ada sesi membaca.
class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      key: const ValueKey<String>('stats-empty'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allMedium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.bar_chart_rounded,
              size: 28,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.statsChartEmptyTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.statsChartEmptyMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Pemberitahuan ringan ketika data terakhir gagal diperbarui.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.sync_problem_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.statsStaleNotice,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            key: const ValueKey<String>('stats-stale-retry'),
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}

/// Permukaan kartu Statistik, sama dengan kartu Beranda dan Detail Buku.
class _StatsSurface extends StatelessWidget {
  const _StatsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors extras = Theme.of(context)
        .extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

String _statsErrorMessage(Object error) {
  if (error is ReadingStatsFailure) {
    return error.message;
  }
  return AppStrings.statsLoadError;
}
