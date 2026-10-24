import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ikon aplikasi Libria: ubin bergradien dengan ilustrasi buku terbuka.
///
/// Bentuknya berasal dari layar Splash dan dipakai ulang di layar Masuk serta
/// Daftar agar branding tetap konsisten. Ukuran dapat diperkecil tanpa
/// mengubah proporsi ilustrasi karena seluruh jalur digambar relatif terhadap
/// sisi ubin.
class BrandBadge extends StatelessWidget {
  const BrandBadge({
    this.size = 96,
    this.radius = AppRadius.extraLarge,
    this.showGlow = true,
    super.key,
  });

  /// Sisi ubin ikon dalam piksel logis.
  final double size;

  /// Radius sudut ubin dan lingkaran cahaya di belakangnya.
  final double radius;

  /// Menampilkan lingkaran cahaya gradien di belakang ubin.
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double glowInset = AppSpacing.sm;
    final double outerSize = size + glowInset * 2;
    final BorderRadius borderRadius = BorderRadius.all(Radius.circular(radius));

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
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
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
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
