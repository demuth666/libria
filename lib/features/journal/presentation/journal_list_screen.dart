import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../library/data/library_entry.dart';
import '../../library/presentation/library_providers.dart';
import '../data/journal.dart';
import '../data/journal_repository.dart';
import 'journal_providers.dart';

/// Layar daftar jurnal refleksi pada rute `/journal` (T-060, FR-J1 dan
/// FR-J2).
///
/// Layar ini tidak ada di Stitch; susunannya mengikuti PRD bagian 5.5 dan
/// bahasa visual Koleksi/Riwayat Sesi: header kaca dengan tombol kembali dan
/// tombol tambah, pil filter per buku, kartu jurnal berisi judul buku,
/// tanggal, dan cuplikan isi, serta tombol Muat Lebih Banyak.
class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  String? _selectedBookId;
  final Set<String> _deletingIds = <String>{};

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeSettings);
  }

  void _selectBook(String? bookId) {
    if (bookId == _selectedBookId) {
      return;
    }
    setState(() {
      _selectedBookId = bookId;
    });
  }

  void _openNew() {
    context.push(AppRoutes.journalNewPath(bookId: _selectedBookId));
  }

  void _openEdit(Journal journal) {
    context.push(AppRoutes.journalEditPath(journal.id));
  }

  Future<void> _confirmDelete(Journal journal) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.journalDeleteDialogTitle,
      message: AppStrings.journalDeleteDialogMessage,
      confirmLabel: AppStrings.journalDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _deletingIds.add(journal.id));
    try {
      await ref.read(journalRepositoryProvider).deleteJournal(journal.id);
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.journalDeleteSuccess);
    } on JournalFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.journalDeleteError);
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(journal.id));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final JournalListScope scope = (bookId: _selectedBookId);
    final AsyncValue<JournalListState> asyncJournals = ref.watch(
      journalListProvider(scope),
    );
    final bool isOffline = ref.watch(connectivityProvider).value == false;
    final AsyncValue<LibraryShelfData> shelf = ref.watch(libraryShelfProvider);

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.journalTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('journal-back'),
                tooltip: AppStrings.journalBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            actions: [
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: const ValueKey<String>('journal-add'),
                  tooltip: AppStrings.journalAddAction,
                  padding: EdgeInsets.zero,
                  onPressed: _openNew,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
          _JournalFilterBar(
            shelf: shelf,
            selectedBookId: _selectedBookId,
            onSelected: _selectBook,
          ),
          Expanded(
            child: asyncJournals.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const LoadingView(message: AppStrings.journalLoading),
              error: (Object error, StackTrace stackTrace) => ErrorView(
                message: _journalErrorMessage(error),
                onRetry: () =>
                    ref.read(journalListProvider(scope).notifier).retry(),
              ),
              data: (JournalListState data) => _JournalListContent(
                state: data,
                isOffline: isOffline,
                bookFilterActive: _selectedBookId != null,
                deletingIds: _deletingIds,
                onLoadMore: () =>
                    ref.read(journalListProvider(scope).notifier).loadMore(),
                onRetry: () =>
                    ref.read(journalListProvider(scope).notifier).retry(),
                onCreate: _openNew,
                onTapJournal: _openEdit,
                onDeleteJournal: _confirmDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris pil filter buku; kosong bila koleksi pengguna masih kosong.
class _JournalFilterBar extends StatelessWidget {
  const _JournalFilterBar({
    required this.shelf,
    required this.selectedBookId,
    required this.onSelected,
  });

  final AsyncValue<LibraryShelfData> shelf;
  final String? selectedBookId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<LibraryEntry> entries =
        shelf.value?.entries ?? const <LibraryEntry>[];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.md,
        horizontalPadding,
        0,
      ),
      child: ContentWidth(
        maxWidth: 760,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              _JournalFilterChip(
                key: const ValueKey<String>('journal-filter-all'),
                label: AppStrings.journalFilterAll,
                selected: selectedBookId == null,
                onTap: () => onSelected(null),
              ),
              for (final LibraryEntry entry in entries)
                _JournalFilterChip(
                  key: ValueKey<String>('journal-filter-${entry.bookId}'),
                  label: entry.bookTitle.trim().isEmpty
                      ? AppStrings.sessionSetupUntitledBook
                      : entry.bookTitle.trim(),
                  selected: selectedBookId == entry.bookId,
                  onTap: () => onSelected(entry.bookId),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalFilterChip extends StatelessWidget {
  const _JournalFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foreground = selected
        ? (isDark ? scheme.onPrimaryContainer : scheme.onPrimary)
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: ChoiceChip(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide.none,
        labelStyle: theme.textTheme.labelMedium?.copyWith(color: foreground),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}

/// Daftar jurnal yang dapat digulir, atau keadaan kosong/offline.
class _JournalListContent extends StatelessWidget {
  const _JournalListContent({
    required this.state,
    required this.isOffline,
    required this.bookFilterActive,
    required this.deletingIds,
    required this.onLoadMore,
    required this.onRetry,
    required this.onCreate,
    required this.onTapJournal,
    required this.onDeleteJournal,
  });

  final JournalListState state;
  final bool isOffline;
  final bool bookFilterActive;
  final Set<String> deletingIds;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final VoidCallback onCreate;
  final ValueChanged<Journal> onTapJournal;
  final ValueChanged<Journal> onDeleteJournal;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      if (isOffline) {
        return EmptyView(
          title: AppStrings.journalOfflineTitle,
          message: AppStrings.journalOfflineMessage,
          icon: Icons.wifi_off_rounded,
          action: PrimaryButton(
            label: AppStrings.retry,
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        );
      }
      return EmptyView(
        title: AppStrings.journalEmptyTitle,
        message: bookFilterActive
            ? AppStrings.journalBookEmptyMessage
            : AppStrings.journalEmptyMessage,
        icon: Icons.edit_note_rounded,
        action: PrimaryButton(
          key: const ValueKey<String>('journal-empty-add'),
          label: AppStrings.journalAddAction,
          icon: Icons.edit_rounded,
          onPressed: onCreate,
        ),
      );
    }

    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg;

    return CustomScrollView(
      key: const PageStorageKey<String>('journal-list'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            0,
          ),
          sliver: SliverList.builder(
            itemCount: state.journals.length,
            itemBuilder: (BuildContext context, int index) {
              final Journal journal = state.journals[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ContentWidth(
                  maxWidth: 760,
                  child: _JournalCard(
                    journal: journal,
                    isDeleting: deletingIds.contains(journal.id),
                    onTap: () => onTapJournal(journal),
                    onDelete: () => onDeleteJournal(journal),
                  ),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            bottomInset,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 760,
              child: _JournalListFooter(
                state: state,
                onLoadMore: onLoadMore,
                onRetry: onRetry,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu kartu jurnal: judul buku, tanggal, cuplikan isi, dan tombol hapus.
class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.journal,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  final Journal journal;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final String title = journal.bookTitle.trim().isEmpty
        ? AppStrings.sessionSetupUntitledBook
        : journal.bookTitle.trim();
    final DateTime? createdAt = journal.createdAt;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('journal-card-${journal.id}'),
          onTap: onTap,
          borderRadius: AppRadius.allLarge,
          child: Container(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            createdAt == null
                                ? AppStrings.journalDateUnavailable
                                : AppDateFormatter.dateTime(createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DeleteJournalButton(
                      isDeleting: isDeleting,
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  journal.content.trim(),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteJournalButton extends StatelessWidget {
  const _DeleteJournalButton({
    required this.isDeleting,
    required this.onPressed,
  });

  final bool isDeleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (isDeleting) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: AppStrings.journalDeleteTooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(Icons.delete_outline, color: scheme.error),
    );
  }
}

/// Tombol "Muat Lebih Banyak", pemuatan berikutnya, dan galat pemuatan
/// tambahan.
class _JournalListFooter extends StatelessWidget {
  const _JournalListFooter({
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
  });

  final JournalListState state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const _InlineLoading(message: AppStrings.journalLoadingMore);
    }
    if (state.loadMoreFailed) {
      return _InlineError(
        message: AppStrings.journalLoadMoreError,
        onRetry: onRetry,
      );
    }
    if (!state.hasMore) {
      return const SizedBox.shrink();
    }
    return SecondaryButton(
      key: const ValueKey<String>('journal-load-more'),
      label: AppStrings.journalLoadMore,
      icon: Icons.expand_more_rounded,
      expand: true,
      onPressed: onLoadMore,
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.secondary,
          ),
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
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }
}

String _journalErrorMessage(Object error) {
  if (error is JournalFailure) {
    return error.message;
  }
  return AppStrings.journalLoadError;
}
