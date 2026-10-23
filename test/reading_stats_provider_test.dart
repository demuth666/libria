import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/stats/data/reading_stats_repository.dart';
import 'package:libria/features/stats/presentation/reading_stats_providers.dart';

import 'support/fake_reading_stats_repository.dart';

void main() {
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  Future<ProviderContainer> createContainer(
    FakeReadingStatsRepository repository,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [readingStatsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.listen<AsyncValue<ReadingStatsData>>(
      readingStatsProvider,
      (
        AsyncValue<ReadingStatsData>? previous,
        AsyncValue<ReadingStatsData> next,
      ) {},
    );
    await settle();
    return container;
  }

  test('memuat seluruh sesi lintas halaman dan buku selesai', () async {
    final FakeReadingStatsRepository repository = FakeReadingStatsRepository();
    repository.sessions.addAll(
      List<ReadingSession>.generate(
        readingStatsPageSize + 5,
        (int index) => _session(
          'session-$index',
          startedAt: DateTime(
            2026,
            10,
            23,
            8,
          ).subtract(Duration(minutes: index)),
        ),
      ),
    );
    repository.finishedBooks.addAll(<LibraryEntry>[
      _book('book-1'),
      _book('book-2'),
    ]);

    final ProviderContainer container = await createContainer(repository);
    final ReadingStatsData data = container
        .read(readingStatsProvider)
        .requireValue;

    expect(data.sessions, hasLength(readingStatsPageSize + 5));
    expect(data.finishedBooks, hasLength(2));
    expect(repository.lastSessionLimit, readingStatsPageSize * 2);
    expect(repository.lastBookLimit, readingStatsPageSize);
    expect(data.streamError, isNull);
  });

  test('data terakhir dipertahankan saat stream gagal diperbarui', () async {
    final FakeReadingStatsRepository repository = FakeReadingStatsRepository();
    repository.sessions.add(
      _session('session-1', startedAt: DateTime(2026, 10, 23, 8)),
    );
    final ProviderContainer container = await createContainer(repository);

    expect(
      container.read(readingStatsProvider).requireValue.sessions,
      hasLength(1),
    );

    repository.sessionError = const ReadingStatsFailure(
      AppStrings.statsNetworkError,
    );
    repository.notifySessions();
    await settle();

    final ReadingStatsData data = container
        .read(readingStatsProvider)
        .requireValue;
    expect(data.sessions, hasLength(1));
    expect(data.streamError, AppStrings.statsNetworkError);
  });

  test('galat awal menampilkan state galat yang ramah', () async {
    final FakeReadingStatsRepository repository = FakeReadingStatsRepository()
      ..sessionError = const ReadingStatsFailure(
        AppStrings.statsSignInRequired,
      );

    final ProviderContainer container = await createContainer(repository);
    final AsyncValue<ReadingStatsData> state = container.read(
      readingStatsProvider,
    );

    expect(state.hasError, isTrue);
    expect(
      state.error,
      isA<ReadingStatsFailure>().having(
        (ReadingStatsFailure failure) => failure.message,
        'message',
        AppStrings.statsSignInRequired,
      ),
    );
  });

  test('retry memuat ulang data setelah galat awal', () async {
    final FakeReadingStatsRepository repository = FakeReadingStatsRepository()
      ..sessionError = const ReadingStatsFailure(AppStrings.statsNetworkError);
    final ProviderContainer container = await createContainer(repository);
    expect(container.read(readingStatsProvider).hasError, isTrue);

    repository.sessionError = null;
    repository.sessions.add(
      _session('session-1', startedAt: DateTime(2026, 10, 23, 8)),
    );
    container.read(readingStatsProvider.notifier).retry();
    await settle();

    final ReadingStatsData data = container
        .read(readingStatsProvider)
        .requireValue;
    expect(data.sessions, hasLength(1));
    expect(data.streamError, isNull);
  });
}

ReadingSession _session(String id, {required DateTime startedAt}) {
  return ReadingSession(
    id: id,
    bookId: 'book-1',
    bookTitle: 'Bumi Manusia',
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 20)),
    durationSeconds: 20 * 60,
    targetSeconds: 30 * 60,
    startPage: 40,
    endPage: 60,
  );
}

LibraryEntry _book(String id) {
  return LibraryEntry(
    bookId: id,
    status: LibraryEntry.statusFinished,
    bookTitle: 'Buku $id',
    bookAuthor: 'Penulis',
    bookTotalPages: 100,
  );
}
