import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Radius sudut dari token desain "Literary Elegance".
///
/// Padanan token Stitch: extraSmall = sm (0.25rem), small = DEFAULT (0.5rem),
/// medium = md (0.75rem), large = lg (1rem), extraLarge = xl (1.5rem),
/// full = full.
abstract final class AppRadius {
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 24;
  static const double full = 999;

  static const BorderRadius allSmall = BorderRadius.all(Radius.circular(small));
  static const BorderRadius allMedium = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius allLarge = BorderRadius.all(Radius.circular(large));
  static const BorderRadius allExtraLarge = BorderRadius.all(
    Radius.circular(extraLarge),
  );
  static const BorderRadius allFull = BorderRadius.all(Radius.circular(full));
}

/// Jarak dari token desain "Literary Elegance".
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Margin layar ponsel (px-margin 1.25rem).
  static const double screenMargin = 20;

  /// Margin layar sempit (px-margin-mobile 1rem).
  static const double screenMarginSmall = 16;

  /// Jarak antarkartu dalam grid.
  static const double gridGutter = 16;

  /// Jarak rapat dalam grid dua kolom.
  static const double gridGutterSmall = 12;
}

/// Bayangan dari pedoman gaya "Literary Elegance".
///
/// Dipakai lewat `Container`/`DecoratedBox`; warna dan blur mengikuti
/// spesifikasi Stitch (lihat docs/DESIGN.md bagian Elevasi).
abstract final class AppShadows {
  /// Kartu dan tile permukaan (level 1).
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 16,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
  ];

  /// Dialog dan bottom sheet aktif (level 2).
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x1F0F172A),
      blurRadius: 30,
      spreadRadius: -4,
      offset: Offset(0, 10),
    ),
  ];

  /// Bayangan kartu ringan yang dipakai layar Stitch (setara shadow-sm).
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Cahaya ke atas pada bilah navigasi bawah.
  static const List<BoxShadow> navigationBar = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 20, offset: Offset(0, -4)),
  ];

  /// Garis bayangan tipis di bawah header layar.
  static const List<BoxShadow> header = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1)),
  ];

  /// Bayangan sampul buku.
  static const List<BoxShadow> cover = [
    BoxShadow(color: Color(0x1F002045), blurRadius: 14, offset: Offset(0, 6)),
  ];

  /// Sigma blur kaca untuk `BackdropFilter` (setara blur 16 px CSS).
  static const double glassBlurSigma = 8;
}

/// Tema Libria untuk mode terang dan gelap.
abstract final class AppTheme {
  static ThemeData get light =>
      _build(scheme: AppColors.lightScheme, extras: AppSemanticColors.light);

  static ThemeData get dark =>
      _build(scheme: AppColors.darkScheme, extras: AppSemanticColors.dark);

  static ThemeData _build({
    required ColorScheme scheme,
    required AppSemanticColors extras,
  }) {
    final TextTheme text = AppTextStyles.textTheme;
    final bool isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [extras],
      appBarTheme: AppBarTheme(
        backgroundColor: extras.glassHeader,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineMd.copyWith(
          color: scheme.primary,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        actionsIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: extras.glassSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return AppTextStyles.labelSm.copyWith(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
          side: BorderSide(color: extras.cardBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHigh,
        labelStyle: AppTextStyles.labelSm.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: AppTextStyles.labelSm.copyWith(
          color: scheme.onPrimary,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12.5,
        ),
        hintStyle: AppTextStyles.bodyMd.copyWith(color: scheme.outline),
        labelStyle: AppTextStyles.bodyMd.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: AppTextStyles.labelMd.copyWith(
          color: scheme.secondary,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.allMedium,
          borderSide: BorderSide(color: extras.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMedium,
          borderSide: BorderSide(color: extras.inputBorder),
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
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          textStyle: AppTextStyles.labelLg,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.allMedium,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          textStyle: AppTextStyles.labelLg,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.allMedium,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          minimumSize: const Size(48, 48),
          textStyle: AppTextStyles.labelLg,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.allMedium,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.extraLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTextStyles.headlineSm.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: AppTextStyles.bodyMd.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.allExtraLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: AppTextStyles.bodyMd.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMedium),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainer,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTextStyles.labelLg.copyWith(color: scheme.primary),
        subtitleTextStyle: AppTextStyles.bodySm.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primaryContainer;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(scheme.onPrimary),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.extraSmall)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.outline;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
    );
  }
}
