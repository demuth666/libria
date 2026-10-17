import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Kerangka responsif untuk layar autentikasi.
///
/// Di ponsel, [hero] dan [content] ditumpuk dalam satu kolom dengan lebar
/// maksimum [maxContentWidth]. Pada layar lebar (tablet), keduanya ditampilkan
/// berdampingan dengan lebar maksimum [wideMaxContentWidth] agar ruang layar
/// terpakai dan formulir tidak menggantung di sisi atas.
class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({
    required this.hero,
    required this.content,
    this.maxContentWidth = 440,
    this.wideMaxContentWidth = 960,
    this.wideBreakpoint = 720,
    this.spacing = AppSpacing.lg,
    super.key,
  });

  /// Bagian pengantar di sisi kiri pada layar lebar.
  final Widget hero;

  /// Formulir dan tautan utama.
  final Widget content;

  /// Lebar maksimum konten pada ponsel.
  final double maxContentWidth;

  /// Lebar maksimum konten pada layar lebar.
  final double wideMaxContentWidth;

  /// Lebar layar logis mulai dari layout dua kolom dipakai.
  final double wideBreakpoint;

  /// Jarak antarbagian, baik vertikal pada ponsel maupun horizontal pada
  /// tablet.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SizedBox.expand(
        child: DecoratedBox(
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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isWide = constraints.maxWidth >= wideBreakpoint;
                final double horizontalPadding = isWide
                    ? AppSpacing.xl
                    : AppSpacing.screenMargin;
                final EdgeInsets padding = EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.lg,
                  horizontalPadding,
                  AppSpacing.screenMargin,
                );
                final double minHeight = math.max(
                  0,
                  constraints.maxHeight - padding.vertical,
                );

                return SingleChildScrollView(
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide
                              ? wideMaxContentWidth
                              : maxContentWidth,
                        ),
                        child: isWide
                            ? _WideLayout(
                                hero: hero,
                                content: content,
                                spacing: spacing,
                              )
                            : _NarrowLayout(
                                hero: hero,
                                content: content,
                                spacing: spacing,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.hero,
    required this.content,
    required this.spacing,
  });

  final Widget hero;
  final Widget content;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        hero,
        SizedBox(height: spacing),
        content,
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.hero,
    required this.content,
    required this.spacing,
  });

  final Widget hero;
  final Widget content;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: hero),
        SizedBox(width: spacing + AppSpacing.sm),
        Expanded(flex: 5, child: content),
      ],
    );
  }
}
