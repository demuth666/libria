import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/library_providers.dart';
import '../data/journal.dart';
import '../data/journal_repository.dart';
import 'journal_providers.dart';

/// Layar formulir jurnal baru atau ubah pada rute `/journal/new` (T-060,
/// FR-J1).
///
/// [journalId] membuka formulir dalam mode ubah; buku terkait terkunci dan
/// hanya isi jurnal yang dapat diubah. Tanpa [journalId], formulir meminta
/// pengguna memilih buku dari koleksi, dengan [initialBookId] sebagai pilihan
/// awal (dipakai T-061 setelah sesi tersimpan). Layar ini tidak ada di
/// Stitch; susunannya mengikuti PRD bagian 5.5 dan bahasa visual Koleksi/
/// penyelesaian sesi: header kaca, kartu pemilih buku atau label buku
/// terkunci, kolom isi jurnal, dan tombol simpan.
class JournalFormScreen extends ConsumerWidget {
  const JournalFormScreen({this.initialBookId, this.journalId, super.key});

  /// ID buku yang sudah dipilih sebelum formulir dibuka.
  final String? initialBookId;

  /// ID jurnal yang diubah; `null` berarti formulir jurnal baru.
  final String? journalId;

  bool get _isEditing => journalId != null && journalId!.trim().isNotEmpty;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.journal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;
    if (_isEditing) {
      final String id = journalId!;
      final AsyncValue<Journal?> asyncJournal = ref.watch(journalProvider(id));
      body = asyncJournal.when(
        loading: () => const LoadingView(message: AppStrings.journalLoading),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          message: _journalErrorMessage(error),
          onRetry: () => ref.invalidate(journalProvider(id)),
        ),
        data: (Journal? journal) {
          if (journal == null) {
            return EmptyView(
              title: AppStrings.journalNotFound,
              icon: Icons.edit_note_rounded,
              action: PrimaryButton(
                label: AppStrings.journalBack,
                icon: Icons.arrow_back,
                onPressed: () => _goBack(context),
              ),
            );
          }
          return _JournalForm(
            key: ValueKey<String>('journal-edit-$id'),
            existing: journal,
          );
        },
      );
    } else {
      body = _JournalForm(
        key: ValueKey<String>('journal-new-${initialBookId ?? ''}'),
        initialBookId: initialBookId,
      );
    }

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: _isEditing
                ? AppStrings.journalEditTitle
                : AppStrings.journalNewTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('journal-form-back'),
                tooltip: AppStrings.journalBack,
                padding: EdgeInsets.zero,
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Formulir isian: pemilih buku (jurnal baru) atau label buku terkunci
/// (ubah), kolom isi, dan tombol simpan.
class _JournalForm extends ConsumerStatefulWidget {
  const _JournalForm({this.existing, this.initialBookId, super.key});

  /// Jurnal yang sedang diubah; `null` berarti formulir jurnal baru.
  final Journal? existing;

  /// Buku yang sudah dipilih sebelum formulir dibuka (jurnal baru saja).
  final String? initialBookId;

  bool get isEditing => existing != null;

  @override
  ConsumerState<_JournalForm> createState() => _JournalFormState();
}

class _JournalFormState extends ConsumerState<_JournalForm> {
  late final TextEditingController _contentController;
  String? _selectedBookId;
  String? _selectedBookTitle;
  bool _isSaving = false;
  String? _contentError;
  String? _bookError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.existing?.content ?? '',
    );
    final Journal? existing = widget.existing;
    if (existing != null) {
      _selectedBookId = existing.bookId;
      _selectedBookTitle = existing.bookTitle;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _onContentChanged(String value) {
    if (_contentError == null && _saveError == null) {
      return;
    }
    setState(() {
      _contentError = null;
      _saveError = null;
    });
  }

  void _selectBook(LibraryEntry entry) {
    setState(() {
      _selectedBookId = entry.bookId;
      _selectedBookTitle = entry.bookTitle;
      _bookError = null;
      _saveError = null;
    });
  }

  LibraryEntry? _matchInitialEntry(List<LibraryEntry> entries) {
    final String? id = widget.initialBookId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final LibraryEntry entry in entries) {
      if (entry.bookId == id) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final String content = _contentController.text;
    final String? contentError = JournalRepository.validateContent(content);

    String? bookId = _selectedBookId;
    String? bookTitle = _selectedBookTitle;
    if (!widget.isEditing && bookId == null) {
      final LibraryEntry? initialEntry = _matchInitialEntry(
        ref.read(libraryShelfProvider).value?.entries ?? const <LibraryEntry>[],
      );
      bookId = initialEntry?.bookId;
      bookTitle = initialEntry?.bookTitle;
    }
    final bool missingBook = !widget.isEditing && bookId == null;

    if (contentError != null || missingBook) {
      setState(() {
        _contentError = contentError;
        _bookError = missingBook ? AppStrings.journalBookRequired : null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final JournalRepository repository = ref.read(journalRepositoryProvider);
      if (widget.isEditing) {
        await repository.updateJournal(
          widget.existing!.id,
          content: content.trim(),
        );
      } else {
        await repository.addJournal(
          bookId: bookId!,
          bookTitle: bookTitle!,
          content: content.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.journal);
      }
    } on JournalFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _saveError = failure.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _saveError = AppStrings.journalSaveError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.lg,
          horizontalPadding,
          AppSpacing.xl,
        ),
        child: ContentWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isEditing)
                _LockedBookNotice(
                  title:
                      _selectedBookTitle ?? AppStrings.sessionSetupUntitledBook,
                )
              else
                _BookPicker(
                  initialBookId: widget.initialBookId,
                  selectedBookId: _selectedBookId,
                  errorText: _bookError,
                  onSelected: _selectBook,
                ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const ValueKey<String>('journal-content-field'),
                controller: _contentController,
                enabled: !_isSaving,
                label: AppStrings.journalContentLabel,
                hint: AppStrings.journalContentHint,
                errorText: _contentError,
                maxLines: 8,
                onChanged: _onContentChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_saveError != null) ...[
                _SaveErrorNotice(message: _saveError!),
                const SizedBox(height: AppSpacing.sm),
              ],
              PrimaryButton(
                key: const ValueKey<String>('journal-save'),
                label: _isSaving
                    ? AppStrings.journalSaving
                    : AppStrings.journalSave,
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                expand: true,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label buku terkunci pada formulir ubah; buku tidak dapat diganti.
class _LockedBookNotice extends StatelessWidget {
  const _LockedBookNotice({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.journalBookLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.allMedium,
          ),
          child: Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pemilih buku dari koleksi pengguna untuk jurnal baru.
class _BookPicker extends ConsumerWidget {
  const _BookPicker({
    required this.initialBookId,
    required this.selectedBookId,
    required this.errorText,
    required this.onSelected,
  });

  final String? initialBookId;
  final String? selectedBookId;
  final String? errorText;
  final ValueChanged<LibraryEntry> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AsyncValue<LibraryShelfData> shelf = ref.watch(libraryShelfProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.journalBookLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        shelf.when(
          loading: () =>
              const _InlineLoading(message: AppStrings.journalLibraryLoading),
          error: (Object error, StackTrace stackTrace) => ErrorView(
            message: error is LibraryFailure
                ? error.message
                : AppStrings.libraryLoadError,
            onRetry: () => ref.read(libraryShelfProvider.notifier).retry(),
          ),
          data: (LibraryShelfData data) {
            if (data.entries.isEmpty) {
              return EmptyView(
                title: AppStrings.journalLibraryEmptyTitle,
                message: AppStrings.journalLibraryEmptyMessage,
                icon: Icons.library_books_outlined,
                action: TextButton(
                  onPressed: () => context.push(AppRoutes.homeLibrary),
                  child: const Text(AppStrings.journalOpenLibrary),
                ),
              );
            }

            final String? effectiveSelectedId =
                selectedBookId ?? _matchInitial(data.entries)?.bookId;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final LibraryEntry entry in data.entries) ...[
                  _BookTile(
                    entry: entry,
                    selected: entry.bookId == effectiveSelectedId,
                    onTap: () => onSelected(entry),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }

  LibraryEntry? _matchInitial(List<LibraryEntry> entries) {
    final String? id = initialBookId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final LibraryEntry entry in entries) {
      if (entry.bookId == id) {
        return entry;
      }
    }
    return null;
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final LibraryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final String title = entry.bookTitle.trim().isEmpty
        ? AppStrings.sessionSetupUntitledBook
        : entry.bookTitle.trim();
    final String author = entry.bookAuthor.trim();

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('journal-book-${entry.bookId}'),
          onTap: onTap,
          borderRadius: AppRadius.allLarge,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.surfaceContainerLow
                  : scheme.surfaceContainerLowest,
              borderRadius: AppRadius.allLarge,
              border: Border.all(
                color: selected ? scheme.secondary : extras.cardBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                BookCoverImage(
                  coverUrl: entry.bookCoverUrl,
                  width: 40,
                  height: 56,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs / 2),
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
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? scheme.secondary : scheme.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
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

/// Galat ringkas saat jurnal gagal disimpan.
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

String _journalErrorMessage(Object error) {
  if (error is JournalFailure) {
    return error.message;
  }
  return AppStrings.journalLoadError;
}
