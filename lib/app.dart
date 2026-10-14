import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';

/// Akar aplikasi Libria.
class LibriaApp extends StatelessWidget {
  const LibriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Banner offline dipasang di atas seluruh isi aplikasi, termasuk di atas
      // shell dengan navigasi bawah pada task router.
      builder: (BuildContext context, Widget? child) =>
          OfflineBannerHost(child: child ?? const SizedBox.shrink()),
      home: const PlaceholderScreen(),
    );
  }
}

/// Layar sementara sampai Splash dan router dibuat pada task berikutnya.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          AppStrings.appName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
