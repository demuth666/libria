import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/google_logo.dart';

/// Warna teks petunjuk di sisi label kolom autentikasi.
enum AuthHintTone {
  /// Petunjuk biasa, misalnya "Wajib diisi".
  neutral,

  /// Petunjuk yang menonjol, misalnya "Minimal 8 karakter".
  accent,
}

/// Jenis pesan umpan balik di dalam kartu formulir autentikasi.
enum AuthFeedbackTone {
  /// Kegagalan yang membuat pengguna tetap di layar.
  error,

  /// Hasil yang berhasil, misalnya email verifikasi terkirim.
  success,
}

/// Kolom teks autentikasi dengan label di atas, ikon di depan, dan tombol
/// lihat sandi untuk kolom kata sandi.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.focusNode,
    this.hint,
    this.helperText,
    this.helperTone = AuthHintTone.neutral,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final String? helperText;
  final AuthHintTone helperTone;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  void _toggleVisibility() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasHelper = widget.helperText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (hasHelper) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.helperText!,
                style: widget.helperTone == AuthHintTone.accent
                    ? theme.textTheme.labelSmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w500,
                      )
                    : theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofillHints: widget.autofillHints,
          autocorrect: !widget.obscureText,
          enableSuggestions: !widget.obscureText,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.outline,
            ),
            filled: true,
            fillColor: scheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: widget.enabled ? _toggleVisibility : null,
                    tooltip: _obscured
                        ? AppStrings.showPassword
                        : AppStrings.hidePassword,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : null,
            border: const OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide.none,
            ),
            disabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(color: scheme.secondary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(color: scheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(color: scheme.error, width: 1.5),
            ),
            errorText: widget.errorText,
            errorMaxLines: 3,
            errorStyle: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pesan galat atau hasil di dalam kartu formulir autentikasi.
class AuthFeedbackBanner extends StatelessWidget {
  const AuthFeedbackBanner({
    required this.message,
    required this.tone,
    super.key,
  });

  final String message;
  final AuthFeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isError = tone == AuthFeedbackTone.error;
    final Color background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final Color foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.mark_email_read_outlined,
              size: 20,
              color: foreground,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Garis pemisah dengan label di tengah, misalnya "ATAU DAFTAR DENGAN".
class AuthDivider extends StatelessWidget {
  const AuthDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Widget line = Expanded(
      child: Container(height: 1, color: scheme.surfaceContainerHigh),
    );

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Tombol utama autentikasi dengan indikator loading dan ikon opsional di
/// belakang label.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? () {} : onPressed,
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(loadingLabel, textAlign: TextAlign.center),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                  if (icon != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(icon, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Tombol autentikasi dengan Google berlatar `surfaceContainerLow`.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? () {} : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLow,
          foregroundColor: scheme.onSurface,
          disabledBackgroundColor: scheme.surfaceContainerLow,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.7),
          side: BorderSide.none,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.allMedium,
          ),
          textStyle: theme.textTheme.labelLarge,
        ),
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(loadingLabel, textAlign: TextAlign.center),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoogleLogo(size: 20),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}
