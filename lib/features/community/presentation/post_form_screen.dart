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
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/library_providers.dart';
import '../data/post_repository.dart';

/// Formulir postingan teks baru pada rute `/post/new` (T-081, FR-K2).
///
/// Isi postingan wajib diisi dan dibatasi [postContentMaxLength] karakter.
/// Buku bersifat opsional dan dipilih dari koleksi pengguna lewat lembar
/// pemilih. Setelah tersimpan, layar kembali ke feed Komunitas; postingan baru
/// langsung tampil karena feed memakai stream Firestore.
///
/// Layar ini tidak memiliki desain tersendiri di Stitch. Susunannya mengikuti
/// PRD bagian 5.8 dan bahasa visual kartu Komunitas: header kaca, kolom isi,
/// kartu tautan buku, dan tombol kirim.
class PostFormScreen extends ConsumerStatefulWidget {
  const PostFormScreen({super.key});

  @override
  ConsumerState<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends ConsumerState<PostFormScreen> {
  late final TextEditingController _contentController;
  LibraryEntry? _selectedBook;
  bool _isSubmitting = false;
  String? _contentError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeCommunity);
  }

  void _onContentChanged(String value) {
    if (_contentError == null && _submitError == null) {
      return;
    }
    setState(() {
      _contentError = null;
      _submitError = null;
    });
  }

  Future<void> _pickBook() async {
    final LibraryEntry? entry = await showModalBottomSheet<LibraryEntry>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _BookPickerSheet(selectedBookId: _selectedBook?.bookId);
      },
    );
    if (!mounted || entry == null) {
      return;
    }
    setState(() {
      _selectedBook = entry;
    });
  }

  void _clearBook() {
    setState(() {
      _selectedBook = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final String content = _contentController.text;
    final String? contentError = PostRepository.validateContent(content);
    if (contentError != null) {
      setState(() {
        _contentError = contentError;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _contentError = null;
      _submitError = null;
    });

    try {
      final AppUser? currentUser = ref.read(currentUserProvider).value;
      await ref
          .read(postRepositoryProvider)
          .createPost(
            content: content.trim(),
            authorName: currentUser?.displayName,
            authorPhotoUrl: currentUser?.photoUrl,
            bookId: _selectedBook?.bookId,
            bookTitle: _selectedBook?.bookTitle,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.communityPostCreated)),
        );
      _goBack();
    } on PostFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = failure.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = AppStrings.communityPostCreateError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.communityPostNewTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('post-form-back'),
                tooltip: AppStrings.communityPostFormBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                      Text(
                        AppStrings.communityPostNewSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        key: const ValueKey<String>('post-content-field'),
                        controller: _contentController,
                        enabled: !_isSubmitting,
                        autofocus: true,
                        label: AppStrings.communityPostContentLabel,
                        hint: AppStrings.communityPostContentHint,
                        errorText: _contentError,
                        maxLines: 8,
                        maxLength: postContentMaxLength,
                        onChanged: _onContentChanged,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _BookLinkSection(
                        selectedBook: _selectedBook,
                        enabled: !_isSubmitting,
                        onPick: _pickBook,
                        onClear: _clearBook,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_submitError != null) ...[
                        _SubmitErrorNotice(message: _submitError!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      PrimaryButton(
                        key: const ValueKey<String>('post-submit'),
                        label: _isSubmitting
                            ? AppStrings.communityPostSubmitting
                            : AppStrings.communityPostSubmit,
                        icon: Icons.send_rounded,
                        isLoading: _isSubmitting,
                        expand: true,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu tautan buku opsional pada formulir.
class _BookLinkSection extends StatelessWidget {
  const _BookLinkSection({
    required this.selectedBook,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final LibraryEntry? selectedBook;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

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
                Icons.bookmark_add_outlined,
                size: 20,
                color: scheme.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.communityPostBookTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _OptionalBadge(label: AppStrings.communityPostBookOptional),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (selectedBook != null)
            _SelectedBookCard(
              entry: selectedBook!,
              enabled: enabled,
              onClear: onClear,
            )
          else
            SecondaryButton(
              key: const ValueKey<String>('post-book-pick'),
              label: AppStrings.communityPostBookChoose,
              icon: Icons.menu_book_outlined,
              expand: true,
              onPressed: enabled ? onPick : null,
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.communityPostBookHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label kecil "Opsional" pada kartu tautan buku.
class _OptionalBadge extends StatelessWidget {
  const _OptionalBadge({required this.label});

  final String label;

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
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allFull,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Buku yang sudah ditautkan beserta tombol melepas tautan.
class _SelectedBookCard extends StatelessWidget {
  const _SelectedBookCard({
    required this.entry,
    required this.enabled,
    required this.onClear,
  });

  final LibraryEntry entry;
  final bool enabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final String title = _bookTitle(entry);
    final String author = entry.bookAuthor.trim();

    return Container(
      key: ValueKey<String>('post-book-selected-${entry.bookId}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allMedium,
        border: Border.all(color: extras.cardBorder),
      ),
      child: Row(
        children: [
          BookCoverImage(coverUrl: entry.bookCoverUrl, width: 40, height: 56),
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
          IconButton(
            key: const ValueKey<String>('post-book-clear'),
            tooltip: AppStrings.communityPostBookRemove,
            onPressed: enabled ? onClear : null,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

/// Lembar pemilih buku dari koleksi pengguna.
class _BookPickerSheet extends ConsumerWidget {
  const _BookPickerSheet({required this.selectedBookId});

  final String? selectedBookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AsyncValue<LibraryShelfData> shelf = ref.watch(libraryShelfProvider);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.communityPostBookPickerTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.communityPostBookPickerClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: shelf.when(
                loading: () => const LoadingView(
                  message: AppStrings.communityPostBookPickerLoading,
                ),
                error: (Object error, StackTrace stackTrace) => ErrorView(
                  message: error is LibraryFailure
                      ? error.message
                      : AppStrings.communityPostBookPickerError,
                  onRetry: () =>
                      ref.read(libraryShelfProvider.notifier).retry(),
                ),
                data: (LibraryShelfData data) {
                  if (data.entries.isEmpty) {
                    return const EmptyView(
                      title: AppStrings.communityPostBookPickerEmptyTitle,
                      message: AppStrings.communityPostBookPickerEmptyMessage,
                      icon: Icons.library_books_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    itemCount: data.entries.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int index) {
                      final LibraryEntry entry = data.entries[index];
                      return _BookOptionTile(
                        entry: entry,
                        selected: entry.bookId == selectedBookId,
                        onTap: () => Navigator.of(context).pop(entry),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu pilihan buku pada lembar pemilih.
class _BookOptionTile extends StatelessWidget {
  const _BookOptionTile({
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
    final String title = _bookTitle(entry);
    final String author = entry.bookAuthor.trim();

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('post-book-${entry.bookId}'),
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
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 24,
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

/// Galat ringkas saat postingan gagal dibuat.
class _SubmitErrorNotice extends StatelessWidget {
  const _SubmitErrorNotice({required this.message});

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

String _bookTitle(LibraryEntry entry) {
  final String title = entry.bookTitle.trim();
  return title.isEmpty ? AppStrings.sessionSetupUntitledBook : title;
}
