import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/app_user.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import 'widgets/auth_widgets.dart';

/// Layar pendaftaran akun baru dengan email dan kata sandi atau akun Google
/// (FR-A2, FR-A3, FR-A4).
///
/// Tampilan mengikuti desain Stitch "Libria - Daftar Akun Baru"
/// (`docs/design/stitch/daftar-akun.*`). Pendaftaran email mengirim email
/// verifikasi, membuat dokumen `users/{uid}` dengan role user, lalu keluar
/// otomatis agar pengguna memverifikasi email sebelum masuk.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

enum _RegisterActivity { email, google }

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _agreementError;
  String? _feedbackMessage;
  _RegisterActivity? _activity;
  bool _agreedToTerms = false;
  String? _registeredEmail;

  bool get _isBusy => _activity != null;
  bool get _isEmailLoading => _activity == _RegisterActivity.email;
  bool get _isGoogleLoading => _activity == _RegisterActivity.google;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (_isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();
    final String fullName = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String confirmation = _confirmController.text;

    final String? nameError = fullName.isEmpty
        ? AppStrings.registerFullNameRequired
        : null;
    final String? emailError = _validateEmail(email);
    final String? passwordError = password.isEmpty
        ? AppStrings.registerPasswordRequired
        : (!AppValidators.isValidPassword(password)
              ? AppStrings.registerPasswordTooShort
              : null);
    final String? confirmError = confirmation.isEmpty
        ? AppStrings.registerConfirmPasswordRequired
        : (confirmation != password
              ? AppStrings.registerPasswordMismatch
              : null);
    final String? agreementError = _agreedToTerms
        ? null
        : AppStrings.registerAgreementRequired;

    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmError != null ||
        agreementError != null) {
      setState(() {
        _nameError = nameError;
        _emailError = emailError;
        _passwordError = passwordError;
        _confirmError = confirmError;
        _agreementError = agreementError;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _agreementError = null;
      _feedbackMessage = null;
      _activity = _RegisterActivity.email;
    });

    final AuthRepository authRepository = ref.read(authRepositoryProvider);
    try {
      final UserCredential credential = await authRepository.registerWithEmail(
        fullName: fullName,
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure(AppStrings.genericError);
      }

      try {
        await ref.read(userRepositoryProvider).ensureUserDocument(user);
      } catch (_) {
        await _signOutQuietly();
        throw const AuthFailure(AppStrings.registerProfileSetupError);
      }

      // Email harus diverifikasi sebelum masuk (FR-A4), jadi sesi yang baru
      // dibuat ditutup dan pengguna diarahkan memeriksa kotak masuk.
      await _signOutQuietly();
      if (!mounted) {
        return;
      }
      setState(() {
        _activity = null;
        _registeredEmail = email;
        _passwordController.clear();
        _confirmController.clear();
        _agreedToTerms = false;
      });
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (_) {
      _showError(AppStrings.genericError);
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (_isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _activity = _RegisterActivity.google;
      _feedbackMessage = null;
    });

    final AuthRepository authRepository = ref.read(authRepositoryProvider);
    try {
      final UserCredential credential = await authRepository.signInWithGoogle();
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure(AppStrings.genericError);
      }

      final AppUser? appUser;
      try {
        final UserRepository userRepository = ref.read(userRepositoryProvider);
        await userRepository.ensureUserDocument(user);
        appUser = await userRepository.watchUser(user.uid).first;
      } catch (_) {
        await _signOutQuietly();
        throw const AuthFailure(AppStrings.registerProfileSetupError);
      }

      if (!mounted) {
        return;
      }
      context.go(appUser?.isAdmin ?? false ? AppRoutes.admin : AppRoutes.home);
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (_) {
      _showError(AppStrings.genericError);
    }
  }

  Future<void> _signOutQuietly() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Pesan utama tetap pesan penyiapan akun; keluar dicoba tanpa blokir.
    }
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return AppStrings.registerEmailRequired;
    }
    if (!AppValidators.isValidEmail(email)) {
      return AppStrings.authErrorInvalidEmail;
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _activity = null;
      _feedbackMessage = message;
    });
  }

  void _openLogin() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.surfaceBright,
              scheme.surfaceContainerLow,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.lg,
              AppSpacing.screenMargin,
              AppSpacing.screenMargin,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _RegisterHero(),
                    const SizedBox(height: AppSpacing.md),
                    if (_registeredEmail != null)
                      _RegisterSuccessCard(
                        email: _registeredEmail!,
                        onBackToLogin: _openLogin,
                      )
                    else ...[
                      _buildFormCard(theme, scheme),
                      const SizedBox(height: AppSpacing.lg),
                      _RegisterFooter(enabled: !_isBusy, onSignIn: _openLogin),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              AuthFeedbackBanner(
                message: _feedbackMessage!,
                tone: AuthFeedbackTone.error,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AuthTextField(
              controller: _nameController,
              label: AppStrings.registerFullNameLabel,
              hint: AppStrings.registerFullNameHint,
              helperText: AppStrings.registerFullNameHelper,
              prefixIcon: Icons.person_outline,
              errorText: _nameError,
              enabled: !_isBusy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: AppStrings.registerEmailLabel,
              hint: AppStrings.registerEmailHint,
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
            AuthTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: AppStrings.registerPasswordLabel,
              hint: AppStrings.registerPasswordHint,
              helperText: AppStrings.registerPasswordHelper,
              helperTone: AuthHintTone.accent,
              prefixIcon: Icons.lock_outline,
              errorText: _passwordError,
              enabled: !_isBusy,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _confirmFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              controller: _confirmController,
              focusNode: _confirmFocus,
              label: AppStrings.registerConfirmPasswordLabel,
              hint: AppStrings.registerConfirmPasswordHint,
              prefixIcon: Icons.verified_user_outlined,
              errorText: _confirmError,
              enabled: !_isBusy,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
              onSubmitted: (_) => _submitRegistration(),
            ),
            const SizedBox(height: AppSpacing.md),
            _AgreementRow(
              value: _agreedToTerms,
              enabled: !_isBusy,
              errorText: _agreementError,
              onChanged: (bool value) {
                setState(() {
                  _agreedToTerms = value;
                  if (value) {
                    _agreementError = null;
                  }
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AuthSubmitButton(
              label: AppStrings.registerSubmit,
              loadingLabel: AppStrings.registerSubmitting,
              isLoading: _isEmailLoading,
              icon: Icons.arrow_forward,
              onPressed: _isBusy ? null : _submitRegistration,
            ),
            const SizedBox(height: AppSpacing.md),
            const AuthDivider(label: AppStrings.registerOr),
            const SizedBox(height: AppSpacing.md),
            AuthGoogleButton(
              label: AppStrings.registerGoogle,
              loadingLabel: AppStrings.registerGoogleLoading,
              isLoading: _isGoogleLoading,
              onPressed: _isBusy ? null : _signUpWithGoogle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel hero bergradien dengan monogram, judul, dan pil statistik komunitas.
class _RegisterHero extends StatelessWidget {
  const _RegisterHero();

  static const double _badgeSize = 56;
  static const double _decorSize = 144;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.allLarge,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.1),
            scheme.surfaceContainer,
            scheme.surfaceContainerLow,
          ],
        ),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -AppSpacing.xl,
            right: -AppSpacing.xl,
            child: _BlurredCircle(
              size: _decorSize,
              color: scheme.secondaryContainer.withValues(alpha: 0.3),
              blurSigma: 24,
            ),
          ),
          Positioned(
            bottom: -AppSpacing.lg,
            left: -AppSpacing.lg,
            child: _BlurredCircle(
              size: _decorSize - AppSpacing.md,
              color: scheme.primaryFixed.withValues(alpha: 0.4),
              blurSigma: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Container(
                  width: _badgeSize,
                  height: _badgeSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: AppRadius.allLarge,
                    boxShadow: AppShadows.level1,
                  ),
                  child: Text(
                    AppStrings.brandMonogram,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.registerHeroTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    AppStrings.registerHeroSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md - AppSpacing.xs,
                    vertical: AppSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: AppRadius.allFull,
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: 16,
                        color: scheme.secondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          AppStrings.registerCommunityStat,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.secondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
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

class _BlurredCircle extends StatelessWidget {
  const _BlurredCircle({
    required this.size,
    required this.color,
    required this.blurSigma,
  });

  final double size;
  final Color color;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Baris persetujuan Syarat & Ketentuan dengan kesalahan validasi di bawahnya.
class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle bodyStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final TextStyle linkStyle = theme.textTheme.labelSmall!.copyWith(
      color: scheme.secondary,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: enabled
                    ? (bool? next) => onChanged(next ?? false)
                    : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                checkColor: scheme.onSecondary,
                fillColor: WidgetStateProperty.resolveWith((
                  Set<WidgetState> states,
                ) {
                  return states.contains(WidgetState.selected)
                      ? scheme.secondary
                      : Colors.transparent;
                }),
                side: BorderSide(color: scheme.outlineVariant, width: 1.5),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.extraSmall),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? () => onChanged(!value) : null,
                child: Text.rich(
                  TextSpan(
                    style: bodyStyle,
                    children: [
                      const TextSpan(text: AppStrings.registerAgreementPrefix),
                      TextSpan(
                        text: AppStrings.registerAgreementTerms,
                        style: linkStyle,
                      ),
                      const TextSpan(
                        text: AppStrings.registerAgreementConjunction,
                      ),
                      TextSpan(
                        text: AppStrings.registerAgreementPrivacy,
                        style: linkStyle,
                      ),
                      const TextSpan(text: AppStrings.registerAgreementSuffix),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

/// Kartu hasil pendaftaran email: minta pengguna memverifikasi email dulu.
class _RegisterSuccessCard extends StatelessWidget {
  const _RegisterSuccessCard({
    required this.email,
    required this.onBackToLogin,
  });

  final String email;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: AppRadius.allLarge,
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 28,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.registerSuccessTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.registerSuccessMessage(email),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthSubmitButton(
            label: AppStrings.registerBackToLogin,
            loadingLabel: AppStrings.registerBackToLogin,
            isLoading: false,
            icon: Icons.login,
            onPressed: onBackToLogin,
          ),
        ],
      ),
    );
  }
}

/// Tautan ke layar masuk di bawah kartu formulir.
class _RegisterFooter extends StatelessWidget {
  const _RegisterFooter({required this.enabled, required this.onSignIn});

  final bool enabled;
  final VoidCallback onSignIn;

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
          AppStrings.registerHaveAccount,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: enabled ? onSignIn : null,
          style: TextButton.styleFrom(
            foregroundColor: scheme.secondary,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: theme.textTheme.labelLarge,
          ),
          child: Text(
            AppStrings.registerSignIn,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
