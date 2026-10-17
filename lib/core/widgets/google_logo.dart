import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo Google berwarna untuk tombol "Masuk dengan Google".
///
/// Digambar langsung agar aplikasi tidak bergantung pada aset raster atau
/// paket SVG tambahan. Bentuk mengikuti jalur logo Google resmi pada 24 x 24.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({this.size = 16, super.key});

  /// Sisi logo dalam piksel logis.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const double _designSize = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    canvas.save();
    canvas.scale(size.width / _designSize, size.height / _designSize);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    paint.color = GoogleBrandColors.blue;
    canvas.drawPath(_bluePath(), paint);
    paint.color = GoogleBrandColors.green;
    canvas.drawPath(_greenPath(), paint);
    paint.color = GoogleBrandColors.yellow;
    canvas.drawPath(_yellowPath(), paint);
    paint.color = GoogleBrandColors.red;
    canvas.drawPath(_redPath(), paint);

    canvas.restore();
  }

  Path _bluePath() {
    return Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10)
      ..lineTo(12, 10)
      ..lineTo(12, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
  }

  Path _greenPath() {
    return Path()
      ..moveTo(12, 23)
      ..cubicTo(14.97, 23, 17.46, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.09)
      ..lineTo(2.18, 14.09)
      ..lineTo(2.18, 16.93)
      ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
      ..close();
  }

  Path _yellowPath() {
    return Path()
      ..moveTo(5.84, 14.09)
      ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.06)
      ..lineTo(2.18, 7.06)
      ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
      ..cubicTo(1, 13.78, 1.43, 15.45, 2.18, 16.94)
      ..lineTo(5.84, 14.09)
      ..close();
  }

  Path _redPath() {
    return Path()
      ..moveTo(12, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
      ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.06)
      ..lineTo(5.84, 9.9)
      ..cubicTo(6.71, 7.3, 9.14, 5.38, 12, 5.38)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
