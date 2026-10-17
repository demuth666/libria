import 'package:flutter/material.dart';

/// Token warna Libria.
///
/// Sumber: design system "Literary Elegance" pada proyek Stitch
/// "Aesthetic Navbar Redesign". Skema terang mengikuti named colors Stitch
/// apa adanya; skema gelap diturunkan dari token yang sama mengikuti peran
/// Material 3. Aturan turunan dan tabel lengkapnya ada di docs/DESIGN.md.
///
/// Jangan menulis kode warna langsung di widget. Ambil dari tema:
/// `Theme.of(context).colorScheme` untuk peran Material 3, atau
/// `Theme.of(context).extension<AppSemanticColors>()` untuk token tambahan.
abstract final class AppColors {
  // Palet merek dari pedoman gaya "Literary Elegance".
  static const Color deepNavy = Color(0xFF1A365D);
  static const Color navyPressed = Color(0xFF0F2942);
  static const Color emeraldTeal = Color(0xFF0D9488);
  static const Color mintTeal = Color(0xFF14B8A6);
  static const Color archivalSlate = Color(0xFF0F172A);
  static const Color slateIcon = Color(0xFF64748B);
  static const Color slateTrough = Color(0xFFF1F5F9);
  static const Color coolCanvas = Color(0xFFF8FAFC);
  static const Color creamCanvas = Color(0xFFFDFBF7);

  /// Skema terang, sama persis dengan named colors Stitch.
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF002045),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF1A365D),
    onPrimaryContainer: Color(0xFF86A0CD),
    primaryFixed: Color(0xFFD6E3FF),
    primaryFixedDim: Color(0xFFADC7F7),
    onPrimaryFixed: Color(0xFF001B3C),
    onPrimaryFixedVariant: Color(0xFF2D476F),
    secondary: Color(0xFF006A61),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFF86F2E4),
    onSecondaryContainer: Color(0xFF006F66),
    secondaryFixed: Color(0xFF89F5E7),
    secondaryFixedDim: Color(0xFF6BD8CB),
    onSecondaryFixed: Color(0xFF00201D),
    onSecondaryFixedVariant: Color(0xFF005049),
    tertiary: Color(0xFF002521),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF003D36),
    onTertiaryContainer: Color(0xFF00B2A0),
    tertiaryFixed: Color(0xFF71F8E4),
    tertiaryFixedDim: Color(0xFF4FDBC8),
    onTertiaryFixed: Color(0xFF00201C),
    onTertiaryFixedVariant: Color(0xFF005048),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFFAF8FF),
    onSurface: Color(0xFF131B2E),
    onSurfaceVariant: Color(0xFF43474E),
    surfaceDim: Color(0xFFD2D9F4),
    surfaceBright: Color(0xFFFAF8FF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF2F3FF),
    surfaceContainer: Color(0xFFEAEDFF),
    surfaceContainerHigh: Color(0xFFE2E7FF),
    surfaceContainerHighest: Color(0xFFDAE2FD),
    outline: Color(0xFF74777F),
    outlineVariant: Color(0xFFC4C6CF),
    inverseSurface: Color(0xFF283044),
    onInverseSurface: Color(0xFFEEF0FF),
    inversePrimary: Color(0xFFADC7F7),
    surfaceTint: Color(0xFF455F88),
    shadow: Color(0xFF0F172A),
  );

  /// Skema gelap, diturunkan dari token yang sama.
  ///
  /// Aturan: peran terang dipindahkan ke peran gelap Material 3 memakai
  /// fixed tone yang sudah ada pada palet Stitch (mis. primary gelap = P80
  /// yang sama dengan inversePrimary terang), dan neutral gelap dihitung
  /// dari keluarga neutral yang sama dengan kanvas terang.
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFADC7F7),
    onPrimary: Color(0xFF0D284C),
    primaryContainer: Color(0xFF1A365D),
    onPrimaryContainer: Color(0xFFD6E3FF),
    primaryFixed: Color(0xFFD6E3FF),
    primaryFixedDim: Color(0xFFADC7F7),
    onPrimaryFixed: Color(0xFF001B3C),
    onPrimaryFixedVariant: Color(0xFF2D476F),
    secondary: Color(0xFF6BD8CB),
    onSecondary: Color(0xFF003833),
    secondaryContainer: Color(0xFF005049),
    onSecondaryContainer: Color(0xFF86F2E4),
    secondaryFixed: Color(0xFF89F5E7),
    secondaryFixedDim: Color(0xFF6BD8CB),
    onSecondaryFixed: Color(0xFF00201D),
    onSecondaryFixedVariant: Color(0xFF005049),
    tertiary: Color(0xFF4FDBC8),
    onTertiary: Color(0xFF003832),
    tertiaryContainer: Color(0xFF005048),
    onTertiaryContainer: Color(0xFF71F8E4),
    tertiaryFixed: Color(0xFF71F8E4),
    tertiaryFixedDim: Color(0xFF4FDBC8),
    onTertiaryFixed: Color(0xFF00201C),
    onTertiaryFixedVariant: Color(0xFF005048),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0D1424),
    onSurface: Color(0xFFDAE2FD),
    onSurfaceVariant: Color(0xFFC4C6CF),
    surfaceDim: Color(0xFF0D1424),
    surfaceBright: Color(0xFF2F374B),
    surfaceContainerLowest: Color(0xFF090F1D),
    surfaceContainerLow: Color(0xFF131B2E),
    surfaceContainer: Color(0xFF171F31),
    surfaceContainerHigh: Color(0xFF222A3C),
    surfaceContainerHighest: Color(0xFF2C3447),
    outline: Color(0xFF8F9199),
    outlineVariant: Color(0xFF43474E),
    inverseSurface: Color(0xFFDAE2FD),
    onInverseSurface: Color(0xFF283044),
    inversePrimary: Color(0xFF2D476F),
    surfaceTint: Color(0xFFADC7F7),
    shadow: Color(0xFF000000),
  );
}

/// Warna resmi merek Google untuk tombol masuk dengan Google.
///
/// Bukan bagian dari palet "Literary Elegance"; dipakai hanya agar logo pada
/// tombol autentikasi sesuai panduan merek Google.
abstract final class GoogleBrandColors {
  const GoogleBrandColors._();

  static const Color blue = Color(0xFF4285F4);
  static const Color green = Color(0xFF34A853);
  static const Color yellow = Color(0xFFFBBC05);
  static const Color red = Color(0xFFEA4335);
}

/// Token tambahan di luar peran Material 3.
///
/// Dipakai untuk komponen yang khas Libria: garis kartu, garis input,
/// permukaan kaca (header dan navigasi bawah), warna bintang rating, dan
/// scrim dialog. Ambil lewat
/// `Theme.of(context).extension<AppSemanticColors>()`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.cardBorder,
    required this.inputBorder,
    required this.glassSurface,
    required this.glassHeader,
    required this.starRating,
    required this.scrim,
  });

  /// Garis 1px tepi kartu (pedoman gaya level 1).
  final Color cardBorder;

  /// Garis kolom input yang belum fokus.
  final Color inputBorder;

  /// Dasar permukaan kaca navigasi bawah (sudah termasuk alfa).
  final Color glassSurface;

  /// Dasar permukaan kaca header layar (sudah termasuk alfa).
  final Color glassHeader;

  /// Warna bintang rating.
  final Color starRating;

  /// Latar belakang gelap untuk dialog dan bottom sheet (sudah termasuk alfa).
  final Color scrim;

  static const AppSemanticColors light = AppSemanticColors(
    cardBorder: Color(0xFFE2E8F0),
    inputBorder: Color(0xFFCBD5E1),
    glassSurface: Color(0xD9FFFFFF),
    glassHeader: Color(0xCCFAF8FF),
    starRating: Color(0xFFEAB308),
    scrim: Color(0x660F172A),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    cardBorder: Color(0xFF2A3246),
    inputBorder: Color(0xFF43474E),
    glassSurface: Color(0xD9222A3C),
    glassHeader: Color(0xCC171F31),
    starRating: Color(0xFFFACC15),
    scrim: Color(0x99000000),
  );

  @override
  AppSemanticColors copyWith({
    Color? cardBorder,
    Color? inputBorder,
    Color? glassSurface,
    Color? glassHeader,
    Color? starRating,
    Color? scrim,
  }) {
    return AppSemanticColors(
      cardBorder: cardBorder ?? this.cardBorder,
      inputBorder: inputBorder ?? this.inputBorder,
      glassSurface: glassSurface ?? this.glassSurface,
      glassHeader: glassHeader ?? this.glassHeader,
      starRating: starRating ?? this.starRating,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassHeader: Color.lerp(glassHeader, other.glassHeader, t)!,
      starRating: Color.lerp(starRating, other.starRating, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
