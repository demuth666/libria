import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_strings.dart';
import 'theme_preference.dart';

/// Galat penyimpanan pengaturan dengan pesan ramah dalam bahasa Indonesia.
class SettingsFailure implements Exception {
  const SettingsFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Penyimpanan pengaturan pengguna di perangkat.
///
/// Widget tidak memakai `SharedPreferences` secara langsung; semua akses lewat
/// repository ini (AGENTS.md bagian 5). Hanya pilihan tampilan yang disimpan di
/// sini karena pengaturan lain berasal dari akun atau data Firestore.
class SettingsRepository {
  /// Kunci penyimpanan pilihan tampilan.
  static const String themePreferenceKey = 'libria_theme_preference';

  /// Membaca pilihan tampilan tersimpan.
  ///
  /// Kegagalan membuka penyimpanan atau membaca nilainya tidak boleh membuat
  /// aplikasi gagal dibuka, sehingga hasilnya jatuh ke [ThemePreference.system].
  Future<ThemePreference> loadThemePreference() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      return ThemePreference.fromStorageValue(
        preferences.getString(themePreferenceKey),
      );
    } catch (_) {
      return ThemePreference.system;
    }
  }

  /// Menyimpan pilihan tampilan agar bertahan setelah aplikasi dibuka ulang.
  Future<void> saveThemePreference(ThemePreference preference) async {
    final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      throw const SettingsFailure(AppStrings.settingsThemeSaveError);
    }

    final bool saved;
    try {
      saved = await preferences.setString(
        themePreferenceKey,
        preference.storageValue,
      );
    } catch (_) {
      throw const SettingsFailure(AppStrings.settingsThemeSaveError);
    }
    if (!saved) {
      throw const SettingsFailure(AppStrings.settingsThemeSaveError);
    }
  }
}

/// Akses penyimpanan pengaturan untuk seluruh lapisan presentasi.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) => SettingsRepository());
