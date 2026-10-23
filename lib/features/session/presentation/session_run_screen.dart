import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/active_session.dart';
import '../data/active_session_repository.dart';
import '../data/session_timer_engine.dart';
import 'active_session_providers.dart';

/// Aksi yang sedang diproses pada panel bawah layar timer.
enum _SessionRunAction { pause, resume, finish }

/// Layar timer sesi membaca pada rute `/session/run` (T-055, FR-S3).
///
/// Susunan visual mengikuti layar Stitch "Libria - Sesi Membaca Aktif":
/// header kaca, kartu buku, kartu timer melingkar, ringkasan progres, dan
/// kartu target durasi. Panel aksi tetap berisi Jeda/Lanjut dan Selesai.
/// Waktu, target, dan progres dihitung ulang dari [SessionTimerEngine] pada
/// setiap pembaruan layar, sehingga tampilan tetap sinkron dengan cap waktu
/// walaupun aplikasi sempat berhenti di latar belakang.
class SessionRunScreen extends ConsumerStatefulWidget {
  const SessionRunScreen({super.key});

  @override
  ConsumerState<SessionRunScreen> createState() => _SessionRunScreenState();
}

class _SessionRunScreenState extends ConsumerState<SessionRunScreen> {
  /// Timer hanya memicu gambar ulang. Durasi tidak dihitung dari jumlah tick,
  /// melainkan dari cap waktu mesin timer (FR-S4).
  Timer? _ticker;

  _SessionRunAction? _pendingAction;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<bool> _runAction(
    _SessionRunAction action,
    Future<void> Function() operation,
  ) async {
    if (_pendingAction != null) {
      return false;
    }

    setState(() {
      _pendingAction = action;
      _actionError = null;
    });

    try {
      await operation();
      return true;
    } on ActiveSessionFailure catch (failure) {
      _setActionError(failure.message);
      return false;
    } catch (_) {
      _setActionError(AppStrings.sessionRunActionError);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _pendingAction = null;
        });
      }
    }
  }

  Future<void> _togglePause(SessionTimerState state) async {
    final bool resume = state == SessionTimerState.paused;
    final ActiveSessionController controller = ref.read(
      activeSessionProvider.notifier,
    );
    await _runAction(
      resume ? _SessionRunAction.resume : _SessionRunAction.pause,
      resume ? controller.resume : controller.pause,
    );
  }

  Future<void> _finish() async {
    final ActiveSessionController controller = ref.read(
      activeSessionProvider.notifier,
    );
    final bool finished = await _runAction(
      _SessionRunAction.finish,
      controller.finish,
    );
    if (!finished || !mounted) {
      return;
    }
    context.go(AppRoutes.sessionFinish);
  }

  void _setActionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _actionError = message;
    });
  }

  void _openSetup() {
    context.go(AppRoutes.sessionSetup);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ActiveSession?> asyncSession = ref.watch(
      activeSessionProvider,
    );
    final ActiveSession? session = asyncSession.value;

    if (session == null) {
      return _SessionRunFrame(child: _buildUnavailableContent(asyncSession));
    }

    return Scaffold(
      body: Column(
        children: [
          const _SessionRunHeader(),
          Expanded(child: _TimerBody(session: session)),
        ],
      ),
      bottomNavigationBar: _SessionActionPanel(
        state: session.timer.state,
        pendingAction: _pendingAction,
        errorMessage: _actionError,
        onPause: () => _togglePause(session.timer.state),
        onResume: () => _togglePause(session.timer.state),
        onFinish: _finish,
      ),
    );
  }

  Widget _buildUnavailableContent(AsyncValue<ActiveSession?> asyncSession) {
    if (asyncSession.isLoading) {
      return const LoadingView(message: AppStrings.sessionRunLoading);
    }

    if (asyncSession.hasError) {
      final Object error = asyncSession.error!;
      return ErrorView(
        message: error is ActiveSessionFailure
            ? error.message
            : AppStrings.sessionRunLoadError,
        onRetry: () => ref.invalidate(activeSessionProvider),
      );
    }

    return EmptyView(
      title: AppStrings.sessionRunNoSessionTitle,
      message: AppStrings.sessionRunNoSessionMessage,
      icon: Icons.timer_off_outlined,
      action: PrimaryButton(
        key: const ValueKey<String>('session-run-open-setup'),
        label: AppStrings.sessionRunOpenSetup,
        icon: Icons.tune_rounded,
        onPressed: _openSetup,
      ),
    );
  }
}

/// Header kaca dengan judul layar.
class _SessionRunHeader extends StatelessWidget {
  const _SessionRunHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ScreenHeader(
      title: AppStrings.sessionRunTitle,
      leading: Icon(Icons.auto_stories, size: 24, color: scheme.secondary),
    );
  }
}

/// Rangka layar untuk keadaan loading, galat, dan sesi kosong.
class _SessionRunFrame extends StatelessWidget {
  const _SessionRunFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.sessionRunTitle,
            leading: Icon(
              Icons.auto_stories,
              size: 24,
              color: scheme.secondary,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Isi layar timer yang dapat digulir pada layar pendek atau teks besar.
class _TimerBody extends StatelessWidget {
  const _TimerBody({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SingleChildScrollView(
      key: const PageStorageKey<String>('session-run'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.md,
        horizontalPadding,
        AppSpacing.lg,
      ),
      child: ContentWidth(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionBookCard(session: session),
            const SizedBox(height: AppSpacing.lg),
            _TimerCard(session: session),
            const SizedBox(height: AppSpacing.lg),
            _TargetDurationCard(session: session),
          ],
        ),
      ),
    );
  }
}

/// Kartu buku yang sedang dibaca: sampul, kategori, judul, penulis, dan
/// progres halaman saat sesi dimulai.
class _SessionBookCard extends StatelessWidget {
  const _SessionBookCard({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final String title = _sessionBookTitle(session);
    final String author = session.bookAuthor.trim();
    final String category = session.bookCategory.trim();
    final int totalPages = session.bookTotalPages;
    final int currentPage = totalPages > 0
        ? session.bookCurrentPage.clamp(0, totalPages).toInt()
        : 0;
    final double progress = totalPages > 0 ? currentPage / totalPages : 0;
    final int percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCoverImage(
                coverUrl: session.bookCoverUrl,
                width: 80,
                height: 112,
                borderRadius: AppRadius.allMedium,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (category.isNotEmpty) ...[
                      _BookCategoryChip(label: category),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: scheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (author.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        author,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (totalPages > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.sessionRunPage(currentPage, totalPages),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.sessionRunPercent(percent),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.allFull,
              child: LinearProgressIndicator(
                key: const ValueKey<String>('session-run-book-progress'),
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainer,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Label kategori pada kartu buku.
class _BookCategoryChip extends StatelessWidget {
  const _BookCategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.allFull,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Kartu utama: cincin timer, angka waktu, target, ringkasan progres, dan
/// pesan status.
class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final SessionTimerEngine timer = session.timer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _TimerStatusPill(state: timer.state),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _TimerRing(timer: timer),
          const SizedBox(height: AppSpacing.lg),
          _SessionProgressSummary(timer: timer),
          const SizedBox(height: AppSpacing.md),
          _TimerStateMessage(state: timer.state),
        ],
      ),
    );
  }
}

/// Cincin progres dengan angka waktu dan pil target di tengahnya.
class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.timer});

  final SessionTimerEngine timer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String elapsedLabel = AppDurationFormatter.timer(timer.elapsed);
    final String targetLabel = AppDurationFormatter.timer(timer.target);
    final bool targetReached =
        timer.state == SessionTimerState.targetReached ||
        timer.state == SessionTimerState.finished;
    final Color timerColor = targetReached ? scheme.secondary : scheme.primary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 248),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  key: const ValueKey<String>('session-run-ring'),
                  value: timer.progress,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: scheme.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      liveRegion: true,
                      label: AppStrings.sessionRunTimerSemantics(
                        elapsedLabel,
                        targetLabel,
                      ),
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            elapsedLabel,
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: timerColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _TimerTargetPill(minutes: timer.target.inMinutes),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pil target durasi di dalam cincin timer.
class _TimerTargetPill extends StatelessWidget {
  const _TimerTargetPill({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppStrings.sessionRunTargetPill(minutes),
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

/// Ringkasan progres sesi di bawah cincin timer.
class _SessionProgressSummary extends StatelessWidget {
  const _SessionProgressSummary({required this.timer});

  final SessionTimerEngine timer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Duration elapsed = timer.elapsed;
    final Duration target = timer.target;
    final Duration remaining = target > elapsed
        ? target - elapsed
        : Duration.zero;
    final int percent = (timer.progress * 100).round();
    final String remainingLabel = AppDurationFormatter.timer(remaining);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: scheme.secondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  AppStrings.sessionRunProgressLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  AppStrings.sessionRunTargetSummary(target.inMinutes),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                AppStrings.sessionRunPercent(percent),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.secondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  AppStrings.sessionRunRemaining(remainingLabel),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: AppStrings.sessionRunProgressSemantics,
            value: AppStrings.sessionRunProgress(percent),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: AppRadius.allFull,
                child: LinearProgressIndicator(
                  key: const ValueKey<String>('session-run-timer-progress'),
                  value: timer.progress,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu target durasi sesi. Target ditetapkan saat sesi dimulai dan tidak
/// dapat diubah dari layar timer.
class _TargetDurationCard extends StatelessWidget {
  const _TargetDurationCard({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final int minutes = session.timer.target.inMinutes;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timelapse_rounded, size: 18, color: scheme.secondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  AppStrings.sessionRunTargetLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.allMedium,
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: scheme.secondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$minutes',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  AppStrings.sessionRunMinutesUnit,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: AppStrings.sessionRunTargetFixed,
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pil status sesi dengan ikon yang sesuai.
class _TimerStatusPill extends StatelessWidget {
  const _TimerStatusPill({required this.state});

  final SessionTimerState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final (String label, IconData icon, bool emphasized) = switch (state) {
      SessionTimerState.idle => (
        AppStrings.sessionRunStatusPaused,
        Icons.pause_rounded,
        false,
      ),
      SessionTimerState.running => (
        AppStrings.sessionRunStatusRunning,
        Icons.timer_outlined,
        true,
      ),
      SessionTimerState.paused => (
        AppStrings.sessionRunStatusPaused,
        Icons.pause_rounded,
        false,
      ),
      SessionTimerState.targetReached => (
        AppStrings.sessionRunStatusTargetReached,
        Icons.check_circle_outline_rounded,
        true,
      ),
      SessionTimerState.finished => (
        AppStrings.sessionRunStatusFinished,
        Icons.check_circle_outline_rounded,
        false,
      ),
    };
    final Color background = emphasized
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHigh;
    final Color foreground = emphasized
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Pesan kontekstual di bawah progres sesuai status timer.
class _TimerStateMessage extends StatelessWidget {
  const _TimerStateMessage({required this.state});

  final SessionTimerState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final (String message, IconData icon, bool emphasized) = switch (state) {
      SessionTimerState.idle => (
        AppStrings.sessionRunPausedMessage,
        Icons.pause_circle_outline_rounded,
        false,
      ),
      SessionTimerState.running => (
        AppStrings.sessionRunBackgroundHint,
        Icons.info_outline_rounded,
        false,
      ),
      SessionTimerState.paused => (
        AppStrings.sessionRunPausedMessage,
        Icons.pause_circle_outline_rounded,
        false,
      ),
      SessionTimerState.targetReached => (
        AppStrings.sessionRunTargetReachedMessage,
        Icons.notifications_active_outlined,
        true,
      ),
      SessionTimerState.finished => (
        AppStrings.sessionRunFinishedMessage,
        Icons.check_circle_outline_rounded,
        false,
      ),
    };
    final Color background = emphasized
        ? scheme.secondaryContainer
        : scheme.surfaceContainerLow;
    final Color foreground = emphasized
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel aksi tetap di bagian bawah layar.
class _SessionActionPanel extends StatelessWidget {
  const _SessionActionPanel({
    required this.state,
    required this.pendingAction,
    required this.errorMessage,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final SessionTimerState state;
  final _SessionRunAction? pendingAction;
  final String? errorMessage;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final bool isBusy = pendingAction != null;
    final bool canToggle =
        state == SessionTimerState.running || state == SessionTimerState.paused;
    final bool isPaused = state == SessionTimerState.paused;
    final bool isFinished = state == SessionTimerState.finished;

    final Widget? toggleButton = canToggle
        ? _SurfaceActionButton(
            key: ValueKey<String>(
              isPaused ? 'session-run-resume' : 'session-run-pause',
            ),
            label: isPaused
                ? AppStrings.sessionRunResume
                : AppStrings.sessionRunPause,
            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            isLoading:
                pendingAction == _SessionRunAction.pause ||
                pendingAction == _SessionRunAction.resume,
            onPressed: isBusy ? null : (isPaused ? onResume : onPause),
          )
        : null;

    final Widget finishButton = PrimaryButton(
      key: const ValueKey<String>('session-run-finish'),
      label: pendingAction == _SessionRunAction.finish
          ? AppStrings.sessionRunFinishing
          : isFinished
          ? AppStrings.sessionRunContinue
          : AppStrings.sessionRunFinish,
      icon: isFinished ? Icons.arrow_forward_rounded : Icons.check_circle,
      isLoading: pendingAction == _SessionRunAction.finish,
      expand: true,
      onPressed: isBusy ? null : onFinish,
    );

    return DecoratedBox(
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null) ...[
                    _ActionErrorNotice(message: errorMessage!),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (toggleButton == null)
                    finishButton
                  else
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            if (constraints.maxWidth < 320) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  toggleButton,
                                  const SizedBox(height: AppSpacing.sm),
                                  finishButton,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: toggleButton),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: finishButton),
                              ],
                            );
                          },
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

/// Tombol aksi berlatar permukaan kartu, dipakai untuk Jeda/Lanjutkan.
class _SurfaceActionButton extends StatelessWidget {
  const _SurfaceActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed == null ? null : (isLoading ? () {} : onPressed),
        style: FilledButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLowest,
          foregroundColor: scheme.primary,
          disabledBackgroundColor: scheme.surfaceContainerLow,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 1,
          shadowColor: scheme.shadow.withValues(alpha: 0.12),
          side: BorderSide(color: extras.cardBorder),
        ),
        child: _SurfaceButtonContent(
          label: label,
          icon: icon,
          isLoading: isLoading,
        ),
      ),
    );
  }
}

/// Isi tombol permukaan dengan ikon atau indikator loading.
class _SurfaceButtonContent extends StatelessWidget {
  const _SurfaceButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
  });

  final String label;
  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool showIcon = !isLoading;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          )
        else if (showIcon)
          Icon(icon, size: 18),
        if (isLoading || showIcon) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Galat ringkas saat aksi jeda atau selesai gagal disimpan.
class _ActionErrorNotice extends StatelessWidget {
  const _ActionErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul buku untuk kartu dan header, dengan fallback buku tanpa judul.
String _sessionBookTitle(ActiveSession session) {
  final String title = session.bookTitle.trim();
  return title.isEmpty ? AppStrings.sessionSetupUntitledBook : title;
}
