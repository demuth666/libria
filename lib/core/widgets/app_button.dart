import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tombol utama aplikasi (isian `primary`) di atas gaya `FilledButton` tema.
///
/// Saat [isLoading] benar, ikon digantikan indikator loading dan tombol
/// menahan aksinya sambil tetap terlihat aktif.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  /// Teks tombol; ambil dari `AppStrings`.
  final String label;

  /// Aksi saat tombol ditekan; `null` membuat tombol nonaktif.
  final VoidCallback? onPressed;

  /// Ikon opsional di depan label.
  final IconData? icon;

  /// Menampilkan indikator loading dan menahan aksi sementara.
  final bool isLoading;

  /// Memenuhi lebar induk (dipakai pada kolom).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      child: FilledButton(
        onPressed: onPressed == null ? null : (isLoading ? () {} : onPressed),
        child: _ButtonContent(
          label: label,
          icon: icon,
          isLoading: isLoading,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// Tombol sekunder aplikasi (bergaris `primary`) di atas gaya
/// `OutlinedButton` tema.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  /// Teks tombol; ambil dari `AppStrings`.
  final String label;

  /// Aksi saat tombol ditekan; `null` membuat tombol nonaktif.
  final VoidCallback? onPressed;

  /// Ikon opsional di depan label.
  final IconData? icon;

  /// Menampilkan indikator loading dan menahan aksi sementara.
  final bool isLoading;

  /// Memenuhi lebar induk (dipakai pada kolom).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed == null ? null : (isLoading ? () {} : onPressed),
        child: _ButtonContent(
          label: label,
          icon: icon,
          isLoading: isLoading,
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Isi tombol yang seragam: ikon atau indikator loading di depan label.
class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.indicatorColor,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color indicatorColor;

  @override
  Widget build(BuildContext context) {
    final bool showSpinner = isLoading;
    final bool showIcon = !isLoading && icon != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showSpinner)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: indicatorColor,
            ),
          )
        else if (showIcon)
          Icon(icon, size: 18),
        if (showSpinner || showIcon) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
