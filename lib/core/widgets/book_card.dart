import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Kartu buku untuk daftar rak, katalog, dan hasil pencarian.
///
/// Menampilkan sampul, judul, penulis, label kategori opsional, dan bar
/// progres baca bila [currentPage] dan [totalPages] diisi.
class BookCard extends StatelessWidget {
  const BookCard({
    required this.title,
    required this.author,
    this.coverUrl,
    this.isbn,
    this.category,
    this.currentPage,
    this.totalPages,
    this.trailing,
    this.onTap,
    super.key,
  });

  /// Judul buku.
  final String title;

  /// Nama penulis.
  final String author;

  /// URL sampul; bila kosong kartu memakai sampul pengganti.
  final String? coverUrl;

  /// ISBN buku yang ditampilkan di bawah penulis, misalnya untuk daftar
  /// katalog admin.
  final String? isbn;

  /// Label kategori atau genre, misalnya "Sastra Dunia".
  final String? category;

  /// Halaman yang sudah dibaca untuk bar progres.
  final int? currentPage;

  /// Total halaman buku untuk bar progres.
  final int? totalPages;

  /// Aksi tambahan di sisi kanan kartu, misalnya tombol hapus katalog admin.
  final Widget? trailing;

  /// Aksi saat kartu diketuk.
  final VoidCallback? onTap;

  bool get _hasProgress =>
      currentPage != null && totalPages != null && totalPages! > 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookCover(coverUrl: coverUrl),
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
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      author,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isbn != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.isbnLabel(isbn!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (category != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _CategoryChip(label: category!),
                    ],
                    if (_hasProgress) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _ProgressBar(
                        currentPage: currentPage!,
                        totalPages: totalPages!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sampul buku dengan rasio 2:3 dan bayangan dari token tema.
class _BookCover extends StatelessWidget {
  const _BookCover({this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasCover = coverUrl != null && coverUrl!.isNotEmpty;

    return Container(
      width: 80,
      height: 112,
      decoration: const BoxDecoration(
        borderRadius: AppRadius.allSmall,
        boxShadow: AppShadows.cover,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.allSmall,
        child: hasCover
            ? CachedNetworkImage(
                imageUrl: coverUrl!,
                fit: BoxFit.cover,
                placeholder: (BuildContext context, String url) =>
                    _CoverPlaceholder(scheme: scheme),
                errorWidget: (BuildContext context, String url, Object error) =>
                    _CoverPlaceholder(scheme: scheme),
              )
            : _CoverPlaceholder(scheme: scheme),
      ),
    );
  }
}

/// Sampul pengganti saat buku belum punya gambar.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        size: 28,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// Pil kategori kecil di bawah penulis.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

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

/// Bar progres halaman yang sedang dibaca.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double ratio = (currentPage / totalPages).clamp(0.0, 1.0);
    final int percent = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.percentDone(percent),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.secondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppStrings.pagesRead(currentPage, totalPages),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
    );
  }
}
