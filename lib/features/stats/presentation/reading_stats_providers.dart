import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../library/data/library_entry.dart';
import '../../session/data/reading_session.dart';
import '../data/reading_stats_repository.dart';

/// Jumlah sesi dan buku yang dimuat per langkah pada layar Statistik.
///
/// Batas dinaikkan dua kali lipat sampai seluruh data terbaca. Dengan begitu
/// statistik tetap dihitung dari seluruh riwayat tanpa satu query tanpa batas.
const int readingStatsPageSize = 200;

/// Data yang berhasil dimuat untuk layar Statistik.
class ReadingStatsData {
  const ReadingStatsData({
    this.sessions = const <ReadingSession>[],
    this.finishedBooks = const <LibraryEntry>[],
    this.streamError,
  });

  final List<ReadingSession> sessions;
  final List<LibraryEntry> finishedBooks;

  /// Galat setelah data pernah tampil. Data terakhir dipertahankan agar
  /// statistik yang sudah dimuat tetap terbaca saat offline.
  final String? streamError;

  bool get isEmpty => sessions.isEmpty;

  ReadingStatsData copyWith({
    List<ReadingSession>? sessions,
    List<LibraryEntry>? finishedBooks,
    String? streamError,
  }) {
    return ReadingStatsData(
      sessions: sessions ?? this.sessions,
      finishedBooks: finishedBooks ?? this.finishedBooks,
      streamError: streamError ?? this.streamError,
    );
  }
}

/// Pengendali data Statistik (FR-T1 dan FR-T2).
///
/// Sesi dan buku selesai didengarkan bersamaan. Masing-masing stream dimulai
/// dengan [readingStatsPageSize] data; bila hasilnya penuh, batas dinaikkan
/// sampai data habis sehingga total tidak terpotong. Kegagalan setelah data
/// tampil disimpan sebagai [ReadingStatsData.streamError] agar angka terakhir
/// tidak hilang.
class ReadingStatsController extends Notifier<AsyncValue<ReadingStatsData>> {
  late ReadingStatsRepository _repository;
  StreamSubscription<List<ReadingSession>>? _sessionSubscription;
  StreamSubscription<List<LibraryEntry>>? _bookSubscription;
  int _sessionLimit = readingStatsPageSize;
  int _bookLimit = readingStatsPageSize;
  int _sessionGeneration = 0;
  int _bookGeneration = 0;
  List<ReadingSession>? _sessions;
  List<LibraryEntry>? _finishedBooks;
  String? _streamError;

  @override
  AsyncValue<ReadingStatsData> build() {
    _repository = ref.watch(readingStatsRepositoryProvider);
    _resetData();

    ref.onDispose(() {
      _sessionGeneration++;
      _bookGeneration++;
      unawaited(_sessionSubscription?.cancel());
      unawaited(_bookSubscription?.cancel());
    });

    Future<void>.microtask(() {
      if (ref.mounted) {
        _listen();
      }
    });

    return const AsyncLoading<ReadingStatsData>();
  }

  void _resetData() {
    _sessionLimit = readingStatsPageSize;
    _bookLimit = readingStatsPageSize;
    _sessions = null;
    _finishedBooks = null;
    _streamError = null;
  }

  void _listen() {
    _listenSessions();
    _listenFinishedBooks();
  }

  void _listenSessions() {
    final int generation = ++_sessionGeneration;
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription = _repository
        .watchSessions(limit: _sessionLimit)
        .listen(
          (List<ReadingSession> sessions) {
            if (!ref.mounted || generation != _sessionGeneration) {
              return;
            }
            if (sessions.length >= _sessionLimit) {
              _sessionLimit *= 2;
              _listenSessions();
              return;
            }
            _sessions = List<ReadingSession>.unmodifiable(sessions);
            _emitData();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!ref.mounted || generation != _sessionGeneration) {
              return;
            }
            _handleError(error, stackTrace);
          },
        );
  }

  void _listenFinishedBooks() {
    final int generation = ++_bookGeneration;
    unawaited(_bookSubscription?.cancel());
    _bookSubscription = _repository
        .watchFinishedBooks(limit: _bookLimit)
        .listen(
          (List<LibraryEntry> entries) {
            if (!ref.mounted || generation != _bookGeneration) {
              return;
            }
            if (entries.length >= _bookLimit) {
              _bookLimit *= 2;
              _listenFinishedBooks();
              return;
            }
            _finishedBooks = List<LibraryEntry>.unmodifiable(entries);
            _emitData();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!ref.mounted || generation != _bookGeneration) {
              return;
            }
            _handleError(error, stackTrace);
          },
        );
  }

  void _emitData() {
    final List<ReadingSession>? sessions = _sessions;
    final List<LibraryEntry>? finishedBooks = _finishedBooks;
    if (sessions == null || finishedBooks == null) {
      return;
    }
    state = AsyncData<ReadingStatsData>(
      ReadingStatsData(
        sessions: sessions,
        finishedBooks: finishedBooks,
        streamError: _streamError,
      ),
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    final String message = error is ReadingStatsFailure
        ? error.message
        : AppStrings.statsLoadError;

    if (state.hasValue) {
      _streamError = message;
      final ReadingStatsData data = state.requireValue;
      state = AsyncData<ReadingStatsData>(data.copyWith(streamError: message));
      return;
    }

    state = AsyncError<ReadingStatsData>(error, stackTrace);
  }

  /// Memuat ulang kedua sumber data dari batas awal.
  void retry() {
    if (!ref.mounted) {
      return;
    }
    _resetData();
    state = const AsyncLoading<ReadingStatsData>();
    _listen();
  }
}

/// Data Statistik milik pengguna aktif.
///
/// Provider dibuang saat layar tidak lagi mendengarkan, sehingga membuka tab
/// Statistik kembali selalu mengambil data terbaru dari cache atau server.
final NotifierProvider<ReadingStatsController, AsyncValue<ReadingStatsData>>
readingStatsProvider =
    NotifierProvider.autoDispose<
      ReadingStatsController,
      AsyncValue<ReadingStatsData>
    >(ReadingStatsController.new);
