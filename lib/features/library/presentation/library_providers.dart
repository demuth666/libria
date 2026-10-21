import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/connectivity_service.dart';
import '../data/library_entry.dart';
import '../data/library_repository.dart';

/// Penanda untuk [LibraryShelfData.copyWith] agar nilai galat bisa
/// dikosongkan secara eksplisit.
const Object _unset = Object();

/// Data rak yang berhasil diterima dari satu stream.
///
/// [streamError] menyimpan galat pembaruan saat data terakhir masih tampil.
/// Bentuk ini dipakai di dalam [AsyncValue] agar loading, data, dan galat awal
/// tetap direpresentasikan oleh state async standar Riverpod.
class LibraryShelfData {
  const LibraryShelfData({
    this.entries = const <LibraryEntry>[],
    this.streamError,
  });

  /// Seluruh entri rak dari satu stream, sudah terurut dari repository.
  final List<LibraryEntry> entries;

  /// Galat setelah data pernah tampil; daftar terakhir dipertahankan dan
  /// layar hanya menampilkan pemberitahuan ringan.
  final String? streamError;

  LibraryShelfData copyWith({
    List<LibraryEntry>? entries,
    Object? streamError = _unset,
  }) {
    return LibraryShelfData(
      entries: entries ?? this.entries,
      streamError: identical(streamError, _unset)
          ? this.streamError
          : streamError as String?,
    );
  }
}

/// Pengendali layar Koleksi.
///
/// Hanya memakai satu stream [LibraryRepository.watchLibrary]. Hitungan dan
/// filter segmen dihitung di memori oleh layar, sehingga tidak ada query
/// tambahan per segmen. Data terakhir dipertahankan bila stream gagal setelah
/// tampil, dan koneksi yang pulih memulai ulang langganan tanpa mengubah
/// segmen aktif yang disimpan layar.
class LibraryShelfController extends Notifier<AsyncValue<LibraryShelfData>> {
  late LibraryRepository _repository;
  StreamSubscription<List<LibraryEntry>>? _subscription;
  bool _isOffline = false;
  bool _streamClosed = true;
  int _generation = 0;

  @override
  AsyncValue<LibraryShelfData> build() {
    _repository = ref.watch(libraryRepositoryProvider);
    _isOffline = ref.read(connectivityProvider).value == false;

    ref.listen<AsyncValue<bool>>(connectivityProvider, (
      AsyncValue<bool>? previous,
      AsyncValue<bool> next,
    ) {
      final bool? online = next.value;
      if (online == null) {
        return;
      }
      final bool wasOffline = _isOffline;
      _isOffline = !online;
      if (wasOffline && !_isOffline && (_streamClosed || !state.hasValue)) {
        // Stream yang masih hidup melanjutkan sendiri saat koneksi pulih.
        // Langganan hanya dibuka ulang bila stream sudah tertutup atau belum
        // pernah mengemit data apa pun.
        _subscribe(preserveData: true);
      }
    });

    ref.onDispose(() {
      _generation++;
      _streamClosed = true;
      unawaited(_subscription?.cancel());
      _subscription = null;
    });

    // Langganan dimulai setelah build selesai agar perubahan state tidak
    // terjadi saat provider masih dibangun.
    Future<void>.microtask(() {
      if (ref.mounted) {
        _subscribe(preserveData: false);
      }
    });

    return const AsyncLoading<LibraryShelfData>();
  }

  /// Memuat ulang stream. Data yang sudah tampil tetap dipertahankan sampai
  /// snapshot baru masuk.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _subscribe(preserveData: true);
  }

  void _subscribe({required bool preserveData}) {
    if (!ref.mounted) {
      return;
    }

    final int generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _streamClosed = false;

    final LibraryShelfData? previous = state.value;
    if (preserveData && previous != null) {
      state = AsyncData<LibraryShelfData>(previous.copyWith(streamError: null));
    } else {
      state = const AsyncLoading<LibraryShelfData>();
    }

    try {
      _subscription = _repository.watchLibrary().listen(
        (List<LibraryEntry> entries) {
          if (!ref.mounted || generation != _generation) {
            return;
          }
          state = AsyncData<LibraryShelfData>(
            LibraryShelfData(entries: List<LibraryEntry>.unmodifiable(entries)),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!ref.mounted || generation != _generation) {
            return;
          }
          _streamClosed = true;
          _handleError(error, stackTrace);
        },
        onDone: () {
          if (!ref.mounted || generation != _generation) {
            return;
          }
          _streamClosed = true;
          _handleDone();
        },
      );
    } on LibraryFailure catch (failure, stackTrace) {
      _streamClosed = true;
      _handleError(failure, stackTrace);
    } catch (error, stackTrace) {
      _streamClosed = true;
      _handleError(error, stackTrace);
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (!ref.mounted) {
      return;
    }
    final String message = error is LibraryFailure
        ? error.message
        : AppStrings.libraryLoadError;
    final LibraryShelfData? previous = state.value;

    if (previous != null) {
      state = AsyncData<LibraryShelfData>(
        previous.copyWith(streamError: message),
      );
      return;
    }

    state = AsyncError<LibraryShelfData>(
      error is LibraryFailure ? error : LibraryFailure(message),
      stackTrace,
    );
  }

  void _handleDone() {
    if (!ref.mounted || state.hasValue || state.hasError) {
      return;
    }
    if (_isOffline) {
      // Layar menampilkan keadaan offline selama stream belum mengemit apa pun.
      return;
    }
    state = AsyncError<LibraryShelfData>(
      const LibraryFailure(AppStrings.libraryLoadError),
      StackTrace.empty,
    );
  }
}

/// Rak pengguna untuk layar Koleksi pada rute `/home/library`.
///
/// Dibuang saat layar tidak lagi mendengarkan, sehingga membuka kembali tab
/// Koleksi selalu mengambil snapshot terbaru (termasuk cache Firestore saat
/// offline).
final NotifierProvider<LibraryShelfController, AsyncValue<LibraryShelfData>>
libraryShelfProvider =
    NotifierProvider.autoDispose<
      LibraryShelfController,
      AsyncValue<LibraryShelfData>
    >(LibraryShelfController.new);
