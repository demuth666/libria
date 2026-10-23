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
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../books/presentation/book_detail_providers.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../data/active_session.dart';
import '../data/active_session_repository.dart';
import '../data/session_repository.dart';
import '../data/session_timer_engine.dart';
import 'active_session_providers.dart';

/// Layar penyelesaian sesi pada rute `/session/finish` (T-056, FR-S7 dan
/// FR-S8).
///
/// Pengguna mencatat halaman terakhir, lalu sesi disimpan bersama pembaruan
/// halaman dan status buku. Halaman awal diambil dari entri rak saat sesi
/// disimpan, sehingga nilai yang divalidasi selalu sama dengan data terbaru.
/// Layar ini tidak ada di Stitch; susunannya mengikuti PRD bagian 5.4 dan
/// bahasa visual Koleksi/Detail Buku.
class SessionFinishScreen extends ConsumerStatefulWidget {
  const SessionFinishScreen({super.key});

  @override
  ConsumerState<SessionFinishScreen> createState() =>
      _SessionFinishScreenState();
}

class _SessionFinishScreenState extends ConsumerState<SessionFinishScreen> {
  final TextEditingController _pageController = TextEditingController();

  bool _isSaving = false;
  String? _pageError;
  String? _saveError;
  String? _clearWarning;
  SessionSaveResult? _savedResult;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(String value) {
    if (_pageError == null && _saveError == null) {
      return;
    }
    setState(() {
      _pageError = null;
      _saveError = null;
    });
  }

  Future<void> _save(ActiveSession session, LibraryEntry entry) async {
    if (_isSaving || _savedResult != null) {
      return;
    }

    final String raw = _pageController.text.trim();
    final int? endPage = int.tryParse(raw);
    String? error;
    if (raw.isEmpty) {
      error = AppStrings.sessionFinishPageRequired;
    } else if (endPage == null) {
      error = AppStrings.sessionFinishPageInvalid;
    } else {
      error = SessionRepository.validateEndPage(entry: entry, endPage: endPage);
    }

    if (error != null) {
      setState(() {
        _pageError = error;
        _saveError = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _pageError = null;
      _saveError = null;
    });

    try {
      final SessionSaveResult result = await ref
          .read(sessionRepositoryProvider)
          .saveSession(activeSession: session, entry: entry, endPage: endPage!);
      if (!mounted) {
        return;
      }

      setState(() {
        _savedResult = result;
      });

      // Sesi sudah tersimpan di Firestore. Kegagalan menghapus salinan lokal
      // ditampilkan sebagai peringatan agar pengguna tidak menyimpan ulang.
      try {
        await ref.read(activeSessionProvider.notifier).clear();
      } on ActiveSessionFailure {
        _setClearWarning();
      } catch (_) {
        _setClearWarning();
      }
    } on SessionFailure catch (failure) {
      if (failure.code == SessionFailureCode.page) {
        _setPageError(failure.message);
      } else {
        _setSaveError(failure.message);
      }
    } catch (_) {
      _setSaveError(AppStrings.sessionFinishSaveError);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _setPageError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pageError = message;
      _saveError = null;
    });
  }

  void _setSaveError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _saveError = message;
      _pageError = null;
    });
  }

  void _setClearWarning() {
    if (!mounted) {
      return;
    }
    setState(() {
      _clearWarning = AppStrings.sessionFinishClearWarning;
    });
  }

  void _goHome() {
    context.go(AppRoutes.home);
  }

  void _writeJournal(SessionSaveResult result) {
    // Sesi sudah tersimpan, jadi layar penyelesaian diganti formulir jurnal.
    // Jurnal baru membawa buku dan sesi tersebut agar tautannya otomatis.
    context.go(
      AppRoutes.journalNewPath(
        bookId: result.session.bookId,
        sessionId: result.session.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ActiveSession?> asyncSession = ref.watch(
      activeSessionProvider,
    );
    final SessionSaveResult? savedResult = _savedResult;

    if (savedResult != null) {
      return _SessionFinishFrame(
        child: _SuccessView(
          result: savedResult,
          clearWarning: _clearWarning,
          onWriteJournal: () => _writeJournal(savedResult),
          onSkipJournal: _goHome,
        ),
      );
    }

    final ActiveSession? session = asyncSession.value;
    if (session == null) {
      return _SessionFinishFrame(child: _buildSessionState(asyncSession));
    }

    if (session.timer.state != SessionTimerState.finished) {
      return _SessionFinishFrame(
        child: EmptyView(
          title: AppStrings.sessionFinishRunningTitle,
          message: AppStrings.sessionFinishRunningMessage,
          icon: Icons.timer_outlined,
          action: PrimaryButton(
            key: const ValueKey<String>('session-finish-open-run'),
            label: AppStrings.sessionFinishOpenRun,
            icon: Icons.play_arrow_rounded,
            onPressed: () => context.go(AppRoutes.sessionRun),
          ),
        ),
      );
    }

    final AsyncValue<LibraryEntry?> asyncEntry = ref.watch(
      libraryEntryProvider(session.bookId),
    );
    final LibraryEntry? entry = asyncEntry.value;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(title: AppStrings.sessionFinishTitle),
          Expanded(
            child: _buildEntryState(asyncEntry: asyncEntry, session: session),
          ),
        ],
      ),
      bottomNavigationBar: entry == null
          ? null
          : _SessionSavePanel(
              isSaving: _isSaving,
              errorMessage: _saveError,
              onSave: () => _save(session, entry),
            ),
    );
  }

  Widget _buildSessionState(AsyncValue<ActiveSession?> asyncSession) {
    if (asyncSession.isLoading) {
      return const LoadingView(message: AppStrings.sessionFinishLoading);
    }

    if (asyncSession.hasError) {
      final Object error = asyncSession.error!;
      return ErrorView(
        message: error is ActiveSessionFailure
            ? error.message
            : AppStrings.sessionFinishLoadError,
        onRetry: () => ref.invalidate(activeSessionProvider),
      );
    }

    return EmptyView(
      title: AppStrings.sessionFinishNoSessionTitle,
      message: AppStrings.sessionFinishNoSessionMessage,
      icon: Icons.timer_off_outlined,
      action: PrimaryButton(
        key: const ValueKey<String>('session-finish-open-setup'),
        label: AppStrings.sessionFinishOpenSetup,
        icon: Icons.tune_rounded,
        onPressed: () => context.go(AppRoutes.sessionSetup),
      ),
    );
  }

  Widget _buildEntryState({
    required AsyncValue<LibraryEntry?> asyncEntry,
    required ActiveSession session,
  }) {
    return asyncEntry.when(
      loading: () =>
          const LoadingView(message: AppStrings.sessionFinishEntryLoading),
      error: (Object error, StackTrace stackTrace) => ErrorView(
        message: error is LibraryFailure
            ? error.message
            : AppStrings.sessionFinishEntryLoadError,
        onRetry: () => ref.invalidate(libraryEntryProvider(session.bookId)),
      ),
      data: (LibraryEntry? entry) {
        if (entry == null) {
          return EmptyView(
            title: AppStrings.sessionFinishBookMissingTitle,
            message: AppStrings.sessionFinishBookMissingMessage,
            icon: Icons.menu_book_outlined,
            action: PrimaryButton(
              key: const ValueKey<String>('session-finish-home'),
              label: AppStrings.sessionFinishHome,
              icon: Icons.home_outlined,
              onPressed: _goHome,
            ),
          );
        }
        return _SessionFinishForm(
          session: session,
          entry: entry,
          pageController: _pageController,
          pageError: _pageError,
          isSaving: _isSaving,
          onPageChanged: _onPageChanged,
          onSave: () => _save(session, entry),
        );
      },
    );
  }
}

/// Rangka layar untuk keadaan loading, galat, sesi kosong, dan berhasil.
class _SessionFinishFrame extends StatelessWidget {
  const _SessionFinishFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(title: AppStrings.sessionFinishTitle),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Formulir halaman terakhir beserta ringkasan sesi.
class _SessionFinishForm extends StatelessWidget {
  const _SessionFinishForm({
    required this.session,
    required this.entry,
    required this.pageController,
    required this.pageError,
    required this.isSaving,
    required this.onPageChanged,
    required this.onSave,
  });

  final ActiveSession session;
  final LibraryEntry entry;
  final TextEditingController pageController;
  final String? pageError;
  final bool isSaving;
  final ValueChanged<String> onPageChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return CustomScrollView(
      key: const PageStorageKey<String>('session-finish'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.sessionFinishIntro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SessionSummaryCard(session: session, entry: entry),
                  const SizedBox(height: AppSpacing.md),
                  _PageCard(
                    entry: entry,
                    pageController: pageController,
                    pageError: pageError,
                    isSaving: isSaving,
                    onPageChanged: onPageChanged,
                    onSave: onSave,
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

/// Ringkasan buku, durasi, target, dan halaman awal sesi.
class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.session, required this.entry});

  final ActiveSession session;
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final String title = _bookTitle(session, entry);
    final String author = entry.bookAuthor.trim();
    final bool targetReached =
        session.timer.target > Duration.zero &&
        session.timer.elapsed >= session.timer.target;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCoverImage(
                coverUrl: entry.bookCoverUrl,
                width: 56,
                height: 80,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.sessionFinishSummaryTitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
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
                    if (targetReached) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const _TargetReachedPill(),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SessionMetric(
                  label: AppStrings.sessionFinishDurationLabel,
                  value: AppDurationFormatter.timer(session.timer.elapsed),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SessionMetric(
                  label: AppStrings.sessionFinishTargetLabel,
                  value: AppDurationFormatter.timer(session.timer.target),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SessionMetric(
                  label: AppStrings.sessionFinishStartPageLabel,
                  value: '${entry.currentPage}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _bookTitle(ActiveSession session, LibraryEntry entry) {
    final String title = session.bookTitle.trim().isNotEmpty
        ? session.bookTitle.trim()
        : entry.bookTitle.trim();
    return title.isEmpty ? AppStrings.sessionSetupUntitledBook : title;
  }
}

/// Satu angka ringkasan pada kartu sesi.
class _SessionMetric extends StatelessWidget {
  const _SessionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
        ),
      ],
    );
  }
}

/// Pil kecil penanda target sesi sudah tercapai.
class _TargetReachedPill extends StatelessWidget {
  const _TargetReachedPill();

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
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppStrings.sessionFinishTargetReached,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu isian halaman terakhir.
class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.entry,
    required this.pageController,
    required this.pageError,
    required this.isSaving,
    required this.onPageChanged,
    required this.onSave,
  });

  final LibraryEntry entry;
  final TextEditingController pageController;
  final String? pageError;
  final bool isSaving;
  final ValueChanged<String> onPageChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final bool hasTotalPages = entry.bookTotalPages > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_added_outlined,
                size: 20,
                color: scheme.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.sessionFinishPageSection,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasTotalPages
                ? AppStrings.sessionFinishStartPage(
                    entry.currentPage,
                    entry.bookTotalPages,
                  )
                : AppStrings.sessionFinishPageUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: const ValueKey<String>('session-finish-page'),
            controller: pageController,
            label: AppStrings.sessionFinishPageLabel,
            hint: hasTotalPages
                ? AppStrings.sessionFinishPageHint(
                    entry.currentPage,
                    entry.bookTotalPages,
                  )
                : null,
            prefixIcon: Icons.menu_book_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            errorText: pageError,
            enabled: !isSaving,
            onChanged: onPageChanged,
            onSubmitted: (String value) => onSave(),
          ),
        ],
      ),
    );
  }
}

/// Panel aksi tetap di bagian bawah formulir.
class _SessionSavePanel extends StatelessWidget {
  const _SessionSavePanel({
    required this.isSaving,
    required this.errorMessage,
    required this.onSave,
  });

  final bool isSaving;
  final String? errorMessage;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

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
                    _SaveErrorNotice(message: errorMessage!),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  PrimaryButton(
                    key: const ValueKey<String>('session-finish-save'),
                    label: isSaving
                        ? AppStrings.sessionFinishSaving
                        : AppStrings.sessionFinishSave,
                    icon: Icons.check_rounded,
                    isLoading: isSaving,
                    expand: true,
                    onPressed: isSaving ? null : onSave,
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

/// Galat ringkas saat sesi gagal disimpan.
class _SaveErrorNotice extends StatelessWidget {
  const _SaveErrorNotice({required this.message});

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

/// Keadaan berhasil setelah sesi dan progres buku tersimpan.
class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.result,
    required this.clearWarning,
    required this.onWriteJournal,
    required this.onSkipJournal,
  });

  final SessionSaveResult result;
  final String? clearWarning;
  final VoidCallback onWriteJournal;
  final VoidCallback onSkipJournal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final int pagesRead = result.session.endPage - result.session.startPage;
    final Duration duration = Duration(seconds: result.session.durationSeconds);
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.lg,
        horizontalPadding,
        AppSpacing.lg,
      ),
      child: ContentWidth(
        maxWidth: 560,
        child: Container(
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
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 32,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.sessionFinishSuccessTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.sessionFinishSuccessMessage(
                  AppDurationFormatter.timer(duration),
                  pagesRead < 0 ? 0 : pagesRead,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadius.allLarge,
                ),
                child: Column(
                  children: [
                    _SuccessRow(
                      label: AppStrings.sessionFinishDurationLabel,
                      value: AppDurationFormatter.timer(duration),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SuccessRow(
                      label: AppStrings.sessionFinishPageLabel,
                      value: AppStrings.sessionFinishPagesValue(
                        result.session.startPage,
                        result.session.endPage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (result.reachedLastPage)
                _SuccessNotice(
                  message: AppStrings.sessionFinishSuccessFinished,
                  icon: Icons.task_alt_rounded,
                )
              else
                Text(
                  AppStrings.sessionFinishProgressUpdated(
                    result.session.endPage,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (clearWarning != null) ...[
                const SizedBox(height: AppSpacing.md),
                _SaveErrorNotice(message: clearWarning!),
              ],
              const SizedBox(height: AppSpacing.md),
              _JournalOffer(
                onWriteJournal: onWriteJournal,
                onSkipJournal: onSkipJournal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tawaran menulis jurnal setelah sesi tersimpan (T-061, FR-S8).
///
/// Jurnal baru otomatis membawa buku dan sesi dari hasil penyimpanan; pengguna
/// tetap boleh melewati tawaran ini.
class _JournalOffer extends StatelessWidget {
  const _JournalOffer({
    required this.onWriteJournal,
    required this.onSkipJournal,
  });

  final VoidCallback onWriteJournal;
  final VoidCallback onSkipJournal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

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
              Icon(Icons.edit_note_rounded, size: 20, color: scheme.secondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.sessionFinishJournalOfferTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.sessionFinishJournalOfferMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const ValueKey<String>('session-finish-write-journal'),
            label: AppStrings.sessionFinishWriteJournal,
            icon: Icons.edit_note_rounded,
            expand: true,
            onPressed: onWriteJournal,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            key: const ValueKey<String>('session-finish-skip-journal'),
            label: AppStrings.sessionFinishSkipJournal,
            expand: true,
            onPressed: onSkipJournal,
          ),
        ],
      ),
    );
  }
}

/// Baris label dan nilai pada kartu berhasil.
class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
        ),
      ],
    );
  }
}

/// Pemberitahuan ringkas pada keadaan berhasil.
class _SuccessNotice extends StatelessWidget {
  const _SuccessNotice({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
