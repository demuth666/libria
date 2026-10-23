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
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/reading_report.dart';
import '../data/reading_report_printer.dart';
import '../data/reading_report_repository.dart';
import 'reading_report_providers.dart';

/// Layar laporan membaca pada rute `/report` (T-073, FR-P1 sampai FR-P3).
///
/// Pengguna memilih rentang tanggal, melihat pratinjau isi laporan, lalu
/// membuka dialog cetak sistem lewat [ReadingReportPrinter]. Layar ini tidak
/// ada di Stitch; susunannya mengikuti PRD bagian 5.7 dan bahasa visual kartu
/// Koleksi/Statistik. Tidak ada aksi berbagi atau mengirim berkas.
class ReadingReportScreen extends ConsumerStatefulWidget {
  const ReadingReportScreen({this.today, super.key});

  /// Tanggal acuan untuk rentang awal dan batas pemilih tanggal.
  ///
  /// Bila kosong, memakai waktu perangkat. Parameter ini dipakai uji agar
  /// hasilnya deterministik.
  final DateTime? today;

  @override
  ConsumerState<ReadingReportScreen> createState() =>
      _ReadingReportScreenState();
}

class _ReadingReportScreenState extends ConsumerState<ReadingReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isPrinting = false;

  DateTime get _today => _dateOnly(widget.today ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    final DateTime today = _today;
    _startDate = DateTime(today.year, today.month, 1);
    _endDate = today;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeSettings);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
      ),
      builder: (BuildContext context) => _ReportDatePickerSheet(
        title: isStart
            ? AppStrings.reportDatePickerStartTitle
            : AppStrings.reportDatePickerEndTitle,
        initialDate: isStart ? _startDate : _endDate,
        firstDate: isStart ? DateTime(2000) : _startDate,
        lastDate: isStart ? _endDate : _today,
      ),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = _dateOnly(picked);
      } else {
        _endDate = _dateOnly(picked);
      }
    });
  }

  Future<void> _print(ReadingReport report) async {
    if (_isPrinting) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      await ref.read(readingReportPrinterProvider).printReport(report);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.reportPrintError)),
        );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = ref.watch(currentUserProvider).value;
    final String trimmedName = user?.displayName.trim() ?? '';
    final String userName = trimmedName.isEmpty
        ? AppStrings.reportPdfReaderFallback
        : trimmedName;
    final ReadingReportRequest request = ReadingReportRequest(
      userName: userName,
      startDate: _startDate,
      endDate: _endDate,
    );
    final AsyncValue<ReadingReport> asyncReport = ref.watch(
      readingReportProvider(request),
    );
    final ReadingReport? report = asyncReport.value;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.reportTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('report-back'),
                tooltip: AppStrings.reportBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              key: const PageStorageKey<String>('reading-report'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.md,
                    horizontalPadding,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ContentWidth(
                      maxWidth: 960,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DateRangeCard(
                            startDate: _startDate,
                            endDate: _endDate,
                            onPickStart: () => _pickDate(isStart: true),
                            onPickEnd: () => _pickDate(isStart: false),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            AppStrings.reportPreviewTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            AppStrings.reportPreviewSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          asyncReport.when(
                            loading: () => _ReportSurface(
                              child: SizedBox(
                                height: 240,
                                child: LoadingView(
                                  message: AppStrings.reportLoading,
                                ),
                              ),
                            ),
                            error: (Object error, StackTrace stackTrace) =>
                                _ReportSurface(
                                  child: ErrorView(
                                    message: _reportErrorMessage(error),
                                    onRetry: () => ref.invalidate(
                                      readingReportProvider(request),
                                    ),
                                  ),
                                ),
                            data: (ReadingReport data) =>
                                _ReportPreview(report: data),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ReportPrintPanel(
        isPrinting: _isPrinting,
        onPrint: report == null || _isPrinting ? null : () => _print(report),
      ),
    );
  }
}

/// Kartu pemilih rentang tanggal laporan.
class _DateRangeCard extends StatelessWidget {
  const _DateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return _ReportSurface(
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
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.allMedium,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.date_range_rounded,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.reportRangeTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      AppStrings.reportRangeSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget startField = _DateField(
                fieldKey: const ValueKey<String>('report-start-date'),
                label: AppStrings.reportStartDateLabel,
                value: AppDateFormatter.date(startDate),
                onTap: onPickStart,
              );
              final Widget endField = _DateField(
                fieldKey: const ValueKey<String>('report-end-date'),
                label: AppStrings.reportEndDateLabel,
                value: AppDateFormatter.date(endDate),
                onTap: onPickEnd,
              );

              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    startField,
                    const SizedBox(height: AppSpacing.sm),
                    endField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: startField),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: endField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Satu kolom tanggal yang membuka pemilih kalender.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Semantics(
      button: true,
      label: AppStrings.reportDateFieldSemantics(label, value),
      child: Material(
        key: fieldKey,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
          side: BorderSide(color: extras.inputBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: scheme.secondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

/// Pratinjau ringkas isi PDF laporan.
class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.report});

  final ReadingReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return _ReportSurface(
      key: const ValueKey<String>('report-preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: AppRadius.allMedium,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 24,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.reportPdfTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      AppStrings.reportPeriod(
                        AppDateFormatter.date(report.startDate),
                        AppDateFormatter.date(report.endDate),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppRadius.allFull,
                ),
                child: Text(
                  AppStrings.reportPreviewBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.allMedium,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: scheme.secondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.reportPdfNameLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        report.userName.trim().isEmpty
                            ? AppStrings.reportPdfReaderFallback
                            : report.userName.trim(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryGrid(report: report),
          if (report.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const ValueKey<String>('report-empty'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: AppRadius.allMedium,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.reportPreviewEmptyTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          AppStrings.reportPreviewEmptyMessage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _PreviewSectionTitle(
            title: AppStrings.reportPdfBooksTitle,
            icon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (report.books.isEmpty)
            const _PreviewEmptyLine(message: AppStrings.reportPdfBooksEmpty)
          else
            for (int index = 0; index < report.books.length; index++) ...[
              if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
              _PreviewBookRow(book: report.books[index]),
            ],
          const SizedBox(height: AppSpacing.lg),
          _PreviewSectionTitle(
            title: AppStrings.reportPdfDaysTitle,
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (report.days.isEmpty)
            const _PreviewEmptyLine(message: AppStrings.reportPdfDaysEmpty)
          else
            for (int index = 0; index < report.days.length; index++) ...[
              if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
              _PreviewDayRow(day: report.days[index]),
            ],
        ],
      ),
    );
  }
}

/// Empat kartu angka ringkasan laporan.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final ReadingReport report;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      _SummaryCard(
        label: AppStrings.reportPdfTotalMinutesLabel,
        value: '${report.totalMinutes}',
        valueKey: const ValueKey<String>('report-total-minutes'),
        icon: Icons.timer_outlined,
      ),
      _SummaryCard(
        label: AppStrings.reportPdfTotalPagesLabel,
        value: '${report.totalPages}',
        valueKey: const ValueKey<String>('report-total-pages'),
        icon: Icons.auto_stories_outlined,
      ),
      _SummaryCard(
        label: AppStrings.reportPdfFinishedBooksLabel,
        value: '${report.finishedBookCount}',
        valueKey: const ValueKey<String>('report-finished-books'),
        icon: Icons.check_circle_outline_rounded,
      ),
      _SummaryCard(
        label: AppStrings.reportPdfSessionsLabel,
        value: '${report.sessionCount}',
        valueKey: const ValueKey<String>('report-sessions'),
        icon: Icons.menu_book_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 640 ? 4 : 2;
        final List<Widget> rows = <Widget>[];
        for (int start = 0; start < cards.length; start += columns) {
          final List<Widget> rowCards = cards.sublist(
            start,
            start + columns > cards.length ? cards.length : start + columns,
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          children: [
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

/// Satu kartu angka ringkasan.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.icon,
  });

  final String label;
  final String value;
  final Key valueKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allMedium,
        border: Border.all(color: extras.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.secondary),
              const SizedBox(width: AppSpacing.xs),
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
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: valueKey,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul bagian di dalam pratinjau.
class _PreviewSectionTitle extends StatelessWidget {
  const _PreviewSectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.secondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Satu buku pada pratinjau laporan.
class _PreviewBookRow extends StatelessWidget {
  const _PreviewBookRow({required this.book});

  final ReadingReportBook book;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool finished = book.finished;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title.isEmpty
                          ? AppStrings.reportPdfUnknownBook
                          : book.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      book.author.isEmpty
                          ? AppStrings.reportPdfAuthorUnavailable
                          : book.author,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: finished
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.allFull,
                ),
                child: Text(
                  finished
                      ? AppStrings.reportPdfStatusFinished
                      : AppStrings.reportPdfStatusReading,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: finished
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.reportActivitySummary(
              book.sessionCount,
              book.minutes,
              book.pages,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu hari pada pratinjau laporan.
class _PreviewDayRow extends StatelessWidget {
  const _PreviewDayRow({required this.day});

  final ReadingReportDay day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppDateFormatter.date(day.date),
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
          ),
          Text(
            AppStrings.reportActivitySummary(
              day.sessionCount,
              day.minutes,
              day.pages,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris kosong di dalam bagian pratinjau.
class _PreviewEmptyLine extends StatelessWidget {
  const _PreviewEmptyLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
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

/// Panel aksi tetap untuk membuka dialog cetak sistem.
class _ReportPrintPanel extends StatelessWidget {
  const _ReportPrintPanel({required this.isPrinting, required this.onPrint});

  final bool isPrinting;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: extras.cardBorder)),
        boxShadow: AppShadows.navigationBar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.reportPrintHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    key: const ValueKey<String>('report-print'),
                    label: AppStrings.reportPrintAction,
                    icon: Icons.print_outlined,
                    expand: true,
                    isLoading: isPrinting,
                    onPressed: onPrint,
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

/// Pemilih kalender sederhana berbahasa Indonesia.
///
/// Dibuat sendiri agar nama bulan dan hari memakai locale `id_ID` tanpa
/// menambah paket lokalisasi, serta agar warnanya mengikuti token tema.
class _ReportDatePickerSheet extends StatefulWidget {
  const _ReportDatePickerSheet({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_ReportDatePickerSheet> createState() => _ReportDatePickerSheetState();
}

class _ReportDatePickerSheetState extends State<_ReportDatePickerSheet> {
  static final DateTime _weekdayAnchor = DateTime(2026, 10, 5);

  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  DateTime get _firstMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month);

  DateTime get _lastMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month);

  bool get _canGoPrevious => _visibleMonth.isAfter(_firstMonth);

  bool get _canGoNext => _visibleMonth.isBefore(_lastMonth);

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  bool _isEnabled(DateTime date) {
    return !date.isBefore(_dateOnly(widget.firstDate)) &&
        !date.isAfter(_dateOnly(widget.lastDate));
  }

  void _select(DateTime date) {
    if (!_isEnabled(date)) {
      return;
    }
    setState(() => _selectedDate = date);
  }

  void _confirm() {
    Navigator.of(context).pop(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int leadingBlanks = _visibleMonth.weekday - DateTime.monday;
    final int daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final int cellCount = leadingBlanks + daysInMonth;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: ContentWidth(
            maxWidth: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: AppRadius.allFull,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey<String>('report-date-picker-prev'),
                      tooltip: AppStrings.reportDatePickerPreviousMonth,
                      onPressed: _canGoPrevious ? () => _changeMonth(-1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        AppDateFormatter.monthYear(_visibleMonth),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('report-date-picker-next'),
                      tooltip: AppStrings.reportDatePickerNextMonth,
                      onPressed: _canGoNext ? () => _changeMonth(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    for (int index = 0; index < 7; index++)
                      Expanded(
                        child: Text(
                          AppDateFormatter.weekdayNarrow(
                            _weekdayAnchor.add(Duration(days: index)),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cellCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: AppSpacing.xs,
                    crossAxisSpacing: AppSpacing.xs,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    if (index < leadingBlanks) {
                      return const SizedBox.shrink();
                    }
                    final int day = index - leadingBlanks + 1;
                    final DateTime date = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month,
                      day,
                    );
                    return _CalendarDay(
                      date: date,
                      selected: _isSameDay(date, _selectedDate),
                      enabled: _isEnabled(date),
                      onTap: () => _select(date),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    TextButton(
                      key: const ValueKey<String>('report-date-picker-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.reportDatePickerCancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        key: const ValueKey<String>(
                          'report-date-picker-confirm',
                        ),
                        label: AppStrings.reportDatePickerConfirm,
                        expand: true,
                        onPressed: _confirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu tanggal pada kalender pemilih.
class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color foreground = selected
        ? scheme.onPrimary
        : enabled
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: AppDateFormatter.date(date),
      child: InkWell(
        key: ValueKey<String>(
          'report-date-${date.year}-${date.month}-${date.day}',
        ),
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : null,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${date.day}',
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

/// Permukaan kartu laporan, sama dengan kartu Statistik dan Detail Buku.
class _ReportSurface extends StatelessWidget {
  const _ReportSurface({required this.child, super.key});

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

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _reportErrorMessage(Object error) {
  if (error is ReadingReportFailure) {
    return error.message;
  }
  return AppStrings.reportLoadError;
}
