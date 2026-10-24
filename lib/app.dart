import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/settings/data/theme_preference.dart';
import 'features/settings/presentation/settings_providers.dart';

/// Akar aplikasi Libria.
class LibriaApp extends ConsumerWidget {
  const LibriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final ThemePreference themePreference =
        ref.watch(themePreferenceProvider).value ?? ThemePreference.system;

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themePreference.themeMode,
      routerConfig: router,
      // Banner offline dipasang di atas seluruh isi aplikasi, termasuk di atas
      // shell dengan navigasi bawah.
      builder: (BuildContext context, Widget? child) =>
          OfflineBannerHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
