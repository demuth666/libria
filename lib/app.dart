import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';

/// Akar aplikasi Libria.
class LibriaApp extends StatelessWidget {
  const LibriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: AppStrings.appName,
      home: PlaceholderScreen(),
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
