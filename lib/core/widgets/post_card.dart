import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Kartu postingan dasar untuk feed komunitas.
///
/// Menampilkan penulis, waktu, isi postingan, penautan buku opsional, serta
/// jumlah tanggapan dan like. Hanya menampilkan data; aksi ditangani pemanggil
/// lewat [onTap].
class PostCard extends StatelessWidget {
  const PostCard({
    required this.authorName,
    required this.timeLabel,
    required this.content,
    this.authorPhotoUrl,
    this.bookTitle,
    this.replyCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.onTap,
    super.key,
  });

  /// Nama penulis postingan.
  final String authorName;

  /// Waktu postingan yang sudah diformat, misalnya "2 jam lalu".
  final String timeLabel;

  /// Isi postingan.
  final String content;

  /// URL foto penulis; bila kosong dipakai avatar huruf awal.
  final String? authorPhotoUrl;

  /// Judul buku yang ditautkan, bila ada.
  final String? bookTitle;

  /// Jumlah tanggapan.
  final int replyCount;

  /// Jumlah like.
  final int likeCount;

  /// Menampilkan ikon like terisi.
  final bool isLiked;

  /// Aksi saat kartu diketuk.
  final VoidCallback? onTap;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AuthorAvatar(name: authorName, photoUrl: authorPhotoUrl),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (bookTitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _BookReference(title: bookTitle!),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _StatItem(
                    icon: Icons.chat_bubble_outline,
                    label: AppStrings.replyCountLabel(replyCount),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _StatItem(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '$likeCount',
                    color: isLiked ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar bulat penulis dengan foto atau huruf awal nama.
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  String get _initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    final String first = parts.first.substring(0, 1);
    final String second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              width: 36,
              height: 36,
              placeholder: (BuildContext context, String url) =>
                  _initialsText(theme, scheme),
              errorWidget: (BuildContext context, String url, Object error) =>
                  _initialsText(theme, scheme),
            )
          : _initialsText(theme, scheme),
    );
  }

  Widget _initialsText(ThemeData theme, ColorScheme scheme) {
    if (_initials.isEmpty) {
      return Icon(Icons.person, size: 18, color: scheme.onPrimary);
    }
    return Text(
      _initials,
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Baris ringkas penautan buku pada postingan.
class _BookReference extends StatelessWidget {
  const _BookReference({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allSmall,
      ),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu butir statistik (ikon dan angka) di bawah postingan.
class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color resolved = color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: resolved),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: resolved),
        ),
      ],
    );
  }
}
