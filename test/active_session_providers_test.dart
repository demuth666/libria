import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/active_session_repository.dart';
import 'package:libria/features/session/data/session_timer_engine.dart';
import 'package:libria/features/session/presentation/active_session_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> createContainer({
    ActiveSessionRepository? repository,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        activeSessionRepositoryProvider.overrideWithValue(
          repository ?? ActiveSessionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.future);
    return container;
  }

  Future<ActiveSession> storedSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(
      ActiveSessionRepository.storageKey,
    );
    expect(raw, isNotNull);
    return ActiveSession.fromMap(jsonDecode(raw!) as Map<String, dynamic>);
  }

  test('start menyimpan sesi aktif dan menandainya berjalan', () async {
    final ProviderContainer container = await createContainer();
    final ActiveSessionController controller = container.read(
      activeSessionProvider.notifier,
    );

    await controller.start(
      bookId: 'book-1',
      bookTitle: 'Bumi Manusia',
      target: const Duration(minutes: 25),
    );

    final ActiveSession session = container
        .read(activeSessionProvider)
        .requireValue!;
    expect(session.bookId, 'book-1');
    expect(session.bookTitle, 'Bumi Manusia');
    expect(session.timer.state, SessionTimerState.running);
    expect(session.timer.target, const Duration(minutes: 25));

    final ActiveSession persisted = await storedSession();
    expect(persisted.bookId, 'book-1');
    expect(persisted.bookTitle, 'Bumi Manusia');
    expect(persisted.timer.state, SessionTimerState.running);
    expect(persisted.timer.target, const Duration(minutes: 25));
  });

  test('setiap transisi timer menulis state terbaru', () async {
    final ProviderContainer container = await createContainer();
    final ActiveSessionController controller = container.read(
      activeSessionProvider.notifier,
    );
    await controller.start(
      bookId: 'book-2',
      bookTitle: 'Laskar Pelangi',
      target: const Duration(minutes: 30),
    );

    await controller.pause();
    expect(
      container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.paused,
    );
    expect((await storedSession()).timer.state, SessionTimerState.paused);

    await controller.resume();
    expect(
      container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.running,
    );
    expect((await storedSession()).timer.state, SessionTimerState.running);

    await controller.finish();
    expect(
      container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.finished,
    );
    expect((await storedSession()).timer.state, SessionTimerState.finished);
  });

  test('provider memulihkan sesi berjalan saat aplikasi dibuka lagi', () async {
    DateTime now = DateTime(2026, 10, 23, 9);
    final ActiveSessionRepository saveRepository = ActiveSessionRepository(
      clock: () => now,
    );
    final ActiveSession session = ActiveSession.start(
      bookId: 'book-3',
      bookTitle: 'Sapiens',
      target: const Duration(hours: 5),
      clock: () => now,
    );
    now = now.add(const Duration(minutes: 5));
    await saveRepository.save(session);

    // Buang cache statis plugin untuk meniru proses aplikasi baru.
    SharedPreferences.resetStatic();
    now = DateTime(2026, 10, 23, 12);

    final ProviderContainer container = await createContainer(
      repository: ActiveSessionRepository(clock: () => now),
    );

    final ActiveSession restored = container
        .read(activeSessionProvider)
        .requireValue!;
    expect(restored.bookId, 'book-3');
    expect(restored.bookTitle, 'Sapiens');
    expect(restored.timer.state, SessionTimerState.running);
    expect(restored.timer.elapsed, const Duration(hours: 3));
  });

  test('start menolak sesi baru selama sesi aktif masih ada', () async {
    final ProviderContainer container = await createContainer();
    final ActiveSessionController controller = container.read(
      activeSessionProvider.notifier,
    );
    await controller.start(
      bookId: 'book-1',
      bookTitle: 'Bumi Manusia',
      target: const Duration(minutes: 20),
    );

    await expectLater(
      controller.start(
        bookId: 'book-2',
        bookTitle: 'Laskar Pelangi',
        target: const Duration(minutes: 20),
      ),
      throwsA(
        isA<ActiveSessionFailure>().having(
          (ActiveSessionFailure failure) => failure.message,
          'message',
          AppStrings.sessionAlreadyActive,
        ),
      ),
    );

    final ActiveSession session = container
        .read(activeSessionProvider)
        .requireValue!;
    expect(session.bookId, 'book-1');
    expect((await storedSession()).bookId, 'book-1');
  });

  test('clear menghapus state dan data tersimpan', () async {
    final ProviderContainer container = await createContainer();
    final ActiveSessionController controller = container.read(
      activeSessionProvider.notifier,
    );
    await controller.start(
      bookId: 'book-4',
      bookTitle: 'Pulang',
      target: const Duration(minutes: 10),
    );

    await controller.clear();

    expect(container.read(activeSessionProvider).requireValue, isNull);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(ActiveSessionRepository.storageKey), isNull);
  });

  test('kegagalan membaca penyimpanan tampil sebagai galat ramah', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        activeSessionRepositoryProvider.overrideWithValue(
          _LoadFailingActiveSessionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(activeSessionProvider.future),
      throwsA(isA<ActiveSessionFailure>()),
    );
    expect(container.read(activeSessionProvider).hasError, isTrue);
  });
}

class _LoadFailingActiveSessionRepository extends ActiveSessionRepository {
  @override
  Future<ActiveSession?> load() async {
    throw const ActiveSessionFailure(AppStrings.sessionActiveLoadError);
  }
}
