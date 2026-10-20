import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import 'book_cover_image.dart';

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
              BookCoverImage(coverUrl: coverUrl),
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
