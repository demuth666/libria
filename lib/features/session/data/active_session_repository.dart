import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_strings.dart';
import 'active_session.dart';

/// Galat penyimpanan sesi aktif dengan pesan yang sudah ramah pengguna dalam
/// bahasa Indonesia, siap ditampilkan langsung ke layar.
class ActiveSessionFailure implements Exception {
  const ActiveSessionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Penyimpanan sesi membaca aktif di perangkat.
///
/// Sesi ditulis sebagai satu nilai JSON pada `shared_preferences` setiap kali
/// status timer berubah, sehingga sesi yang berjalan dapat dipulihkan setelah
/// aplikasi dimatikan sistem (FR-S9). Widget tidak memakai
/// `SharedPreferences` secara langsung; semua akses lewat repository ini.
class ActiveSessionRepository {
  ActiveSessionRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Kunci penyimpanan sesi aktif.
  static const String storageKey = 'libria_active_session';

  final DateTime Function() _clock;

  /// Membaca sesi aktif yang tersimpan, atau `null` bila belum ada.
  ///
  /// Data yang rusak atau tidak lengkap dibuang agar aplikasi tidak gagal
  /// dibuka. Kegagalan mengakses penyimpanan dilempar sebagai
  /// [ActiveSessionFailure] dengan pesan yang ramah.
  Future<ActiveSession?> load() async {
    final SharedPreferences preferences = await _preferences(
      AppStrings.sessionActiveLoadError,
    );

    final String? raw;
    try {
      raw = preferences.getString(storageKey);
    } catch (_) {
      throw const ActiveSessionFailure(AppStrings.sessionActiveLoadError);
    }
    if (raw == null) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _discard(preferences);
        return null;
      }

      final ActiveSession session = ActiveSession.fromMap(
        Map<String, dynamic>.from(decoded),
        clock: _clock,
      );
      if (!session.isRestorable) {
        await _discard(preferences);
        return null;
      }
      return session;
    } catch (_) {
      // JSON rusak atau bentuk map tidak sesuai; buang agar tidak dibaca
      // berulang kali pada pembukaan berikutnya.
      await _discard(preferences);
      return null;
    }
  }

  /// Menyimpan [session] sebagai sesi aktif terbaru.
  Future<void> save(ActiveSession session) async {
    final SharedPreferences preferences = await _preferences(
      AppStrings.sessionActiveSaveError,
    );

    final bool saved;
    try {
      saved = await preferences.setString(
        storageKey,
        jsonEncode(session.toMap()),
      );
    } catch (_) {
      throw const ActiveSessionFailure(AppStrings.sessionActiveSaveError);
    }
    if (!saved) {
      throw const ActiveSessionFailure(AppStrings.sessionActiveSaveError);
    }
  }

  /// Menghapus sesi aktif setelah sesi disimpan ke Firestore (T-056).
  Future<void> clear() async {
    final SharedPreferences preferences = await _preferences(
      AppStrings.sessionActiveSaveError,
    );
    try {
      await preferences.remove(storageKey);
    } catch (_) {
      throw const ActiveSessionFailure(AppStrings.sessionActiveSaveError);
    }
  }

  Future<SharedPreferences> _preferences(String errorMessage) async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      throw ActiveSessionFailure(errorMessage);
    }
  }

  Future<void> _discard(SharedPreferences preferences) async {
    try {
      await preferences.remove(storageKey);
    } catch (_) {
      // Data rusak tetap diabaikan; kegagalan menghapus tidak boleh membuat
      // aplikasi gagal dibuka.
    }
  }
}

/// Akses penyimpanan sesi aktif untuk seluruh lapisan presentasi.
final Provider<ActiveSessionRepository> activeSessionRepositoryProvider =
    Provider<ActiveSessionRepository>((Ref ref) => ActiveSessionRepository());
