import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/content_width.dart';
import '../../../../core/theme/app_theme.dart';

/// Kerangka responsif untuk layar autentikasi.
///
/// Hero dan formulir selalu disusun dalam satu kolom dari atas ke bawah.
/// Pada layar di bawah 600 dp, lebar isi dibatasi [compactMaxContentWidth]
/// agar susunan ponsel tidak berubah. Mulai 600 dp, isi dipusatkan dengan
/// lebar maksimum [maxContentWidth] sehingga tidak melebar di tablet.
/// Seluruh isi berada di dalam [SingleChildScrollView] agar aman saat tinggi
/// layar terbatas, misalnya pada tablet landscape.
class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({
    required this.hero,
    required this.content,
    this.maxContentWidth = 640,
    this.compactMaxContentWidth = 440,
    this.spacing = AppSpacing.lg,
    super.key,
  });

  /// Bagian pengantar di atas formulir.
  final Widget hero;

  /// Formulir dan tautan utama.
  final Widget content;

  /// Lebar maksimum isi pada layar medium dan expanded.
  final double maxContentWidth;

  /// Lebar maksimum isi pada layar compact, dipertahankan dari desain ponsel.
  final double compactMaxContentWidth;

  /// Jarak vertikal antara hero dan formulir.
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
                final bool isCompact =
                    constraints.maxWidth < Breakpoints.medium;
                final double horizontalPadding = isCompact
                    ? AppSpacing.screenMargin
                    : AppSpacing.xl;
                final double contentMaxWidth = isCompact
                    ? compactMaxContentWidth
                    : maxContentWidth;
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
                  child: ContentWidth(
                    maxWidth: contentMaxWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            hero,
                            SizedBox(height: spacing),
                            content,
                          ],
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
