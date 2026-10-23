import 'dart:async';

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
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../books/data/book.dart';
import '../../books/presentation/book_detail_providers.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/library_providers.dart';
import '../data/active_session_repository.dart';
import 'active_session_providers.dart';
import 'session_setup_providers.dart';

/// Sumber buku pada layar pengaturan sesi.
enum SessionBookSource { library, catalog }

/// Buku yang dipilih untuk sesi membaca.
///
/// [book] berisi data katalog lengkap bila pilihan berasal dari katalog,
/// hasil pemindaian ISBN, atau buku awal dari Detail Buku. Pilihan dari rak
/// hanya membawa salinan ringkas [LibraryEntry], sehingga tidak perlu membaca
/// ulang koleksi `books`.
class _BookSelection {
  const _BookSelection({
    required this.bookId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.book,
  });

  factory _BookSelection.fromLibraryEntry(LibraryEntry entry) {
    return _BookSelection(
      bookId: entry.bookId,
      title: entry.bookTitle,
      author: entry.bookAuthor,
      coverUrl: entry.bookCoverUrl,
    );
  }

  factory _BookSelection.fromBook(Book book) {
    return _BookSelection(
      bookId: book.id,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      book: book,
    );
  }

  final String bookId;
  final String title;
  final String author;
  final String? coverUrl;

  /// Data katalog lengkap, dipakai untuk menambah buku ke rak bila perlu.
  final Book? book;
}

/// Layar pengaturan sesi pada rute `/session/setup` (T-052, FR-S1 dan FR-S2).
///
/// Pengguna memilih buku dari rak atau katalog, memindai ISBN sebagai jalan
/// pintas, lalu menentukan target durasi dalam menit. Saat sesi dimulai, buku
/// yang belum ada di rak otomatis ditambahkan dengan status Sedang Dibaca.
/// Layar ini belum ada di Stitch; susunannya mengikuti PRD bagian 5.4 dan
/// bahasa visual Koleksi/Detail Buku.
class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({this.initialBookId, super.key});

  /// ID buku yang sudah dipilih, misalnya dari tombol Mulai Sesi di Detail
  /// Buku atau kartu Sedang Dibaca di Beranda.
  final String? initialBookId;

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  static const String _defaultTargetMinutes = '30';

  final TextEditingController _targetController = TextEditingController(
    text: _defaultTargetMinutes,
  );

  late final String? _initialBookId;

  SessionBookSource _source = SessionBookSource.library;
  _BookSelection? _selection;
  bool _isStarting = false;
  String? _targetError;
  String? _startError;

  @override
  void initState() {
    super.initState();
    final String trimmed = widget.initialBookId?.trim() ?? '';
    _initialBookId = trimmed.isEmpty ? null : trimmed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(sessionCatalogProvider.notifier).ensureLoaded());
      }
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  void _selectSource(SessionBookSource source) {
    if (source == _source) {
      return;
    }
    setState(() {
      _source = source;
    });
  }

  void _selectBook(_BookSelection selection) {
    setState(() {
      _selection = selection;
      _startError = null;
    });
  }

  Future<void> _scanIsbn() async {
    final Book? book = await context.push<Book>(AppRoutes.isbnScanPickerPath);
    if (!mounted || book == null) {
      return;
    }
    _selectBook(_BookSelection.fromBook(book));
  }

  void _onTargetChanged(String value) {
    if (_targetError == null && _startError == null) {
      return;
    }
    setState(() {
      _targetError = null;
      _startError = null;
    });
  }

  int? _validateTarget() {
    final String raw = _targetController.text.trim();
    String? error;
    int? minutes;

    if (raw.isEmpty) {
      error = AppStrings.sessionSetupTargetRequired;
    } else {
      minutes = int.tryParse(raw);
      if (minutes == null) {
        error = AppStrings.sessionSetupTargetInvalid;
      } else if (minutes <= 0) {
        error = AppStrings.sessionSetupTargetPositive;
      }
    }

    if (error != null) {
      setState(() {
        _targetError = error;
      });
      return null;
    }

    setState(() {
      _targetError = null;
    });
    return minutes;
  }

  Future<void> _startSession(_BookSelection? selection) async {
    if (_isStarting || selection == null) {
      return;
    }

    final int? targetMinutes = _validateTarget();
    if (targetMinutes == null) {
      return;
    }

    setState(() {
      _isStarting = true;
      _startError = null;
    });

    try {
      final Book? book = selection.book;
      if (book != null) {
        // Buku dari katalog atau pemindaian belum tentu ada di rak. Daftar rak
        // yang sedang ditampilkan dipakai sebagai sumber kebenaran agar buku
        // yang sudah ada tidak ditulis ulang dan tetap bisa dibaca saat
        // offline.
        final LibraryShelfData? shelf = ref.read(libraryShelfProvider).value;
        final bool inLibrary =
            shelf?.entries.any(
              (LibraryEntry entry) => entry.bookId == selection.bookId,
            ) ??
            false;
        if (!inLibrary) {
          await ref
              .read(libraryRepositoryProvider)
              .addBook(book, status: LibraryEntry.statusReading);
        }
      }

      if (!mounted) {
        return;
      }
      await ref
          .read(activeSessionProvider.notifier)
          .start(
            bookId: selection.bookId,
            bookTitle: selection.title.trim().isEmpty
                ? AppStrings.sessionSetupUntitledBook
                : selection.title.trim(),
            target: Duration(minutes: targetMinutes),
          );
      if (!mounted) {
        return;
      }
      context.go(AppRoutes.sessionRun);
    } on ActiveSessionFailure catch (failure) {
      _setStartError(failure.message);
    } on LibraryFailure catch (failure) {
      _setStartError(failure.message);
    } on BookDetailFailure catch (failure) {
      _setStartError(failure.message);
    } catch (_) {
      _setStartError(AppStrings.sessionSetupStartError);
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  void _setStartError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _startError = message;
    });
  }

  LibraryEntry? _entryFor(List<LibraryEntry> entries, String bookId) {
    for (final LibraryEntry entry in entries) {
      if (entry.bookId == bookId) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LibraryShelfData> shelf = ref.watch(libraryShelfProvider);
    final AsyncValue<SessionCatalogData> catalog = ref.watch(
      sessionCatalogProvider,
    );
    final bool isOffline = ref.watch(connectivityProvider).value == false;
    final AsyncValue<Book>? initialBook = _initialBookId == null
        ? null
        : ref.watch(bookDetailProvider(_initialBookId));

    _BookSelection? selection = _selection;
    if (selection == null && initialBook != null) {
      final Book? book = initialBook.value;
      if (book != null) {
        selection = _BookSelection.fromBook(book);
      }
    }

    final LibraryShelfData? shelfData = shelf.value;
    final LibraryEntry? selectedEntry = selection == null || shelfData == null
        ? null
        : _entryFor(shelfData.entries, selection.bookId);

    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.sessionSetupTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('session-setup-back'),
                tooltip: AppStrings.sessionSetupBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              key: const PageStorageKey<String>('session-setup'),
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
                      maxWidth: 960,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppStrings.sessionSetupIntro,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SelectedBookCard(
                            selection: selection,
                            initialBook: initialBook,
                            selectedEntry: selectedEntry,
                            onRetryInitial: _initialBookId == null
                                ? null
                                : () => ref.invalidate(
                                    bookDetailProvider(_initialBookId),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionTitle(AppStrings.sessionSetupPickBook),
                          const SizedBox(height: AppSpacing.sm),
                          _SourcePicker(
                            source: _source,
                            onSourceChanged: _selectSource,
                            onScan: _scanIsbn,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_source == SessionBookSource.library)
                            _LibraryChoices(
                              shelf: shelf,
                              isOffline: isOffline,
                              selectedBookId: selection?.bookId,
                              onSelected: _selectBook,
                              onRetry: () => ref
                                  .read(libraryShelfProvider.notifier)
                                  .retry(),
                              onOpenCatalog: () =>
                                  _selectSource(SessionBookSource.catalog),
                            )
                          else
                            _CatalogChoices(
                              catalog: catalog,
                              isOffline: isOffline,
                              selectedBookId: selection?.bookId,
                              onSelected: _selectBook,
                              onRetry: () => ref
                                  .read(sessionCatalogProvider.notifier)
                                  .retry(),
                              onLoadMore: () => ref
                                  .read(sessionCatalogProvider.notifier)
                                  .loadMore(),
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
      bottomNavigationBar: _SessionStartPanel(
        targetController: _targetController,
        targetError: _targetError,
        startError: _startError,
        isStarting: _isStarting,
        canStart: selection != null,
        onTargetChanged: _onTargetChanged,
        onStart: () => _startSession(selection),
      ),
    );
  }
}

/// Judul bagian di dalam isi layar.
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

/// Kartu buku yang sedang dipilih beserta status raknya.
class _SelectedBookCard extends StatelessWidget {
  const _SelectedBookCard({
    required this.selection,
    required this.initialBook,
    required this.selectedEntry,
    required this.onRetryInitial,
  });

  final _BookSelection? selection;
  final AsyncValue<Book>? initialBook;
  final LibraryEntry? selectedEntry;
  final VoidCallback? onRetryInitial;

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
                Icons.bookmark_added_outlined,
                size: 20,
                color: scheme.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.sessionSetupSelectedBook,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (selection != null)
            _SelectedBookContent(
              selection: selection!,
              selectedEntry: selectedEntry,
            )
          else if (initialBook != null)
            initialBook!.when(
              loading: () => const _InlineLoading(
                message: AppStrings.sessionSetupBookLoading,
              ),
              error: (Object error, StackTrace stackTrace) => _InlineError(
                message: error is BookDetailFailure
                    ? error.message
                    : AppStrings.sessionSetupBookLoadError,
                onRetry: onRetryInitial,
              ),
              data: (Book? book) => const _EmptySelection(),
            )
          else
            const _EmptySelection(),
        ],
      ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.menu_book_outlined,
          size: 24,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.sessionSetupNoBookTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.sessionSetupNoBookMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedBookContent extends StatelessWidget {
  const _SelectedBookContent({
    required this.selection,
    required this.selectedEntry,
  });

  final _BookSelection selection;
  final LibraryEntry? selectedEntry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String title = selection.title.trim().isEmpty
        ? AppStrings.sessionSetupUntitledBook
        : selection.title.trim();
    final String author = selection.author.trim();
    final String? statusLabel = selectedEntry == null
        ? null
        : _statusLabel(selectedEntry!.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCoverImage(coverUrl: selection.coverUrl, width: 56, height: 80),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: AppSpacing.sm),
              if (selectedEntry == null)
                Text(
                  AppStrings.sessionSetupWillAdd,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                _StatusPill(
                  label: statusLabel == null
                      ? AppStrings.sessionSetupInShelf
                      : AppStrings.sessionSetupShelfStatus(statusLabel),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Label status rak yang dikenal; status tak dikenal tidak ditampilkan.
String? _statusLabel(String status) {
  switch (status) {
    case LibraryEntry.statusReading:
      return AppStrings.librarySegmentReading;
    case LibraryEntry.statusWant:
      return AppStrings.librarySegmentWant;
    case LibraryEntry.statusFinished:
      return AppStrings.librarySegmentFinished;
    default:
      return null;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

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
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allFull,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Pemilih sumber buku dan tombol pintasan pemindaian ISBN.
class _SourcePicker extends StatelessWidget {
  const _SourcePicker({
    required this.source,
    required this.onSourceChanged,
    required this.onScan,
  });

  final SessionBookSource source;
  final ValueChanged<SessionBookSource> onSourceChanged;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final Widget segmented = SegmentedButton<SessionBookSource>(
      style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
      segments: const <ButtonSegment<SessionBookSource>>[
        ButtonSegment<SessionBookSource>(
          value: SessionBookSource.library,
          label: Text(AppStrings.sessionSetupSourceLibrary),
          icon: Icon(Icons.library_books_outlined),
        ),
        ButtonSegment<SessionBookSource>(
          value: SessionBookSource.catalog,
          label: Text(AppStrings.sessionSetupSourceCatalog),
          icon: Icon(Icons.menu_book_outlined),
        ),
      ],
      selected: <SessionBookSource>{source},
      showSelectedIcon: false,
      onSelectionChanged: (Set<SessionBookSource> selection) {
        if (selection.isNotEmpty) {
          onSourceChanged(selection.first);
        }
      },
    );

    final Widget scanButton = SecondaryButton(
      key: const ValueKey<String>('session-setup-scan'),
      label: AppStrings.sessionSetupScanIsbn,
      icon: Icons.qr_code_scanner,
      onPressed: onScan,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              Expanded(child: segmented),
              const SizedBox(width: AppSpacing.md),
              scanButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            segmented,
            const SizedBox(height: AppSpacing.sm),
            scanButton,
          ],
        );
      },
    );
  }
}

/// Daftar buku pada rak pengguna.
class _LibraryChoices extends StatelessWidget {
  const _LibraryChoices({
    required this.shelf,
    required this.isOffline,
    required this.selectedBookId,
    required this.onSelected,
    required this.onRetry,
    required this.onOpenCatalog,
  });

  final AsyncValue<LibraryShelfData> shelf;
  final bool isOffline;
  final String? selectedBookId;
  final ValueChanged<_BookSelection> onSelected;
  final VoidCallback onRetry;
  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    if (shelf.isLoading && isOffline) {
      return EmptyView(
        title: AppStrings.libraryOfflineTitle,
        message: AppStrings.libraryOfflineMessage,
        icon: Icons.wifi_off_rounded,
        action: PrimaryButton(
          label: AppStrings.retry,
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
      );
    }

    return shelf.when(
      loading: () => const _InlineLoading(message: AppStrings.libraryLoading),
      error: (Object error, StackTrace stackTrace) => ErrorView(
        message: error is LibraryFailure
            ? error.message
            : AppStrings.libraryLoadError,
        onRetry: onRetry,
      ),
      data: (LibraryShelfData data) {
        if (data.entries.isEmpty) {
          return EmptyView(
            title: AppStrings.libraryEmptyTitle,
            message: AppStrings.sessionSetupLibraryEmptyMessage,
            icon: Icons.library_books_outlined,
            action: TextButton(
              onPressed: onOpenCatalog,
              child: const Text(AppStrings.sessionSetupOpenCatalog),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.streamError != null) ...[
              _Notice(message: AppStrings.libraryStaleMessage),
              const SizedBox(height: AppSpacing.sm),
            ],
            for (final LibraryEntry entry in data.entries) ...[
              _BookChoiceTile(
                bookId: entry.bookId,
                title: entry.bookTitle,
                author: entry.bookAuthor,
                coverUrl: entry.bookCoverUrl,
                statusLabel: _statusLabel(entry.status),
                selected: entry.bookId == selectedBookId,
                onTap: () => onSelected(_BookSelection.fromLibraryEntry(entry)),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

/// Daftar buku katalog dengan paginasi dan keadaan kosong, galat, serta
/// offline.
class _CatalogChoices extends StatelessWidget {
  const _CatalogChoices({
    required this.catalog,
    required this.isOffline,
    required this.selectedBookId,
    required this.onSelected,
    required this.onRetry,
    required this.onLoadMore,
  });

  final AsyncValue<SessionCatalogData> catalog;
  final bool isOffline;
  final String? selectedBookId;
  final ValueChanged<_BookSelection> onSelected;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return catalog.when(
      loading: () =>
          const _InlineLoading(message: AppStrings.sessionSetupCatalogLoading),
      error: (Object error, StackTrace stackTrace) => isOffline
          ? EmptyView(
              title: AppStrings.sessionSetupCatalogOfflineTitle,
              message: AppStrings.sessionSetupCatalogOfflineMessage,
              icon: Icons.wifi_off_rounded,
              action: PrimaryButton(
                label: AppStrings.retry,
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            )
          : ErrorView(
              message: AppStrings.sessionSetupCatalogError,
              onRetry: onRetry,
            ),
      data: (SessionCatalogData data) {
        if (data.isEmpty) {
          return const EmptyView(
            title: AppStrings.sessionSetupCatalogEmptyTitle,
            message: AppStrings.sessionSetupCatalogEmptyMessage,
            icon: Icons.menu_book_outlined,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final Book book in data.books) ...[
              _BookChoiceTile(
                bookId: book.id,
                title: book.title,
                author: book.author,
                coverUrl: book.coverUrl,
                selected: book.id == selectedBookId,
                onTap: () => onSelected(_BookSelection.fromBook(book)),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (data.loadMoreFailed) ...[
              _Notice(message: AppStrings.catalogSearchLoadMoreError),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (data.hasMore)
              SecondaryButton(
                key: const ValueKey<String>('session-setup-load-more'),
                label: AppStrings.catalogSearchLoadMore,
                icon: data.loadMoreFailed ? Icons.refresh : Icons.expand_more,
                isLoading: data.isLoadingMore,
                expand: true,
                onPressed: data.isLoadingMore ? null : onLoadMore,
              ),
          ],
        );
      },
    );
  }
}

/// Kartu pilihan buku pada daftar rak atau katalog.
class _BookChoiceTile extends StatelessWidget {
  const _BookChoiceTile({
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.selected,
    required this.onTap,
    this.statusLabel,
  });

  final String bookId;
  final String title;
  final String author;
  final String? coverUrl;
  final String? statusLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final String displayTitle = title.trim().isEmpty
        ? AppStrings.sessionSetupUntitledBook
        : title.trim();
    final String displayAuthor = author.trim();

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('session-setup-book-$bookId'),
          onTap: onTap,
          borderRadius: AppRadius.allLarge,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.surfaceContainerLow
                  : scheme.surfaceContainerLowest,
              borderRadius: AppRadius.allLarge,
              border: Border.all(
                color: selected ? scheme.secondary : extras.cardBorder,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? null : AppShadows.card,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCoverImage(coverUrl: coverUrl, width: 48, height: 68),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (displayAuthor.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          displayAuthor,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (statusLabel != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _StatusPill(label: statusLabel!),
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

/// Panel tetap di bagian bawah: target menit dan tombol Mulai Sesi.
class _SessionStartPanel extends StatelessWidget {
  const _SessionStartPanel({
    required this.targetController,
    required this.targetError,
    required this.startError,
    required this.isStarting,
    required this.canStart,
    required this.onTargetChanged,
    required this.onStart,
  });

  final TextEditingController targetController;
  final String? targetError;
  final String? startError;
  final bool isStarting;
  final bool canStart;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    final Widget targetField = AppTextField(
      key: const ValueKey<String>('session-setup-target'),
      controller: targetController,
      label: AppStrings.sessionSetupTargetLabel,
      hint: AppStrings.sessionSetupTargetHint,
      prefixIcon: Icons.timer_outlined,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      enabled: !isStarting,
      errorText: targetError,
      onChanged: onTargetChanged,
      onSubmitted: (_) {
        if (canStart && !isStarting) {
          onStart();
        }
      },
    );

    final Widget startButton = PrimaryButton(
      key: const ValueKey<String>('session-setup-start'),
      label: isStarting
          ? AppStrings.sessionSetupStarting
          : AppStrings.sessionSetupStart,
      icon: Icons.play_arrow_rounded,
      isLoading: isStarting,
      expand: true,
      onPressed: canStart && !isStarting ? onStart : null,
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
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget? error = startError == null
                      ? null
                      : _ErrorNotice(message: startError!);

                  if (constraints.maxWidth < 320) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (error != null) ...[
                          error,
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        targetField,
                        const SizedBox(height: AppSpacing.sm),
                        startButton,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (error != null) ...[
                        error,
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 132, child: targetField),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: startButton),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indikator loading ringkas di dalam daftar.
class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LoadingView(message: message),
    );
  }
}

/// Pesan galat ringkas dengan aksi coba lagi.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text(AppStrings.retry),
          ),
      ],
    );
  }
}

/// Pemberitahuan ringan untuk data basi atau pemuatan tambahan yang gagal.
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

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

/// Kotak galat yang tampil di panel bawah saat sesi gagal dimulai.
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
