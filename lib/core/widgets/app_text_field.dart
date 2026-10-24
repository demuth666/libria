import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

/// Kolom teks aplikasi di atas gaya `InputDecoration` tema.
///
/// Bila [obscureText] benar, kolom menyediakan tombol lihat atau sembunyikan
/// kata sandi di sisi kanan.
class AppTextField extends StatefulWidget {
  const AppTextField({
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    super.key,
  });

  /// Pengendali teks milik pemanggil.
  final TextEditingController? controller;

  /// Fokus kolom milik pemanggil, misalnya untuk mengembalikan fokus setelah
  /// pencarian dihapus.
  final FocusNode? focusNode;

  /// Label melayang di atas kolom.
  final String? label;

  /// Contoh isian saat kolom kosong.
  final String? hint;

  /// Ikon di depan kolom.
  final IconData? prefixIcon;

  /// Pesan kesalahan; kolom menampilkan garis dan teks error bila terisi.
  final String? errorText;

  /// Jenis papan ketik yang muncul.
  final TextInputType? keyboardType;

  /// Aksi tombol enter pada papan ketik.
  final TextInputAction? textInputAction;

  /// Menyembunyikan teks dan menampilkan tombol lihat sandi.
  final bool obscureText;

  /// Meminta fokus otomatis saat kolom pertama kali ditampilkan.
  final bool autofocus;

  /// Jumlah baris; dipaksa satu baris saat [obscureText] benar.
  final int maxLines;

  /// Batas jumlah karakter isian; `null` berarti tanpa batas.
  ///
  /// Bila diisi, kolom menampilkan penghitung karakter dan membatasi isian
  /// sesuai perilaku `TextField.maxLength`.
  final int? maxLength;

  /// Mengaktifkan atau menonaktifkan kolom.
  final bool enabled;

  /// Dipanggil setiap isian berubah.
  final ValueChanged<String>? onChanged;

  /// Dipanggil saat tombol submit pada papan ketik ditekan.
  final ValueChanged<String>? onSubmitted;

  /// Ikon aksi di sisi kanan kolom, misalnya tombol hapus pencarian.
  ///
  /// Diabaikan bila [obscureText] benar karena sisi kanan dipakai tombol
  /// lihat atau sembunyikan kata sandi.
  final Widget? suffixIcon;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  void _toggleVisibility() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _obscured,
      autofocus: widget.autofocus,
      maxLines: _obscured ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: widget.obscureText
            ? IconButton(
                onPressed: _toggleVisibility,
                tooltip: _obscured
                    ? AppStrings.showPassword
                    : AppStrings.hidePassword,
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : widget.suffixIcon,
        errorText: widget.errorText,
        errorMaxLines: 3,
      ),
    );
  }
}
