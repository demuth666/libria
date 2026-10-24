import 'package:flutter/material.dart';

/// Pilihan tampilan aplikasi yang disimpan di perangkat (FR-G2).
enum ThemePreference {
  /// Mengikuti pengaturan tema perangkat.
  system,

  /// Selalu memakai tema terang.
  light,

  /// Selalu memakai tema gelap.
  dark;

  /// Nilai yang disimpan di `shared_preferences`.
  String get storageValue => name;

  /// Memetakan pilihan tersimpan ke [ThemeMode] untuk `MaterialApp`.
  ThemeMode get themeMode {
    return switch (this) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };
  }

  /// Membaca nilai tersimpan. Nilai kosong atau tidak dikenal dianggap
  /// "Ikuti sistem" agar aplikasi tetap terbuka dengan aman.
  static ThemePreference fromStorageValue(String? value) {
    for (final ThemePreference preference in values) {
      if (preference.storageValue == value) {
        return preference;
      }
    }
    return ThemePreference.system;
  }
}
