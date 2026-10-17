import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/app_user.dart';
import '../../features/auth/presentation/auth_providers.dart';

/// Pemicu pemeriksaan ulang redirect go_router saat status login atau role
/// berubah.
///
/// go_router hanya menjalankan `redirect` ketika ada navigasi atau ketika
/// `refreshListenable` memberi tahu. Notifier ini mendengarkan
/// [authStateProvider] dan [currentUserProvider] agar keluar, masuk, maupun
/// perubahan role lewat Firebase Console langsung diterapkan pada rute yang
/// sedang terbuka.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    _subscriptions.add(
      ref.listen<AsyncValue<User?>>(authStateProvider, (
        AsyncValue<User?>? previous,
        AsyncValue<User?> next,
      ) {
        notifyListeners();
      }),
    );
    _subscriptions.add(
      ref.listen<AsyncValue<AppUser?>>(currentUserProvider, (
        AsyncValue<AppUser?>? previous,
        AsyncValue<AppUser?> next,
      ) {
        notifyListeners();
      }),
    );
  }

  final List<ProviderSubscription<Object?>> _subscriptions =
      <ProviderSubscription<Object?>>[];

  @override
  void dispose() {
    for (final ProviderSubscription<Object?> subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
