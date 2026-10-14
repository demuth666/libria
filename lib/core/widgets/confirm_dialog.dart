import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

/// Menampilkan dialog konfirmasi dan menunggu pilihan pengguna.
///
/// Mengembalikan `true` bila tombol konfirmasi ditekan dan `false` bila
/// dibatalkan atau dialog ditutup. Isi [confirmLabel] dengan kata kerja yang
/// jelas, misalnya "Hapus" atau "Keluar".
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = AppStrings.cancel,
  bool isDestructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
