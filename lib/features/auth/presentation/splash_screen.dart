import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../data/app_user.dart';
import 'auth_providers.dart';

/// Layar pembuka yang memeriksa status masuk dan role pengguna, lalu
/// mengarahkan ke `/login`, `/home`, atau `/admin` (PRD bagian 7).
///
/// Progres pada layar ini mengikuti hasil pemeriksaan tersebut, bukan timer
/// hiasan seperti pada HTML Stitch. Selama status belum diketahui, layar tetap
/// tampil; bila pemeriksaan gagal, pengguna diberi pesan dan tombol coba lagi.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasScheduledNavigation = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<User?> authState = ref.watch(authStateProvider);
    final AsyncValue<AppUser?> currentUser = ref.watch(currentUserProvider);
    final _SplashViewState viewState = _resolveViewState(
      authState,
      currentUser,
    );

    if (viewState.hasError) {
      return _buildErrorState(context);
    }

    if (viewState.destination != null) {
      _scheduleNavigation(viewState.destination!);
    }

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _SplashBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.lg,
              AppSpacing.screenMargin,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: const Center(child: _BrandPanel()),
                            ),
                          );
                        },
                  ),
                ),
                _BottomStage(
                  progress: viewState.progress,
                  status: viewState.status,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _SplashBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                const _BrandPanel(),
                const SizedBox(height: AppSpacing.xl),
                ErrorView(message: AppStrings.splashError, onRetry: _retry),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retry() {
    ref.invalidate(authStateProvider);
    ref.invalidate(currentUserProvider);
  }

  void _scheduleNavigation(String destination) {
    if (_hasScheduledNavigation) {
      return;
    }
    _hasScheduledNavigation = true;
    final GoRouter router = GoRouter.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Jangan menimpa navigasi yang sudah dilakukan pihak lain (misalnya
      // redirect router pada T-015) saat callback ini baru berjalan.
      if (router.state.uri.path != AppRoutes.splash) {
        return;
      }
      router.go(destination);
    });
  }

  /// Menentukan tahap tampilan dan tujuan navigasi dari dua sumber status.
  ///
  /// `currentUserProvider` bisa masih memuat nilai lama (misalnya `null`
  /// sebelum pengguna masuk) saat diperbarui, jadi pemeriksaan `isLoading`
  /// dilakukan sebelum memakai nilainya agar admin tidak sempat diarahkan ke
  /// `/home`. Bila dokumen `users/{uid}` belum ada, pengguna dianggap user
  /// biasa; pembuatan dokumen adalah tugas alur pendaftaran atau login.
  _SplashViewState _resolveViewState(
    AsyncValue<User?> authState,
    AsyncValue<AppUser?> currentUser,
  ) {
    if (authState.isLoading) {
      return const _SplashViewState.preparing();
    }
    if (authState.hasError) {
      return const _SplashViewState.error();
    }

    final User? firebaseUser = authState.value;
    if (firebaseUser == null) {
      return const _SplashViewState.ready(AppRoutes.login);
    }

    if (currentUser.isLoading) {
      return const _SplashViewState.syncing();
    }
    if (currentUser.hasError) {
      return const _SplashViewState.error();
    }

    final bool isAdmin = currentUser.value?.isAdmin ?? false;
    return _SplashViewState.ready(isAdmin ? AppRoutes.admin : AppRoutes.home);
  }
}

/// Tahap pemeriksaan status yang dipetakan ke progres dan teks Stitch.
class _SplashViewState {
  const _SplashViewState._({
    required this.progress,
    required this.status,
    this.destination,
    this.hasError = false,
  });

  const _SplashViewState.preparing()
    : this._(progress: 0.65, status: AppStrings.splashStatusPreparing);

  const _SplashViewState.syncing()
    : this._(progress: 0.85, status: AppStrings.splashStatusSyncing);

  const _SplashViewState.ready(String destination)
    : this._(
        progress: 1,
        status: AppStrings.splashStatusReady,
        destination: destination,
      );

  const _SplashViewState.error()
    : this._(progress: 0, status: AppStrings.splashStatusReady, hasError: true);

  final double progress;
  final String status;
  final String? destination;
  final bool hasError;
}

/// Latar dekoratif: dua lingkaran cahaya dan motif halaman arsip samar.
class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          top: -48,
          right: -64,
          child: _AmbientCircle(
            size: 384,
            color: scheme.secondaryFixed.withValues(alpha: 0.2),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -48,
          child: _AmbientCircle(
            size: 320,
            color: scheme.primaryFixed.withValues(alpha: 0.25),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ArchiveWatermarkPainter(color: scheme.primary),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientCircle extends StatelessWidget {
  const _AmbientCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Bagian tengah: ikon aplikasi, nama, garis pemisah, dan tagline.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BrandBadge(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.appName,
          style: theme.textTheme.displaySmall?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.auto_stories, size: 14, color: scheme.secondary),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 32,
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Text(
            AppStrings.splashTagline,
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

/// Ikon aplikasi 96 px dengan cincin cahaya dan ilustrasi buku terbuka.
class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  static const double _badgeSize = 96;
  static const double _glowSize = 112;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: _glowSize,
      height: _glowSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: _glowSize,
              height: _glowSize,
              decoration: BoxDecoration(
                borderRadius: AppRadius.allExtraLarge,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.secondary.withValues(alpha: 0.3),
                    scheme.primaryContainer.withValues(alpha: 0.2),
                    scheme.secondaryContainer.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(
              borderRadius: AppRadius.allExtraLarge,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.primaryContainer],
              ),
              boxShadow: AppShadows.cover,
            ),
            child: CustomPaint(
              painter: _BookGlyphPainter(
                leftPage: scheme.surface,
                rightPage: scheme.surfaceContainerHighest,
                spine: scheme.primaryContainer,
                ribbon: scheme.secondaryFixed,
                ribbonOutline: scheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu kutipan dan progres di bagian bawah layar.
class _BottomStage extends StatelessWidget {
  const _BottomStage({required this.progress, required this.status});

  final double progress;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      children: [
        const _QuoteCard(),
        const SizedBox(height: AppSpacing.md),
        _SplashProgress(progress: progress, status: status),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 15, color: scheme.outline),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              AppStrings.splashFooter,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: AppSpacing.xs, color: scheme.secondary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 20,
                  color: scheme.secondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.splashQuote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.splashQuoteAttribution,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    letterSpacing: 0.4,
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

class _SplashProgress extends StatelessWidget {
  const _SplashProgress({required this.progress, required this.status});

  final double progress;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int percent = (progress * 100).round();

    return Column(
      children: [
        ClipRRect(
          borderRadius: AppRadius.allFull,
          child: SizedBox(
            height: 6,
            child: ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double value, Widget? child) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.allFull,
                          gradient: LinearGradient(
                            colors: [scheme.secondary, scheme.secondaryFixed],
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppStrings.splashProgressPercent(percent),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Motif garis halaman arsip pada latar, mengikuti SVG Stitch.
class _ArchiveWatermarkPainter extends CustomPainter {
  const _ArchiveWatermarkPainter({required this.color});

  final Color color;

  static const double _designWidth = 400;
  static const double _designHeight = 800;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    canvas.save();
    canvas.scale(size.width / _designWidth, size.height / _designHeight);

    final Paint linePaint = Paint()
      ..color = color.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final Path page = Path()
      ..moveTo(60, 120)
      ..cubicTo(140, 100, 260, 100, 340, 120)
      ..lineTo(340, 700)
      ..cubicTo(260, 680, 140, 680, 60, 700)
      ..close();
    canvas.drawPath(page, linePaint);

    const double dash = 6;
    const double gap = 4;
    for (double y = 110; y < 690; y += dash + gap) {
      final double end = y + dash > 690 ? 690 : y + dash;
      canvas.drawLine(Offset(200, y), Offset(200, end), linePaint);
    }

    for (int index = 0; index < 4; index++) {
      final double leftY = 160 + index * 30;
      final double rightY = 155 + index * 30;
      canvas.drawLine(Offset(80, leftY), Offset(180, leftY - 5), linePaint);
      canvas.drawLine(Offset(220, rightY), Offset(320, rightY + 5), linePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArchiveWatermarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Ilustrasi buku terbuka dengan pita penanda pada ikon aplikasi.
class _BookGlyphPainter extends CustomPainter {
  const _BookGlyphPainter({
    required this.leftPage,
    required this.rightPage,
    required this.spine,
    required this.ribbon,
    required this.ribbonOutline,
  });

  final Color leftPage;
  final Color rightPage;
  final Color spine;
  final Color ribbon;
  final Color ribbonOutline;

  static const double _designSize = 48;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    canvas.save();
    canvas.scale(size.width / _designSize, size.height / _designSize);

    final Paint leftPagePaint = Paint()
      ..color = leftPage.withValues(alpha: 0.95);
    final Path leftPagePath = Path()
      ..moveTo(7, 36.5)
      ..cubicTo(11.5, 34, 18, 34, 24, 37)
      ..lineTo(24, 11)
      ..cubicTo(18, 8, 11.5, 8, 7, 10.5)
      ..close();
    canvas.drawPath(leftPagePath, leftPagePaint);

    final Paint rightPagePaint = Paint()
      ..color = rightPage.withValues(alpha: 0.85);
    final Path rightPagePath = Path()
      ..moveTo(41, 36.5)
      ..cubicTo(36.5, 34, 30, 34, 24, 37)
      ..lineTo(24, 11)
      ..cubicTo(30, 8, 36.5, 8, 41, 10.5)
      ..close();
    canvas.drawPath(rightPagePath, rightPagePaint);

    final Paint spinePaint = Paint()
      ..color = spine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(24, 11), const Offset(24, 37), spinePaint);

    final Path ribbonPath = Path()
      ..moveTo(20, 9)
      ..lineTo(20, 23)
      ..lineTo(23.5, 20.5)
      ..lineTo(27, 23)
      ..lineTo(27, 9)
      ..close();
    canvas.drawPath(ribbonPath, Paint()..color = ribbon);

    final Paint ribbonOutlinePaint = Paint()
      ..color = ribbonOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(ribbonPath, ribbonOutlinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BookGlyphPainter oldDelegate) {
    return oldDelegate.leftPage != leftPage ||
        oldDelegate.rightPage != rightPage ||
        oldDelegate.spine != spine ||
        oldDelegate.ribbon != ribbon ||
        oldDelegate.ribbonOutline != ribbonOutline;
  }
}
