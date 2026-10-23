import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/session/data/session_repository.dart';
import 'package:libria/features/session/presentation/session_history_providers.dart';

import 'support/fake_session_repository.dart';

void main() {
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  Future<ProviderContainer> createContainer(
    FakeSessionRepository repository, {
    required SessionHistoryScope scope,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // Menjaga provider autoDispose tetap hidup selama uji.
    container.listen<AsyncValue<SessionHistoryState>>(
      sessionHistoryProvider(scope),
      (
        AsyncValue<SessionHistoryState>? previous,
        AsyncValue<SessionHistoryState> next,
      ) {},
    );
    await settle();
    return container;
  }

  SessionHistoryState stateOf(
    ProviderContainer container,
    SessionHistoryScope scope,
  ) {
    return container.read(sessionHistoryProvider(scope)).requireValue;
  }

  test(
    'memuat halaman pertama semua sesi dan menandai masih ada lagi',
    () async {
      final FakeSessionRepository repository = FakeSessionRepository();
      final List<ReadingSession> sessions = List<ReadingSession>.generate(
        25,
        (int index) => _session(
          'session-$index',
          startedAt: DateTime(2026, 10, 23, 8).subtract(Duration(hours: index)),
        ),
      );
      repository.sessions.addAll(sessions);
      const SessionHistoryScope scope = (bookId: null);

      final ProviderContainer container = await createContainer(
        repository,
        scope: scope,
      );

      final SessionHistoryState initial = stateOf(container, scope);
      expect(initial.sessions, hasLength(sessionHistoryPageSize));
      expect(initial.hasMore, isTrue);
      expect(initial.isLoadingMore, isFalse);
      expect(repository.lastAllLimit, sessionHistoryPageSize);

      container.read(sessionHistoryProvider(scope).notifier).loadMore();
      await settle();

      final SessionHistoryState loaded = stateOf(container, scope);
      expect(loaded.sessions, hasLength(25));
      expect(loaded.hasMore, isFalse);
      expect(loaded.isLoadingMore, isFalse);
      expect(repository.lastAllLimit, sessionHistoryPageSize * 2);
    },
  );

  test('cakupan buku hanya memuat sesi buku itu', () async {
    final FakeSessionRepository repository = FakeSessionRepository();
    repository.sessions.addAll(<ReadingSession>[
      _session('book-1', bookId: 'book-1'),
      _session('book-2', bookId: 'book-2'),
      _session('book-1-other', bookId: 'book-1'),
    ]);
    const SessionHistoryScope scope = (bookId: 'book-1');

    final ProviderContainer container = await createContainer(
      repository,
      scope: scope,
    );

    final SessionHistoryState state = stateOf(container, scope);
    expect(state.sessions, hasLength(2));
    expect(
      state.sessions.every(
        (ReadingSession session) => session.bookId == 'book-1',
      ),
      isTrue,
    );
    expect(repository.lastBookId, 'book-1');
    expect(repository.lastBookLimit, sessionHistoryPageSize);
  });

  test(
    'galat saat memuat lebih banyak mempertahankan sesi yang sudah ada',
    () async {
      final FakeSessionRepository repository = FakeSessionRepository();
      repository.sessions.addAll(
        List<ReadingSession>.generate(
          25,
          (int index) => _session('session-$index'),
        ),
      );
      const SessionHistoryScope scope = (bookId: null);
      final ProviderContainer container = await createContainer(
        repository,
        scope: scope,
      );

      repository.readError = const SessionFailure(
        AppStrings.sessionHistoryNetworkError,
      );
      container.read(sessionHistoryProvider(scope).notifier).loadMore();
      await settle();

      final SessionHistoryState failed = stateOf(container, scope);
      expect(failed.sessions, hasLength(sessionHistoryPageSize));
      expect(failed.loadMoreFailed, isTrue);
      expect(failed.isLoadingMore, isFalse);

      repository.readError = null;
      container.read(sessionHistoryProvider(scope).notifier).retry();
      await settle();

      final SessionHistoryState retried = stateOf(container, scope);
      expect(retried.sessions, hasLength(sessionHistoryPageSize));
      expect(retried.loadMoreFailed, isFalse);
    },
  );

  test('galat awal menampilkan state galat', () async {
    final FakeSessionRepository repository = FakeSessionRepository()
      ..readError = const SessionFailure(AppStrings.sessionHistoryLoadError);
    const SessionHistoryScope scope = (bookId: null);

    final ProviderContainer container = await createContainer(
      repository,
      scope: scope,
    );

    final AsyncValue<SessionHistoryState> state = container.read(
      sessionHistoryProvider(scope),
    );
    expect(state.hasError, isTrue);
    expect(
      state.error,
      isA<SessionFailure>().having(
        (SessionFailure failure) => failure.message,
        'message',
        AppStrings.sessionHistoryLoadError,
      ),
    );
  });

  test('riwayat kosong menghasilkan daftar kosong tanpa galat', () async {
    const SessionHistoryScope scope = (bookId: null);
    final ProviderContainer container = await createContainer(
      FakeSessionRepository(),
      scope: scope,
    );

    final SessionHistoryState state = stateOf(container, scope);
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });
}

ReadingSession _session(
  String id, {
  String bookId = 'book-1',
  DateTime? startedAt,
}) {
  final DateTime start = startedAt ?? DateTime(2026, 10, 23, 9);
  return ReadingSession(
    id: id,
    bookId: bookId,
    bookTitle: 'Bumi Manusia',
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 20)),
    durationSeconds: 20 * 60,
    targetSeconds: 30 * 60,
    startPage: 40,
    endPage: 75,
  );
}
