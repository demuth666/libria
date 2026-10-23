import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../data/active_session.dart';
import '../data/active_session_repository.dart';
import '../data/session_timer_engine.dart';

/// Pengendali sesi membaca aktif.
///
/// Saat pertama dibaca, provider memulihkan sesi dari penyimpanan lokal
/// (FR-S9). Setiap transisi timer yang valid langsung memperbarui state dan
/// menulis sesi terbaru ke [ActiveSessionRepository], sehingga aplikasi yang
/// dimatikan sistem tidak kehilangan sesi yang sedang berjalan.
class ActiveSessionController extends AsyncNotifier<ActiveSession?> {
  late ActiveSessionRepository _repository;

  /// Selesai saat pemulihan awal dari penyimpanan lokal selesai, berhasil
  /// maupun gagal. Transisi menunggu ini agar sesi yang dipulihkan tidak
  /// tertimpa oleh sesi baru yang dimulai saat pemuatan masih berjalan.
  Completer<void>? _restored;

  /// Antrean tulis agar perubahan status yang datang berurutan tidak saling
  /// menimpa di penyimpanan lokal.
  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<ActiveSession?> build() async {
    _repository = ref.watch(activeSessionRepositoryProvider);
    final Completer<void> restored = Completer<void>();
    _restored = restored;

    try {
      return await _repository.load();
    } finally {
      if (!restored.isCompleted) {
        restored.complete();
      }
      if (identical(_restored, restored)) {
        _restored = null;
      }
    }
  }

  /// Memulai sesi baru untuk [bookId] dengan target [target].
  ///
  /// Melempar [ActiveSessionFailure] bila sudah ada sesi aktif agar sesi yang
  /// sedang berjalan tidak tertimpa tanpa disimpan lebih dulu.
  Future<void> start({
    required String bookId,
    required String bookTitle,
    required Duration target,
  }) async {
    await _awaitRestored();
    if (!ref.mounted) {
      return;
    }
    if (state.value != null) {
      throw const ActiveSessionFailure(AppStrings.sessionAlreadyActive);
    }

    final ActiveSession session = ActiveSession.start(
      bookId: bookId,
      bookTitle: bookTitle,
      target: target,
    );
    await _commit(session);
  }

  /// Menghentikan sementara sesi aktif.
  Future<void> pause() {
    return _transition((SessionTimerEngine timer) => timer.pause());
  }

  /// Melanjutkan sesi yang sedang dijeda.
  Future<void> resume() {
    return _transition((SessionTimerEngine timer) => timer.resume());
  }

  /// Menyelesaikan sesi aktif.
  ///
  /// Sesi yang selesai tetap tersimpan sampai [clear] dipanggil setelah sesi
  /// disimpan ke Firestore (T-056), sehingga pengguna dapat mengisi halaman
  /// terakhir walaupun aplikasi sempat ditutup.
  Future<void> finish() {
    return _transition((SessionTimerEngine timer) => timer.finish());
  }

  /// Menghapus sesi aktif dari penyimpanan lokal.
  Future<void> clear() async {
    await _awaitRestored();
    await _enqueueWrite(_repository.clear);
    if (!ref.mounted) {
      return;
    }
    state = const AsyncData<ActiveSession?>(null);
  }

  Future<void> _transition(
    SessionTimerEngine Function(SessionTimerEngine timer) update,
  ) async {
    await _awaitRestored();
    if (!ref.mounted) {
      return;
    }

    final ActiveSession? current = state.value;
    if (current == null) {
      return;
    }

    final SessionTimerEngine next = update(current.timer);
    // Transisi yang tidak sesuai status saat ini mengembalikan mesin yang sama;
    // tidak ada perubahan yang perlu disimpan.
    if (identical(next, current.timer)) {
      return;
    }

    await _commit(current.copyWithTimer(next));
  }

  Future<void> _commit(ActiveSession session) async {
    if (!ref.mounted) {
      return;
    }
    state = AsyncData<ActiveSession?>(session);
    await _enqueueWrite(() => _repository.save(session));
  }

  Future<void> _awaitRestored() async {
    final Completer<void>? restored = _restored;
    if (restored != null) {
      await restored.future;
    }
  }

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final Completer<void> result = Completer<void>();
    _pendingWrite = _pendingWrite.then<void>((void _) async {
      try {
        await write();
        if (!result.isCompleted) {
          result.complete();
        }
      } catch (error, stackTrace) {
        if (!result.isCompleted) {
          result.completeError(error, stackTrace);
        }
      }
    });
    return result.future;
  }
}

/// Sesi membaca aktif yang dipulihkan dari penyimpanan lokal saat aplikasi
/// dibuka (FR-S9).
final AsyncNotifierProvider<ActiveSessionController, ActiveSession?>
activeSessionProvider =
    AsyncNotifierProvider<ActiveSessionController, ActiveSession?>(
      ActiveSessionController.new,
      // Galat penyimpanan lokal tidak dipulihkan dengan percobaan ulang
      // otomatis; pengguna dapat memicunya kembali lewat layar sesi.
      retry: (int retryCount, Object error) => null,
    );
