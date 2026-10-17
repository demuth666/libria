import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

/// Layar lupa kata sandi: mengirim tautan reset ke email pengguna (FR-A5).
///
/// Layar ini belum ada di Stitch dan mengikuti spesifikasi `docs/PRD.md`
/// bagian 7. Pesan hasil selalu sama, baik email terdaftar maupun tidak,
/// karena [AuthRepository.sendPasswordResetEmail] mengabaikan galat
/// `user-not-found`.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  String? _emailError;
  String? _feedbackMessage;
  String? _sentEmail;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    final String email = _emailController.text.trim();
    final String? emailError = _validateEmail(email);
    if (emailError != null) {
      setState(() {
        _emailError = emailError;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _feedbackMessage = null;
      _isLoading = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(email: email);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _sentEmail = email;
      });
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (_) {
      _showError(AppStrings.genericError);
    }
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return AppStrings.forgotPasswordEmailRequired;
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
      _isLoading = false;
      _feedbackMessage = message;
    });
  }

  void _backToLogin() {
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
                    const _ForgotPasswordHeader(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCard(theme, scheme),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : _backToLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.secondary,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: theme.textTheme.labelLarge,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text(AppStrings.forgotPasswordBackToLogin),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.level1,
      ),
      child: _sentEmail == null ? _buildForm(theme, scheme) : _buildSuccess(),
    );
  }

  Widget _buildForm(ThemeData theme, ColorScheme scheme) {
    return AutofillGroup(
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
            controller: _emailController,
            focusNode: _emailFocus,
            label: AppStrings.forgotPasswordEmailLabel,
            hint: AppStrings.forgotPasswordEmailHint,
            prefixIcon: Icons.mail_outline,
            errorText: _emailError,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            onChanged: (_) {
              if (_emailError != null || _feedbackMessage != null) {
                setState(() {
                  _emailError = null;
                  _feedbackMessage = null;
                });
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          AuthSubmitButton(
            label: AppStrings.forgotPasswordSubmit,
            loadingLabel: AppStrings.forgotPasswordSubmitting,
            isLoading: _isLoading,
            icon: Icons.send_outlined,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
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
          AppStrings.forgotPasswordSuccessTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.forgotPasswordSuccessMessage(_sentEmail!),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthSubmitButton(
          label: AppStrings.forgotPasswordBackToLogin,
          loadingLabel: AppStrings.forgotPasswordBackToLogin,
          isLoading: false,
          icon: Icons.login,
          onPressed: _backToLogin,
        ),
      ],
    );
  }
}

/// Kepala layar: ikon kunci, judul, dan penjelasan singkat.
class _ForgotPasswordHeader extends StatelessWidget {
  const _ForgotPasswordHeader();

  static const double _iconSize = 64;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: _iconSize,
          height: _iconSize,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: AppRadius.allLarge,
            boxShadow: AppShadows.level1,
          ),
          child: Icon(Icons.lock_reset, size: 30, color: scheme.onPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.forgotPasswordTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            AppStrings.forgotPasswordSubtitle,
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
