import 'package:flutter/material.dart';

/// Token tipografi Libria.
///
/// Sumber: design system "Literary Elegance" pada proyek Stitch
/// "Aesthetic Navbar Redesign". Merriweather untuk judul, Plus Jakarta Sans
/// untuk antarmuka. Ukuran, tinggi baris, bobot, dan jarak huruf mengikuti
/// token Stitch; pemetaannya ke peran [TextTheme] dicatat di docs/DESIGN.md.
abstract final class AppTextStyles {
  static const String headlineFontFamily = 'Merriweather';
  static const String bodyFontFamily = 'Plus Jakarta Sans';

  /// Judul terbesar untuk hero dan angka besar.
  static const TextStyle headlineXl = TextStyle(
    fontFamily: headlineFontFamily,
    fontSize: 36,
    height: 48 / 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.72,
  );

  /// Judul hero versi layar ponsel.
  static const TextStyle headlineXlMobile = TextStyle(
    fontFamily: headlineFontFamily,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.28,
  );

  /// Judul bagian besar.
  static const TextStyle headlineLg = TextStyle(
    fontFamily: headlineFontFamily,
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
  );

  /// Judul layar dan kartu utama.
  static const TextStyle headlineMd = TextStyle(
    fontFamily: headlineFontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
  );

  /// Judul kartu dan subbagian.
  static const TextStyle headlineSm = TextStyle(
    fontFamily: headlineFontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
  );

  /// Teks badan besar.
  static const TextStyle bodyLg = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 16,
    height: 26 / 16,
    fontWeight: FontWeight.w400,
  );

  /// Teks badan standar.
  static const TextStyle bodyMd = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Teks badan kecil.
  static const TextStyle bodySm = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Label tombol dan judul baris.
  static const TextStyle labelLg = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.14,
  );

  /// Label navigasi dan chip.
  static const TextStyle labelMd = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.24,
  );

  /// Label terkecil.
  static const TextStyle labelSm = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
  );

  /// Angka timer dan metrik; memakai angka tabular agar tidak bergeser.
  static const TextStyle timerDisplay = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// [TextTheme] aplikasi hasil pemetaan token di atas.
  static const TextTheme textTheme = TextTheme(
    displayLarge: timerDisplay,
    displayMedium: headlineXl,
    displaySmall: headlineXlMobile,
    headlineLarge: headlineLg,
    headlineMedium: headlineMd,
    headlineSmall: headlineSm,
    titleLarge: headlineMd,
    titleMedium: headlineSm,
    titleSmall: labelLg,
    bodyLarge: bodyLg,
    bodyMedium: bodyMd,
    bodySmall: bodySm,
    labelLarge: labelLg,
    labelMedium: labelMd,
    labelSmall: labelSm,
  );
}
