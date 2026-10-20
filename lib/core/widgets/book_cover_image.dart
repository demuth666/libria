import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/cloudinary_url.dart';

/// Ukuran gambar Cloudinary yang diminta aplikasi.
///
/// Hanya ada dua ukuran: [list] untuk daftar, grid, dan pratinjau kecil, serta
/// [detail] untuk halaman detail buku.
enum BookCoverWidth {
  list(400),
  detail(800);

  const BookCoverWidth(this.pixels);

  final int pixels;
}

/// Sampul buku bersama untuk seluruh layar.
///
/// [previewBytes] dipakai mendahului [coverUrl] saat admin memilih gambar baru
/// yang belum diunggah. Bila keduanya kosong atau gambar gagal dimuat, widget
/// menampilkan pengganti ikon buku. [CachedNetworkImage] menyimpan gambar yang
/// sudah pernah dimuat sehingga sampul tetap tampil saat offline.
class BookCoverImage extends StatelessWidget {
  const BookCoverImage({
    this.coverUrl,
    this.previewBytes,
    this.width = 80,
    this.height = 112,
    this.requestWidth = BookCoverWidth.list,
    this.borderRadius = AppRadius.allSmall,
    this.showShadow = true,
    this.placeholderLabel,
    super.key,
  });

  /// URL sampul tersimpan, berasal dari Cloudinary atau URL manual lama.
  final String? coverUrl;

  /// Pratinjau gambar lokal yang belum diunggah.
  final Uint8List? previewBytes;

  /// Lebar tampilan sampul.
  final double width;

  /// Tinggi tampilan sampul.
  final double height;

  /// Ukuran transformasi yang diminta dari Cloudinary.
  final BookCoverWidth requestWidth;

  /// Radius sudut sampul.
  final BorderRadius borderRadius;

  /// Menampilkan bayangan sampul.
  final bool showShadow;

  /// Label opsional pada pengganti sampul, misalnya di formulir admin.
  final String? placeholderLabel;

  bool get _hasCover => coverUrl != null && coverUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget placeholder = _CoverPlaceholder(
      scheme: scheme,
      label: placeholderLabel,
    );

    final Widget content;
    if (previewBytes != null) {
      content = Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) => placeholder,
      );
    } else if (_hasCover) {
      content = CachedNetworkImage(
        imageUrl: coverUrlSized(coverUrl!, width: requestWidth.pixels),
        fit: BoxFit.cover,
        placeholder: (BuildContext context, String url) => placeholder,
        errorWidget: (BuildContext context, String url, Object error) =>
            placeholder,
      );
    } else {
      content = placeholder;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: borderRadius,
        boxShadow: showShadow ? AppShadows.cover : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );
  }
}

/// Sampul pengganti saat buku belum punya gambar atau gambar gagal dimuat.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.scheme, this.label});

  final ColorScheme scheme;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 28,
            color: scheme.onSurfaceVariant,
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                label!,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
