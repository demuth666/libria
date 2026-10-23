import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/active_session_repository.dart';
import 'package:libria/features/session/data/session_alarm_service.dart';
import 'package:libria/features/session/data/session_background_service.dart';
import 'package:libria/features/session/data/session_timer_engine.dart';
import 'package:libria/features/session/presentation/active_session_providers.dart';

import 'support/fake_session_alarm_service.dart';
import 'support/fake_session_background_service.dart';

void main() {
  late FakeSessionBackgroundService backgroundService;
  late FakeSessionAlarmService alarmService;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backgroundService = FakeSessionBackgroundService();
    alarmService = FakeSessionAlarmService();
  });

  Future<ProviderContainer> createContainer({
    ActiveSessionRepository? repository,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        activeSessionRepositoryProvider.overrideWithValue(
          repository ?? ActiveSessionRepository(),
        ),
        sessionBackgroundServiceProvider.overrideWithValue(backgroundService),
        sessionAlarmServiceProvider.overrideWithValue(alarmService),
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

    expect(backgroundService.syncedSessions, hasLength(1));
    expect(backgroundService.lastSession?.bookId, 'book-1');
    expect(backgroundService.lastPermissionRequest, isTrue);
    expect(alarmService.lastSession?.bookId, 'book-1');
    expect(alarmService.lastPermissionRequest, isTrue);
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
    expect(
      backgroundService.lastSession?.timer.state,
      SessionTimerState.paused,
    );
    expect(backgroundService.lastPermissionRequest, isFalse);

    await controller.resume();
    expect(
      container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.running,
    );
    expect((await storedSession()).timer.state, SessionTimerState.running);
    expect(
      backgroundService.lastSession?.timer.state,
      SessionTimerState.running,
    );

    await controller.finish();
    expect(
      container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.finished,
    );
    expect((await storedSession()).timer.state, SessionTimerState.finished);
    expect(
      backgroundService.lastSession?.timer.state,
      SessionTimerState.finished,
    );
    expect(backgroundService.lastPermissionRequest, isFalse);
    expect(alarmService.lastSession?.timer.state, SessionTimerState.finished);
  });

  test('target tercapai menghentikan timer dan memicu alarm sekali', () async {
    final ProviderContainer container = await createContainer();
    final ActiveSessionController controller = container.read(
      activeSessionProvider.notifier,
    );
    await controller.start(
      bookId: 'book-5',
      bookTitle: 'Bumi Manusia',
      target: const Duration(milliseconds: 60),
    );

    await Future<void>.delayed(const Duration(milliseconds: 90));
    alarmService.fireTargetReached();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final ActiveSession session = container
        .read(activeSessionProvider)
        .requireValue!;
    expect(session.timer.state, SessionTimerState.targetReached);
    expect(session.timer.elapsed, const Duration(milliseconds: 60));
    expect(
      (await storedSession()).timer.state,
      SessionTimerState.targetReached,
    );
    expect(
      alarmService.lastSession?.timer.state,
      SessionTimerState.targetReached,
    );
    expect(alarmService.lastTargetAnnouncement, isTrue);
    expect(
      alarmService.targetAnnouncements.where((bool value) => value),
      hasLength(1),
    );
  });

  test('sesi dijeda sebelum target tidak memicu alarm target', () async {
    final ProviderContainer container = await createContainer();
    final ActiveSessionController controller = container.read(
      activeSessionProvider.notifier,
    );
    await controller.start(
      bookId: 'book-6',
      bookTitle: 'Laskar Pelangi',
      target: const Duration(milliseconds: 60),
    );

    await controller.pause();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(
      container.read(activeSessionProvider).requireValue!.timer.state,
      SessionTimerState.paused,
    );
    expect(alarmService.lastSession?.timer.state, SessionTimerState.paused);
    expect(alarmService.targetAnnouncements, isNot(contains(true)));
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

    expect(backgroundService.syncedSessions, hasLength(1));
    expect(backgroundService.lastSession?.bookId, 'book-3');
    expect(backgroundService.lastPermissionRequest, isFalse);
    expect(alarmService.lastSession?.bookId, 'book-3');
    expect(alarmService.lastTargetAnnouncement, isFalse);
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
    expect(backgroundService.syncedSessions, hasLength(1));
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
    expect(backgroundService.lastSession, isNull);
    expect(alarmService.lastSession, isNull);
  });

  test('kegagalan membaca penyimpanan tampil sebagai galat ramah', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        activeSessionRepositoryProvider.overrideWithValue(
          _LoadFailingActiveSessionRepository(),
        ),
        sessionAlarmServiceProvider.overrideWithValue(alarmService),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(activeSessionProvider.future),
      throwsA(isA<ActiveSessionFailure>()),
    );
    expect(container.read(activeSessionProvider).hasError, isTrue);
    expect(backgroundService.syncedSessions, isEmpty);
  });
}

class _LoadFailingActiveSessionRepository extends ActiveSessionRepository {
  @override
  Future<ActiveSession?> load() async {
    throw const ActiveSessionFailure(AppStrings.sessionActiveLoadError);
  }
}
