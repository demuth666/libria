import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import '../responsive/content_width.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Header kaca tetap untuk layar di dalam shell user.
///
/// Menyamakan latar, bayangan, tinggi, jarak tepi, dan batas lebar isi yang
/// dipakai Koleksi dan layar turunannya seperti pencarian katalog.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    this.leading,
    this.actions = const <Widget>[],
    super.key,
  });

  /// Judul layar; ambil dari `AppStrings`.
  final String title;

  /// Widget di kiri judul, misalnya ikon merek atau tombol kembali.
  final Widget? leading;

  /// Widget di kanan judul, misalnya tombol pencarian dan avatar.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: extras.glassHeader,
        boxShadow: AppShadows.header,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ContentWidth(
            maxWidth: 960,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: scheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
