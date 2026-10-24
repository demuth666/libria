import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../data/settings_repository.dart';
import '../data/theme_preference.dart';

/// Pilihan tampilan aktif, dimuat dari penyimpanan lokal saat aplikasi dibuka.
///
/// Perubahan langsung diterapkan ke `MaterialApp` lewat `themeMode`, lalu
/// disimpan ke perangkat. Bila penyimpanan gagal, pilihan dikembalikan ke nilai
/// sebelumnya agar tampilan tidak berbeda dari yang tersimpan (FR-G2).
class ThemePreferenceController extends AsyncNotifier<ThemePreference> {
  @override
  Future<ThemePreference> build() {
    return ref.watch(settingsRepositoryProvider).loadThemePreference();
  }

  /// Memilih [preference], menerapkannya segera, lalu menyimpannya.
  Future<void> select(ThemePreference preference) async {
    final ThemePreference previous = state.value ?? ThemePreference.system;
    if (preference == previous) {
      return;
    }

    state = AsyncData<ThemePreference>(preference);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveThemePreference(preference);
    } on SettingsFailure {
      if (ref.mounted) {
        state = AsyncData<ThemePreference>(previous);
      }
      rethrow;
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData<ThemePreference>(previous);
      }
      throw const SettingsFailure(AppStrings.settingsThemeSaveError);
    }
  }
}

/// Pilihan tampilan aplikasi yang dipakai `LibriaApp` dan layar Pengaturan.
final AsyncNotifierProvider<ThemePreferenceController, ThemePreference>
themePreferenceProvider =
    AsyncNotifierProvider<ThemePreferenceController, ThemePreference>(
      ThemePreferenceController.new,
    );
