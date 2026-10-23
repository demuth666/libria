import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/app_button.dart';
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
/// Header hanya menampilkan judul buku tanpa bab. Waktu, target, dan progres
/// dihitung ulang dari [SessionTimerEngine] pada setiap pembaruan layar,
/// sehingga tampilan tetap sinkron dengan cap waktu walaupun aplikasi sempat
/// berhenti di latar belakang. Layar ini belum ada di Stitch; susunannya
/// mengikuti PRD bagian 5.4 dan bahasa visual Koleksi/Detail Buku.
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
    final String headerTitle = session == null
        ? AppStrings.sessionRunTitle
        : _bookTitle(session);

    if (session == null) {
      return _SessionRunFrame(
        title: headerTitle,
        child: _buildUnavailableContent(asyncSession),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(title: headerTitle),
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

  static String _bookTitle(ActiveSession session) {
    final String title = session.bookTitle.trim();
    return title.isEmpty ? AppStrings.sessionSetupUntitledBook : title;
  }
}

/// Rangka layar untuk keadaan loading, galat, dan sesi kosong.
class _SessionRunFrame extends StatelessWidget {
  const _SessionRunFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(title: title),
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double minHeight = constraints.maxHeight > AppSpacing.lg * 2
            ? constraints.maxHeight - AppSpacing.lg * 2
            : 0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.lg,
            horizontalPadding,
            AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _TimerCard(session: session),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kartu utama: status, angka timer, target, dan progres.
class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final SessionTimerEngine timer = session.timer;
    final SessionTimerState state = timer.state;
    final Duration elapsed = timer.elapsed;
    final Duration target = timer.target;
    final Duration remaining = target > elapsed
        ? target - elapsed
        : Duration.zero;
    final int percent = (timer.progress * 100).round();
    final String elapsedLabel = AppDurationFormatter.timer(elapsed);
    final String targetLabel = AppDurationFormatter.timer(target);
    final bool targetReached =
        state == SessionTimerState.targetReached ||
        state == SessionTimerState.finished;
    final Color timerColor = targetReached ? scheme.secondary : scheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allExtraLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: _TimerStatusPill(state: state),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.sessionRunElapsedLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            label: AppStrings.sessionRunTimerSemantics(
              elapsedLabel,
              targetLabel,
            ),
            child: ExcludeSemantics(
              child: SizedBox(
                width: double.infinity,
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
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.sessionRunTarget(targetLabel),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: AppStrings.sessionRunProgressSemantics,
            value: AppStrings.sessionRunProgress(percent),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: AppRadius.allFull,
                child: LinearProgressIndicator(
                  value: timer.progress,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.sessionRunProgress(percent),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  AppStrings.sessionRunRemaining(
                    AppDurationFormatter.timer(remaining),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _TimerStateMessage(state: state),
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
        ? SecondaryButton(
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
            expand: true,
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
      icon: isFinished ? Icons.arrow_forward_rounded : Icons.check_rounded,
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
