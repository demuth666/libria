import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_badge.dart';
import '../../../core/widgets/google_logo.dart';
import '../data/app_user.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import 'widgets/auth_screen_layout.dart';

/// Layar masuk dengan email dan kata sandi atau akun Google (FR-A1, FR-A4).
///
/// Tampilan mengikuti desain Stitch "Libria - Masuk Akun"
/// (`docs/design/stitch/masuk-akun.*`). Setelah masuk berhasil, dokumen
/// `users/{uid}` dipastikan ada, lalu pengguna diarahkan ke `/admin` atau
/// `/home` sesuai role. Penolakan akun yang emailnya belum terverifikasi
/// mengikuti FR-A4: pengguna keluar otomatis dan diberi tombol kirim ulang.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginActivity { email, google, resend }

enum _FeedbackTone { error, success }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  String? _emailError;
  String? _passwordError;
  String? _feedbackMessage;
  _FeedbackTone? _feedbackTone;
  _LoginActivity? _activity;
  bool _canResendVerification = false;
  String? _pendingVerificationEmail;
  String? _pendingVerificationPassword;

  bool get _isBusy => _activity != null;
  bool get _isEmailLoading => _activity == _LoginActivity.email;
  bool get _isGoogleLoading => _activity == _LoginActivity.google;
  bool get _isResendLoading => _activity == _LoginActivity.resend;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (_isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String? emailError = _validateEmail(email);
    final String? passwordError = password.isEmpty
        ? AppStrings.loginPasswordRequired
        : null;

    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _passwordError = null;
      _activity = _LoginActivity.email;
      _resetFeedback();
    });

    final AuthRepository authRepository = ref.read(authRepositoryProvider);
    try {
      final UserCredential credential = await authRepository.signInWithEmail(
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure(AppStrings.genericError);
      }

      await user.reload();
      final bool emailVerified =
          authRepository.currentUser?.emailVerified ?? user.emailVerified;
      if (!emailVerified) {
        await _rejectUnverifiedEmail(
          authRepository: authRepository,
          email: email,
          password: password,
        );
        return;
      }

      await _finishSignIn(user);
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (_) {
      _showError(AppStrings.genericError);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _activity = _LoginActivity.google;
      _emailError = null;
      _passwordError = null;
      _resetFeedback();
    });

    final AuthRepository authRepository = ref.read(authRepositoryProvider);
    try {
      final UserCredential credential = await authRepository.signInWithGoogle();
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure(AppStrings.genericError);
      }
      // Akun Google dianggap sudah terverifikasi (FR-A4), jadi tidak ada
      // pemeriksaan emailVerified pada alur ini.
      await _finishSignIn(user);
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (_) {
      _showError(AppStrings.genericError);
    }
  }

  /// Menolak akun email yang belum terverifikasi dan menyiapkan kirim ulang.
  ///
  /// Email verifikasi dikirim sekali sebelum sesi ditutup. Kredensial hanya
  /// disimpan di memori layar agar tombol kirim ulang dapat masuk sebentar,
  /// mengirim ulang email, lalu keluar lagi tanpa meminta kata sandi ulang.
  Future<void> _rejectUnverifiedEmail({
    required AuthRepository authRepository,
    required String email,
    required String password,
  }) async {
    try {
      await authRepository.sendEmailVerification();
    } catch (_) {
      // Tombol kirim ulang tetap tersedia bila pengiriman pertama gagal.
    }
    await authRepository.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _activity = null;
      _feedbackTone = _FeedbackTone.error;
      _feedbackMessage = AppStrings.loginEmailNotVerified;
      _canResendVerification = true;
      _pendingVerificationEmail = email;
      _pendingVerificationPassword = password;
    });
  }

  Future<void> _resendVerification() async {
    if (_isBusy) {
      return;
    }

    final String? email = _pendingVerificationEmail;
    final String? password = _pendingVerificationPassword;
    if (email == null || password == null) {
      return;
    }

    setState(() {
      _activity = _LoginActivity.resend;
      _feedbackMessage = null;
      _feedbackTone = null;
    });

    final AuthRepository authRepository = ref.read(authRepositoryProvider);
    try {
      await authRepository.signInWithEmail(email: email, password: password);
      await authRepository.sendEmailVerification();
      await authRepository.signOut();
      if (!mounted) {
        return;
      }
      setState(() {
        _activity = null;
        _feedbackTone = _FeedbackTone.success;
        _feedbackMessage = AppStrings.loginVerificationResent(email);
        _canResendVerification = true;
        _pendingVerificationEmail = email;
        _pendingVerificationPassword = password;
      });
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (_) {
      _showError(AppStrings.genericError);
    }
  }

  Future<void> _finishSignIn(User user) async {
    final UserRepository userRepository = ref.read(userRepositoryProvider);
    final AppUser? appUser;
    try {
      await userRepository.ensureUserDocument(user);
      appUser = await userRepository.watchUser(user.uid).first;
    } catch (_) {
      await _signOutQuietly();
      throw const AuthFailure(AppStrings.loginProfileSetupError);
    }

    if (!mounted) {
      return;
    }
    context.go(appUser?.isAdmin ?? false ? AppRoutes.admin : AppRoutes.home);
  }

  Future<void> _signOutQuietly() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Pesan utama tetap pesan penyiapan akun; keluar dicoba tanpa blokir.
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _activity = null;
      _feedbackTone = _FeedbackTone.error;
      _feedbackMessage = message;
    });
  }

  void _resetFeedback() {
    _feedbackMessage = null;
    _feedbackTone = null;
    _canResendVerification = false;
    _pendingVerificationEmail = null;
    _pendingVerificationPassword = null;
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return AppStrings.loginEmailRequired;
    }
    if (!AppValidators.isValidEmail(email)) {
      return AppStrings.authErrorInvalidEmail;
    }
    return null;
  }

  void _openForgotPassword() {
    context.push(AppRoutes.forgotPassword);
  }

  void _openRegister() {
    context.push(AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return AuthScreenLayout(
      hero: const _LoginHeader(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormCard(theme, scheme),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          _LoginFooter(onRegister: _openRegister),
        ],
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.level1,
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_feedbackMessage != null) ...[
              _FeedbackBanner(
                message: _feedbackMessage!,
                tone: _feedbackTone ?? _FeedbackTone.error,
              ),
              if (_canResendVerification) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ResendButton(
                    isLoading: _isResendLoading,
                    onPressed: _isBusy ? null : _resendVerification,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
            _AuthTextField(
              controller: _emailController,
              label: AppStrings.loginEmailLabel,
              hint: AppStrings.loginEmailHint,
              prefixIcon: Icons.mail_outline,
              errorText: _emailError,
              enabled: !_isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.md),
            _AuthTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: AppStrings.loginPasswordLabel,
              hint: AppStrings.loginPasswordHint,
              prefixIcon: Icons.lock_outline,
              errorText: _passwordError,
              enabled: !_isBusy,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _submitEmail(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isBusy ? null : _openForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.secondary,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelMedium,
                ),
                child: const Text(AppStrings.loginForgotPassword),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SubmitButton(
              isLoading: _isEmailLoading,
              onPressed: _isEmailLoading
                  ? () {}
                  : (_isBusy ? null : _submitEmail),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            const _LoginDivider(),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _GoogleButton(
              isLoading: _isGoogleLoading,
              onPressed: _isGoogleLoading
                  ? () {}
                  : (_isBusy ? null : _signInWithGoogle),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bagian atas: ikon aplikasi, judul, dan kalimat pengantar.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      children: [
        const BrandBadge(size: 64, radius: AppRadius.large),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Text(
          AppStrings.loginWelcomeTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            AppStrings.loginSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kolom teks autentikasi dengan label di atas kolom dan ikon di depan.
class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.focusNode,
    this.hint,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  late bool _obscured = widget.obscureText;

  void _toggleVisibility() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
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
            errorMaxLines: 2,
            errorStyle: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tombol utama "Masuk ke Akun" dengan indikator loading.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
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
                  const Flexible(child: Text(AppStrings.loginSubmitting)),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(AppStrings.loginSubmit)),
                  SizedBox(width: AppSpacing.sm),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
      ),
    );
  }
}

/// Tombol masuk dengan Google berlatar `surfaceContainerLow`.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
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
                  const Flexible(child: Text(AppStrings.loginGoogleLoading)),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoogleLogo(size: 16),
                  SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Flexible(child: Text(AppStrings.loginGoogle)),
                ],
              ),
      ),
    );
  }
}

/// Garis pemisah dengan label "ATAU MASUK DENGAN" di tengah.
class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

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
            AppStrings.loginOr,
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

/// Pesan galat atau hasil kirim ulang di dalam kartu formulir.
class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.tone});

  final String message;
  final _FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isError = tone == _FeedbackTone.error;
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

/// Tautan kirim ulang email verifikasi di bawah pesan penolakan.
class _ResendButton extends StatelessWidget {
  const _ResendButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: scheme.secondary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: theme.textTheme.labelMedium,
      ),
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.secondary,
              ),
            )
          : const Icon(Icons.forward_to_inbox_outlined, size: 18),
      label: const Text(AppStrings.loginResendVerification),
    );
  }
}

/// Tautan ke pendaftaran akun baru di bawah kartu.
class _LoginFooter extends StatelessWidget {
  const _LoginFooter({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          AppStrings.loginNoAccount,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: onRegister,
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: theme.textTheme.labelLarge,
          ),
          child: Text(
            AppStrings.loginRegisterNow,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: scheme.secondaryContainer,
              decorationThickness: 2,
            ),
          ),
        ),
      ],
    );
  }
}
