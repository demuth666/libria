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
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/library_shelves.dart';
import '../../reviews/presentation/review_section.dart';
import '../../session/presentation/session_history_screen.dart';
import '../data/book.dart';
import 'book_detail_providers.dart';

/// Layar detail buku pada rute `/book/:id` (T-043).
///
/// Menampilkan data katalog, aksi rak pribadi, dan pintu masuk sesi membaca.
/// Layar ini berada di luar shell user sehingga tampil penuh dengan tombol
/// kembali sendiri. Belum ada desain Stitch untuk layar ini; susunannya
/// mengikuti PRD bagian 5.3 dan 7 serta bahasa visual Koleksi.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({required this.bookId, super.key});

  final String bookId;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeLibrary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Book> book = ref.watch(bookDetailProvider(bookId));

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.bookDetailTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('book-detail-back'),
                tooltip: AppStrings.bookDetailBack,
                padding: EdgeInsets.zero,
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: book.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const LoadingView(message: AppStrings.bookDetailLoading),
              error: (Object error, StackTrace stackTrace) =>
                  _BookDetailErrorView(
                    failure: _asFailure(error),
                    onRetry: () => ref.invalidate(bookDetailProvider(bookId)),
                    onBack: () => _goBack(context),
                  ),
              data: (Book value) => _BookDetailContent(book: value),
            ),
          ),
        ],
      ),
    );
  }
}

BookDetailFailure _asFailure(Object error) {
  if (error is BookDetailFailure) {
    return error;
  }
  return const BookDetailFailure(
    AppStrings.bookDetailLoadError,
    code: BookDetailFailureCode.load,
  );
}

/// Keadaan tidak ditemukan, offline tanpa cache, atau galat pemuatan.
class _BookDetailErrorView extends StatelessWidget {
  const _BookDetailErrorView({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final BookDetailFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (failure.isNotFound) {
      content = EmptyView(
        title: AppStrings.bookDetailNotFoundTitle,
        message: AppStrings.bookDetailNotFoundMessage,
        icon: Icons.search_off_outlined,
        action: SecondaryButton(
          label: AppStrings.bookDetailBack,
          icon: Icons.arrow_back,
          onPressed: onBack,
        ),
      );
    } else if (failure.isOffline) {
      content = EmptyView(
        title: AppStrings.bookDetailOfflineTitle,
        message: AppStrings.bookDetailOfflineMessage,
        icon: Icons.wifi_off_rounded,
        action: PrimaryButton(
          label: AppStrings.retry,
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
      );
    } else {
      content = ErrorView(message: failure.message, onRetry: onRetry);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ContentWidth(maxWidth: 640, child: content),
      ),
    );
  }
}

/// Isi detail buku yang dapat digulir dan dibatasi lebarnya di tablet.
class _BookDetailContent extends StatelessWidget {
  const _BookDetailContent({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return CustomScrollView(
      key: PageStorageKey<String>('book-detail-${book.id}'),
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
                  _BookHero(book: book),
                  const SizedBox(height: AppSpacing.md),
                  _ShelfPanel(book: book),
                  const SizedBox(height: AppSpacing.md),
                  _DetailsCard(book: book),
                  const SizedBox(height: AppSpacing.md),
                  _SynopsisCard(book: book),
                  const SizedBox(height: AppSpacing.md),
                  BookReviewSection(book: book),
                  const SizedBox(height: AppSpacing.md),
                  BookSessionHistoryCard(bookId: book.id),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sampul, judul, dan penulis; berdampingan di tablet dan bertumpuk di ponsel.
class _BookHero extends StatelessWidget {
  const _BookHero({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final bool isCompact = Breakpoints.of(context) == ScreenSize.compact;
    final Widget cover = BookCoverImage(
      coverUrl: book.coverUrl,
      width: isCompact ? _coverWidthCompact : _coverWidthTablet,
      height: isCompact ? _coverHeightCompact : _coverHeightTablet,
      requestWidth: BookCoverWidth.detail,
      borderRadius: AppRadius.allLarge,
    );
    final Widget description = _HeroText(book: book);

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: cover),
          const SizedBox(height: AppSpacing.md),
          description,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cover,
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: description),
      ],
    );
  }
}

const double _coverWidthCompact = 160;
const double _coverHeightCompact = 240;
const double _coverWidthTablet = 200;
const double _coverHeightTablet = 300;

class _HeroText extends StatelessWidget {
  const _HeroText({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String title = _textOrUnavailable(book.title);
    final String author = book.author.trim().isEmpty
        ? AppStrings.bookDetailUnavailable
        : AppStrings.bookDetailByAuthor(book.author.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          author,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Kartu metadata buku.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final List<_MetadataItem> items = <_MetadataItem>[
      _MetadataItem(
        label: AppStrings.bookDetailIsbnLabel,
        value: _textOrUnavailable(book.isbn),
      ),
      _MetadataItem(
        label: AppStrings.bookDetailPublisherLabel,
        value: _textOrUnavailable(book.publisher),
      ),
      _MetadataItem(
        label: AppStrings.bookDetailYearLabel,
        value: book.year > 0
            ? '${book.year}'
            : AppStrings.bookDetailUnavailable,
      ),
      _MetadataItem(
        label: AppStrings.bookDetailPagesLabel,
        value: book.totalPages > 0
            ? '${book.totalPages}'
            : AppStrings.bookDetailUnavailable,
      ),
      _MetadataItem(
        label: AppStrings.bookDetailCategoryLabel,
        value: _textOrUnavailable(book.category),
      ),
    ];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(AppStrings.bookDetailSectionDetails),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth >= 520) {
                const double gap = AppSpacing.md;
                final double itemWidth = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final _MetadataItem item in items)
                      SizedBox(width: itemWidth, child: item),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int index = 0; index < items.length; index++) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.sm),
                    items[index],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({required this.label, required this.value});

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
        const SizedBox(height: AppSpacing.xs / 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Kartu sinopsis buku.
class _SynopsisCard extends StatelessWidget {
  const _SynopsisCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(AppStrings.bookDetailSectionSynopsis),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _textOrUnavailable(book.synopsis),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: book.synopsis.trim().isEmpty
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface,
              fontStyle: book.synopsis.trim().isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu aksi rak dan pintu masuk sesi membaca.
class _ShelfPanel extends ConsumerStatefulWidget {
  const _ShelfPanel({required this.book});

  final Book book;

  @override
  ConsumerState<_ShelfPanel> createState() => _ShelfPanelState();
}

class _ShelfPanelState extends ConsumerState<_ShelfPanel> {
  bool _isSaving = false;
  String? _actionError;
  String? _pageError;

  void _openSession() {
    context.push(AppRoutes.sessionSetupPath(widget.book.id));
  }

  Future<void> _addToLibrary() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _actionError = null;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .addBook(widget.book, status: LibraryEntry.statusWant);
    } on LibraryFailure catch (failure) {
      _setActionError(failure.message);
    } catch (_) {
      _setActionError(AppStrings.libraryAddError);
    } finally {
      _finishSaving();
    }
  }

  Future<void> _changeStatus(String status, {required bool isOffline}) async {
    if (_isSaving) {
      return;
    }
    if (ref.read(libraryEntryProvider(widget.book.id)).value?.status ==
        status) {
      return;
    }
    setState(() {
      _isSaving = true;
      _actionError = null;
      _pageError = null;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateStatus(widget.book.id, status, queueOffline: isOffline);
      if (isOffline) {
        _showQueuedNotice(AppStrings.libraryStatusQueuedOffline);
      }
    } on LibraryFailure catch (failure) {
      _setActionError(failure.message);
    } catch (_) {
      _setActionError(AppStrings.libraryStatusError);
    } finally {
      _finishSaving();
    }
  }

  Future<void> _savePage(String rawValue, {required bool isOffline}) async {
    if (_isSaving) {
      return;
    }
    final int totalPages =
        ref.read(libraryEntryProvider(widget.book.id)).value?.bookTotalPages ??
        0;
    final String value = rawValue.trim();
    final int? page = int.tryParse(value);
    String? error;
    if (totalPages <= 0) {
      error = AppStrings.bookDetailPageUnavailable;
    } else if (value.isEmpty) {
      error = AppStrings.bookDetailPageRequired;
    } else if (page == null) {
      error = AppStrings.bookDetailPageInvalid;
    } else if (page < 0) {
      error = AppStrings.bookDetailPageNegative;
    } else if (page > totalPages) {
      error = AppStrings.bookDetailPageExceeds(totalPages);
    }
    if (error != null) {
      setState(() {
        _pageError = error;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _actionError = null;
      _pageError = null;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateCurrentPage(widget.book.id, page!, queueOffline: isOffline);
      if (isOffline) {
        _showQueuedNotice(AppStrings.libraryPageQueuedOffline);
      }
    } on LibraryFailure catch (failure) {
      _setPageError(failure.message);
    } catch (_) {
      _setPageError(AppStrings.libraryPageError);
    } finally {
      _finishSaving();
    }
  }

  void _setActionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _actionError = message;
    });
  }

  void _showQueuedNotice(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setPageError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pageError = message;
    });
  }

  void _finishSaving() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LibraryEntry?> entry = ref.watch(
      libraryEntryProvider(widget.book.id),
    );
    final bool isOffline = ref.watch(connectivityProvider).value == false;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(AppStrings.bookDetailSectionShelf),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const ValueKey<String>('book-detail-start-session'),
            label: AppStrings.bookDetailStartSession,
            icon: Icons.play_arrow_rounded,
            expand: true,
            onPressed: _openSession,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          entry.when(
            loading: () => const _ShelfLoading(),
            error: (Object error, StackTrace stackTrace) => _ShelfLoadError(
              message: error is LibraryFailure
                  ? error.message
                  : AppStrings.bookDetailShelfLoadError,
              onRetry: () =>
                  ref.invalidate(libraryEntryProvider(widget.book.id)),
            ),
            data: (LibraryEntry? value) {
              if (value == null) {
                return _AddToLibrary(isSaving: _isSaving, onAdd: _addToLibrary);
              }
              return _LibraryEntryPanel(
                entry: value,
                isSaving: _isSaving,
                pageError: _pageError,
                onStatusChanged: (String status) =>
                    _changeStatus(status, isOffline: isOffline),
                onSavePage: (String rawValue) =>
                    _savePage(rawValue, isOffline: isOffline),
              );
            },
          ),
          if (_actionError != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorNotice(message: _actionError!),
          ],
        ],
      ),
    );
  }
}

class _AddToLibrary extends StatelessWidget {
  const _AddToLibrary({required this.isSaving, required this.onAdd});

  final bool isSaving;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.bookDetailAddHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          key: const ValueKey<String>('book-detail-add'),
          label: isSaving
              ? AppStrings.bookDetailSaving
              : AppStrings.bookDetailAddToLibrary,
          icon: Icons.bookmark_add_outlined,
          isLoading: isSaving,
          expand: true,
          onPressed: isSaving ? null : onAdd,
        ),
      ],
    );
  }
}

class _LibraryEntryPanel extends StatelessWidget {
  const _LibraryEntryPanel({
    required this.entry,
    required this.isSaving,
    required this.pageError,
    required this.onStatusChanged,
    required this.onSavePage,
  });

  final LibraryEntry entry;
  final bool isSaving;
  final String? pageError;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSavePage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int percent = libraryProgressPercent(entry);
    final DateTime? finishedAt = entry.finishedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.percentDone(percent),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.secondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppStrings.pagesRead(entry.currentPage, entry.bookTotalPages),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.allFull,
          child: LinearProgressIndicator(
            value: libraryProgressRatio(entry),
            minHeight: AppSpacing.sm,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.bookDetailStatusLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _StatusChoice(
              key: const ValueKey<String>('book-detail-status-want'),
              label: AppStrings.librarySegmentWant,
              selected: entry.status == LibraryEntry.statusWant,
              enabled: !isSaving,
              onSelected: () => onStatusChanged(LibraryEntry.statusWant),
            ),
            _StatusChoice(
              key: const ValueKey<String>('book-detail-status-reading'),
              label: AppStrings.librarySegmentReading,
              selected: entry.status == LibraryEntry.statusReading,
              enabled: !isSaving,
              onSelected: () => onStatusChanged(LibraryEntry.statusReading),
            ),
            _StatusChoice(
              key: const ValueKey<String>('book-detail-status-finished'),
              label: AppStrings.librarySegmentFinished,
              selected: entry.status == LibraryEntry.statusFinished,
              enabled: !isSaving,
              onSelected: () => onStatusChanged(LibraryEntry.statusFinished),
            ),
          ],
        ),
        if (entry.status == LibraryEntry.statusFinished &&
            finishedAt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.libraryFinishedOn(AppDateFormatter.date(finishedAt)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (entry.bookTotalPages > 0)
          _PageEditor(
            key: ValueKey<String>('book-detail-page-${entry.bookId}'),
            currentPage: entry.currentPage,
            totalPages: entry.bookTotalPages,
            isSaving: isSaving,
            errorText: pageError,
            onSave: onSavePage,
          )
        else
          const _InfoNotice(message: AppStrings.bookDetailPageUnavailable),
      ],
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

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
        label: Text(label),
        selected: selected,
        onSelected: enabled ? (_) => onSelected() : null,
        showCheckmark: false,
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainerHigh,
        disabledColor: scheme.surfaceContainerHigh,
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

/// Kolom halaman terakhir beserta validasi dan tombol simpan.
class _PageEditor extends StatefulWidget {
  const _PageEditor({
    required this.currentPage,
    required this.totalPages,
    required this.isSaving,
    required this.errorText,
    required this.onSave,
    super.key,
  });

  final int currentPage;
  final int totalPages;
  final bool isSaving;
  final String? errorText;
  final ValueChanged<String> onSave;

  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentPage}');
  }

  @override
  void didUpdateWidget(covariant _PageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage && !_focusNode.hasFocus) {
      _controller.text = '${widget.currentPage}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const ValueKey<String>('book-detail-page-field'),
          controller: _controller,
          focusNode: _focusNode,
          label: AppStrings.bookDetailPageLabel,
          hint: AppStrings.bookDetailPageHint(widget.totalPages),
          prefixIcon: Icons.auto_stories_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          enabled: !widget.isSaving,
          errorText: widget.errorText,
          onSubmitted: widget.isSaving ? null : widget.onSave,
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          key: const ValueKey<String>('book-detail-save-page'),
          label: widget.isSaving
              ? AppStrings.bookDetailSaving
              : AppStrings.bookDetailPageSave,
          isLoading: widget.isSaving,
          expand: true,
          onPressed: widget.isSaving
              ? null
              : () => widget.onSave(_controller.text),
        ),
      ],
    );
  }
}

class _ShelfLoading extends StatelessWidget {
  const _ShelfLoading();

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
            AppStrings.bookDetailShelfLoading,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfLoadError extends StatelessWidget {
  const _ShelfLoadError({required this.message, required this.onRetry});

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

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.message});

  final String message;

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
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
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

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

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

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
  }
}

String _textOrUnavailable(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? AppStrings.bookDetailUnavailable : trimmed;
}
