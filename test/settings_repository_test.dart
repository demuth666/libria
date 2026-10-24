import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/settings/data/settings_repository.dart';
import 'package:libria/features/settings/data/theme_preference.dart';
import 'package:libria/features/settings/presentation/settings_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ThemePreference', () {
    test('memetakan pilihan ke ThemeMode', () {
      expect(ThemePreference.system.themeMode, ThemeMode.system);
      expect(ThemePreference.light.themeMode, ThemeMode.light);
      expect(ThemePreference.dark.themeMode, ThemeMode.dark);
    });

    test('nilai kosong atau tidak dikenal kembali ke Ikuti sistem', () {
      expect(ThemePreference.fromStorageValue(null), ThemePreference.system);
      expect(
        ThemePreference.fromStorageValue('tidak-dikenal'),
        ThemePreference.system,
      );
      expect(ThemePreference.fromStorageValue('dark'), ThemePreference.dark);
    });
  });

  group('SettingsRepository', () {
    test('memakai Ikuti sistem saat belum ada pilihan tersimpan', () async {
      final SettingsRepository repository = SettingsRepository();

      expect(await repository.loadThemePreference(), ThemePreference.system);
    });

    test('pilihan tersimpan dibaca kembali oleh instance baru', () async {
      final SettingsRepository repository = SettingsRepository();
      await repository.saveThemePreference(ThemePreference.dark);

      final SettingsRepository reopened = SettingsRepository();
      expect(await reopened.loadThemePreference(), ThemePreference.dark);
      expect(
        await SharedPreferences.getInstance().then(
          (SharedPreferences preferences) =>
              preferences.getString(SettingsRepository.themePreferenceKey),
        ),
        'dark',
      );
    });

    test('pilihan terang juga bertahan', () async {
      await SettingsRepository().saveThemePreference(ThemePreference.light);

      expect(
        await SettingsRepository().loadThemePreference(),
        ThemePreference.light,
      );
    });
  });

  group('themePreferenceProvider', () {
    test('memuat pilihan tersimpan saat pertama dibaca', () async {
      await SettingsRepository().saveThemePreference(ThemePreference.dark);
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(themePreferenceProvider.future),
        ThemePreference.dark,
      );
    });

    test('perubahan langsung tampil sebelum penyimpanan selesai', () async {
      final _PendingSettingsRepository repository =
          _PendingSettingsRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWith((Ref ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(themePreferenceProvider.future),
        ThemePreference.system,
      );

      final Future<void> pending = container
          .read(themePreferenceProvider.notifier)
          .select(ThemePreference.dark);

      expect(
        container.read(themePreferenceProvider).value,
        ThemePreference.dark,
      );
      expect(repository.saved, ThemePreference.dark);

      repository.completer.complete();
      await pending;

      expect(
        container.read(themePreferenceProvider).value,
        ThemePreference.dark,
      );
    });

    test('memilih pilihan yang sama tidak menulis ulang', () async {
      final _RecordingSettingsRepository repository =
          _RecordingSettingsRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWith((Ref ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(themePreferenceProvider.future);
      await container
          .read(themePreferenceProvider.notifier)
          .select(ThemePreference.system);

      expect(repository.saveCalls, 0);
    });

    test('kegagalan menyimpan mengembalikan pilihan sebelumnya', () async {
      final _FailingSettingsRepository repository =
          _FailingSettingsRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWith((Ref ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(themePreferenceProvider.future);

      await expectLater(
        container
            .read(themePreferenceProvider.notifier)
            .select(ThemePreference.dark),
        throwsA(
          isA<SettingsFailure>().having(
            (SettingsFailure failure) => failure.message,
            'message',
            AppStrings.settingsThemeSaveError,
          ),
        ),
      );

      expect(
        container.read(themePreferenceProvider).value,
        ThemePreference.system,
      );
    });
  });
}

class _PendingSettingsRepository implements SettingsRepository {
  final Completer<void> completer = Completer<void>();
  ThemePreference? saved;

  @override
  Future<ThemePreference> loadThemePreference() async => ThemePreference.system;

  @override
  Future<void> saveThemePreference(ThemePreference preference) {
    saved = preference;
    return completer.future;
  }
}

class _RecordingSettingsRepository implements SettingsRepository {
  int saveCalls = 0;

  @override
  Future<ThemePreference> loadThemePreference() async => ThemePreference.system;

  @override
  Future<void> saveThemePreference(ThemePreference preference) async {
    saveCalls++;
  }
}

class _FailingSettingsRepository implements SettingsRepository {
  @override
  Future<ThemePreference> loadThemePreference() async => ThemePreference.system;

  @override
  Future<void> saveThemePreference(ThemePreference preference) async {
    throw const SettingsFailure(AppStrings.settingsThemeSaveError);
  }
}
