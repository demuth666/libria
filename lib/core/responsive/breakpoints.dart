import 'package:flutter/widgets.dart';

/// Kategori lebar layar mengikuti breakpoint Material 3.
enum ScreenSize { compact, medium, expanded }

/// Breakpoint lebar layar yang dipakai seluruh antarmuka Libria.
///
/// Nilai mengikuti Material 3: compact di bawah 600 dp, medium mulai 600 dp,
/// dan expanded mulai 840 dp. Jangan membandingkan lebar perangkat secara
/// langsung di widget; gunakan [of] atau konstanta di kelas ini.
abstract final class Breakpoints {
  const Breakpoints._();

  /// Batas bawah layar medium, dalam dp.
  static const double medium = 600;

  /// Batas bawah layar expanded, dalam dp.
  static const double expanded = 840;

  /// Menentukan kategori lebar dari [MediaQuery] terdekat.
  static ScreenSize of(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width < medium) {
      return ScreenSize.compact;
    }
    if (width < expanded) {
      return ScreenSize.medium;
    }
    return ScreenSize.expanded;
  }
}
