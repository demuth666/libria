import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/library_entry.dart';
import '../data/library_repository.dart';
import 'library_providers.dart';
import 'library_shelves.dart';

/// Layar Koleksi pada rute `/home/library` (T-041).
///
/// Layar berada di dalam shell user sehingga navigasi bawah tetap tampil.
/// Seluruh entri dibaca dari satu stream [libraryShelfProvider]; hitungan dan
/// filter segmen dihitung di memori. Header, kontrol segmen, kartu, dan kartu
/// kutipan mengikuti desain Stitch "Libria - Koleksi Saya"
/// (`docs/design/stitch/koleksi.*`).
///
/// Pencarian katalog dibuka sebagai layar tersendiri lewat ikon di header
/// (T-042). FAB "Tambah Buku", menu ubah status, dan tombol "Lanjut Sesi"
/// sengaja belum dibuat karena milik T-043 dan T-052.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibrarySection _section = LibrarySection.reading;

  void _retry() {
    ref.read(libraryShelfProvider.notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LibraryShelfData> shelf = ref.watch(libraryShelfProvider);
    final bool isOffline = ref.watch(connectivityProvider).value == false;

    return Column(
      children: [
        const _LibraryHeader(),
        Expanded(
          child: _LibraryContent(
            shelf: shelf,
            isOffline: isOffline,
            section: _section,
            onSectionChanged: (LibrarySection section) {
              if (section == _section) {
                return;
              }
              setState(() {
                _section = section;
              });
            },
            onRetry: _retry,
          ),
        ),
      ],
    );
  }
}

/// Header tetap dengan ikon buku, judul layar, dan pencarian.
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ScreenHeader(
      title: AppStrings.libraryTitle,
      leading: Icon(
        Icons.auto_stories_outlined,
        size: 24,
        color: scheme.secondary,
      ),
      actions: <Widget>[
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: AppStrings.catalogSearchTitle,
            padding: EdgeInsets.zero,
            onPressed: () => context.push(AppRoutes.homeLibrarySearch),
            icon: const Icon(Icons.search),
          ),
        ),
      ],
    );
  }
}

/// Isi layar: keadaan awal, keadaan kosong, atau daftar per segmen.
class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.shelf,
    required this.isOffline,
    required this.section,
    required this.onSectionChanged,
    required this.onRetry,
  });

  final AsyncValue<LibraryShelfData> shelf;
  final bool isOffline;
  final LibrarySection section;
  final ValueChanged<LibrarySection> onSectionChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom +
        AppBottomNavBar.height +
        AppSpacing.lg;

    return shelf.when(
      loading: () => isOffline
          ? _LibraryOfflineView(onRetry: onRetry, bottomInset: bottomInset)
          : LoadingView(message: AppStrings.libraryLoading),
      error: (Object error, StackTrace stackTrace) => _LibraryErrorView(
        message: _errorMessage(error),
        onRetry: onRetry,
        bottomInset: bottomInset,
      ),
      data: (LibraryShelfData data) => _buildData(context, data, bottomInset),
    );
  }

  Widget _buildData(
    BuildContext context,
    LibraryShelfData data,
    double bottomInset,
  ) {
    final LibraryShelves shelves = LibraryShelves.fromEntries(data.entries);
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final String? streamError = data.streamError;

    if (shelves.isEmpty) {
      // Rak kosong tetap menampilkan kontrol segmen dengan hitungan nol,
      // tetapi hanya satu keadaan kosong untuk seluruh rak.
      return CustomScrollView(
        key: const PageStorageKey<String>('library-empty'),
        slivers: [
          _segmentSliver(horizontalPadding, shelves),
          if (streamError != null) _streamErrorSliver(horizontalPadding),
          SliverFillRemaining(
            hasScrollBody: false,
            child: const _LibraryEmptyView(
              title: AppStrings.libraryEmptyTitle,
              message: AppStrings.libraryEmptyMessage,
              icon: Icons.library_books_outlined,
              showSearchAction: true,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
        ],
      );
    }

    final List<LibraryEntry> entries = shelves.entriesFor(section);

    return CustomScrollView(
      key: PageStorageKey<String>('library-${section.name}'),
      slivers: [
        _segmentSliver(horizontalPadding, shelves),
        if (streamError != null) _streamErrorSliver(horizontalPadding),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _LibraryEmptyView(
              title: _sectionCopy[section]!.emptyTitle,
              message: _sectionCopy[section]!.emptyMessage,
              icon: _sectionCopy[section]!.icon,
            ),
          )
        else if (section == LibrarySection.want)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 960,
                child: _WantGrid(entries: entries),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              AppSpacing.lg,
            ),
            sliver: SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (BuildContext context, int index) {
                final LibraryEntry entry = entries[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ContentWidth(
                    maxWidth: 960,
                    child: section == LibrarySection.reading
                        ? _ReadingCard(entry: entry)
                        : _FinishedRow(entry: entry),
                  ),
                );
              },
            ),
          ),
        if (entries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                bottomInset,
              ),
              child: const ContentWidth(
                maxWidth: 960,
                child: _LibraryQuoteCard(),
              ),
            ),
          )
        else
          SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    );
  }

  SliverToBoxAdapter _streamErrorSliver(double horizontalPadding) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          AppSpacing.md,
        ),
        child: ContentWidth(
          maxWidth: 960,
          child: _StreamErrorNotice(onRetry: onRetry),
        ),
      ),
    );
  }

  SliverToBoxAdapter _segmentSliver(
    double horizontalPadding,
    LibraryShelves shelves,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.md,
          horizontalPadding,
          AppSpacing.md,
        ),
        child: ContentWidth(
          maxWidth: 960,
          child: _LibrarySegmentedControl(
            shelves: shelves,
            selected: section,
            onSelected: onSectionChanged,
          ),
        ),
      ),
    );
  }
}

/// Kontrol segmen tiga rak dengan jumlah entri masing-masing.
class _LibrarySegmentedControl extends StatelessWidget {
  const _LibrarySegmentedControl({
    required this.shelves,
    required this.selected,
    required this.onSelected,
  });

  final LibraryShelves shelves;
  final LibrarySection selected;
  final ValueChanged<LibrarySection> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.allMedium,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final LibrarySection section in LibrarySection.values)
              Expanded(
                child: _SegmentButton(
                  section: section,
                  count: shelves.countFor(section),
                  selected: section == selected,
                  onTap: () => onSelected(section),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Satu pilihan pada kontrol segmen.
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.section,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final LibrarySection section;
  final int count;
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
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: AppRadius.allSmall,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('library-section-${section.name}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _sectionCopy[section]!.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs / 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.secondary
                          : scheme.surfaceContainerHighest,
                      borderRadius: AppRadius.allFull,
                    ),
                    child: Text(
                      '$count',
                      key: ValueKey<String>('library-count-${section.name}'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected
                            ? scheme.onSecondary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
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

/// Kartu buku pada segmen Sedang Dibaca.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double ratio = libraryProgressRatio(entry);
    final int percent = libraryProgressPercent(entry);

    return DecoratedBox(
      key: ValueKey<String>('library-reading-${entry.bookId}'),
      decoration: const BoxDecoration(
        borderRadius: AppRadius.allMedium,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openBook(context, entry.bookId),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCoverImage(coverUrl: entry.bookCoverUrl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.bookTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        entry.bookAuthor,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppStrings.percentDone(percent),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.secondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppStrings.pagesRead(
                              entry.currentPage,
                              entry.bookTotalPages,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: AppRadius.allFull,
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: AppSpacing.sm,
                        ),
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

/// Grid sampul pada segmen Ingin Dibaca.
class _WantGrid extends StatelessWidget {
  const _WantGrid({required this.entries});

  final List<LibraryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ScreenSize screenSize = Breakpoints.of(context);
    final int columns = switch (screenSize) {
      ScreenSize.compact => 2,
      ScreenSize.medium => 3,
      ScreenSize.expanded => 4,
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.gridGutterSmall;
        final double tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final LibraryEntry entry in entries)
              SizedBox(
                width: tileWidth,
                child: _WantTile(entry: entry),
              ),
          ],
        );
      },
    );
  }
}

/// Satu buku pada grid Ingin Dibaca.
class _WantTile extends StatelessWidget {
  const _WantTile({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return DecoratedBox(
      key: ValueKey<String>('library-want-${entry.bookId}'),
      decoration: const BoxDecoration(
        borderRadius: AppRadius.allMedium,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openBook(context, entry.bookId),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          return BookCoverImage(
                            coverUrl: entry.bookCoverUrl,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                          );
                        },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  entry.bookTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.bookAuthor,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
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

/// Baris ringkas buku pada segmen Selesai.
class _FinishedRow extends StatelessWidget {
  const _FinishedRow({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? finishedAt = entry.finishedAt;

    return DecoratedBox(
      key: ValueKey<String>('library-finished-${entry.bookId}'),
      decoration: const BoxDecoration(
        borderRadius: AppRadius.allMedium,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openBook(context, entry.bookId),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
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
                        entry.bookTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        entry.bookAuthor,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (finishedAt != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppStrings.libraryFinishedOn(
                            AppDateFormatter.date(finishedAt),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

/// Pemberitahuan ringan saat stream gagal setelah data tampil.
class _StreamErrorNotice extends StatelessWidget {
  const _StreamErrorNotice({required this.onRetry});

  final VoidCallback onRetry;

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
        children: [
          Icon(
            Icons.sync_problem_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.libraryStaleMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onErrorContainer,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}

/// Keadaan kosong untuk seluruh rak atau satu segmen.
class _LibraryEmptyView extends StatelessWidget {
  const _LibraryEmptyView({
    required this.title,
    required this.message,
    required this.icon,
    this.showSearchAction = false,
  });

  final String title;
  final String message;
  final IconData icon;

  /// Menampilkan aksi "Cari Katalog" pada keadaan kosong seluruh rak.
  final bool showSearchAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ContentWidth(
        maxWidth: 640,
        child: EmptyView(
          title: title,
          message: message,
          icon: icon,
          action: showSearchAction
              ? SecondaryButton(
                  label: AppStrings.catalogSearchTitle,
                  icon: Icons.search,
                  onPressed: () => context.push(AppRoutes.homeLibrarySearch),
                )
              : null,
        ),
      ),
    );
  }
}

/// Keadaan offline tanpa data cache.
class _LibraryOfflineView extends StatelessWidget {
  const _LibraryOfflineView({required this.onRetry, required this.bottomInset});

  final VoidCallback onRetry;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ContentWidth(
          maxWidth: 640,
          child: EmptyView(
            title: AppStrings.libraryOfflineTitle,
            message: AppStrings.libraryOfflineMessage,
            icon: Icons.wifi_off_rounded,
            action: PrimaryButton(
              label: AppStrings.retry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keadaan galat pemuatan awal.
class _LibraryErrorView extends StatelessWidget {
  const _LibraryErrorView({
    required this.message,
    required this.onRetry,
    required this.bottomInset,
  });

  final String message;
  final VoidCallback onRetry;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ContentWidth(
          maxWidth: 640,
          child: ErrorView(message: message, onRetry: onRetry),
        ),
      ),
    );
  }
}

/// Kartu kutipan dekoratif di kaki daftar.
class _LibraryQuoteCard extends StatelessWidget {
  const _LibraryQuoteCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, size: 24, color: scheme.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.libraryQuote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.libraryQuoteAuthor,
                  style: theme.textTheme.labelSmall?.copyWith(
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

void _openBook(BuildContext context, String bookId) {
  context.push(AppRoutes.bookDetailPath(bookId));
}

String _errorMessage(Object error) {
  return error is LibraryFailure ? error.message : AppStrings.libraryLoadError;
}

/// Teks dan ikon tetap tiap segmen.
class _SectionCopy {
  const _SectionCopy({
    required this.label,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.icon,
  });

  final String label;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;
}

const Map<LibrarySection, _SectionCopy> _sectionCopy =
    <LibrarySection, _SectionCopy>{
      LibrarySection.reading: _SectionCopy(
        label: AppStrings.librarySegmentReading,
        emptyTitle: AppStrings.libraryEmptyReadingTitle,
        emptyMessage: AppStrings.libraryEmptyReadingMessage,
        icon: Icons.auto_stories_outlined,
      ),
      LibrarySection.want: _SectionCopy(
        label: AppStrings.librarySegmentWant,
        emptyTitle: AppStrings.libraryEmptyWantTitle,
        emptyMessage: AppStrings.libraryEmptyWantMessage,
        icon: Icons.bookmark_border_rounded,
      ),
      LibrarySection.finished: _SectionCopy(
        label: AppStrings.librarySegmentFinished,
        emptyTitle: AppStrings.libraryEmptyFinishedTitle,
        emptyMessage: AppStrings.libraryEmptyFinishedMessage,
        icon: Icons.task_alt_rounded,
      ),
    };
