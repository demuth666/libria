import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/admin/presentation/admin_events_providers.dart';
import 'package:libria/features/events/data/app_event.dart';
import 'package:libria/features/events/data/event_repository.dart';

import 'support/fake_event_repository.dart';

void main() {
  ProviderContainer createContainer(FakeEventRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    // Provider autoDispose dibuang tanpa pendengar; uji ini perlu
    // mempertahankan state di antara beberapa pembacaan.
    container.listen<AsyncValue<AdminEventsState>>(
      adminEventsProvider,
      (
        AsyncValue<AdminEventsState>? previous,
        AsyncValue<AdminEventsState> next,
      ) {},
    );
    return container;
  }

  test('memuat halaman pertama lalu menambahkan halaman berikutnya', () async {
    final List<AppEvent> firstPage = List<AppEvent>.generate(
      eventPageSize,
      (int index) => fakeEvent(index),
    );
    final List<AppEvent> secondPage = <AppEvent>[
      // Sengaja mengulang kegiatan terakhir halaman pertama untuk memastikan
      // penggabungan tidak menghasilkan duplikat.
      firstPage.last,
      ...List<AppEvent>.generate(3, (int index) => fakeEvent(index + 20)),
    ];
    final FakeEventRepository repository = FakeEventRepository()
      ..pages = <List<AppEvent>>[firstPage, secondPage];
    final ProviderContainer container = createContainer(repository);
    final AdminEventsController controller = container.read(
      adminEventsProvider.notifier,
    );

    await controller.ensureLoaded();

    AdminEventsState state = container.read(adminEventsProvider).requireValue;
    expect(state.events, hasLength(eventPageSize));
    expect(state.hasMore, isTrue);

    await controller.loadMore();

    state = container.read(adminEventsProvider).requireValue;
    expect(state.events, hasLength(eventPageSize + 3));
    expect(
      state.events.map((AppEvent event) => event.id).toSet(),
      hasLength(eventPageSize + 3),
    );
    expect(state.hasMore, isFalse);
    expect(repository.fetchPageCalls, 2);
  });

  test('galat awal dapat dipulihkan lewat muat ulang', () async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[fakeEvent(1)],
    )..fetchPageFailuresRemaining = 1;
    final ProviderContainer container = createContainer(repository);
    final AdminEventsController controller = container.read(
      adminEventsProvider.notifier,
    );

    await controller.ensureLoaded();

    expect(container.read(adminEventsProvider).hasError, isTrue);

    await controller.reload();

    expect(container.read(adminEventsProvider).hasError, isFalse);
    expect(
      container.read(adminEventsProvider).requireValue.events.single.id,
      'event-1',
    );
  });

  test('menghapus kegiatan dari daftar setelah repository berhasil', () async {
    final AppEvent first = fakeEvent(1);
    final AppEvent second = fakeEvent(2);
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[first, second],
    );
    final ProviderContainer container = createContainer(repository);
    final AdminEventsController controller = container.read(
      adminEventsProvider.notifier,
    );
    await controller.ensureLoaded();

    await controller.deleteEvent(first);

    final AdminEventsState state = container
        .read(adminEventsProvider)
        .requireValue;
    expect(state.events, <AppEvent>[second]);
    expect(repository.lastDeletedId, first.id);
  });

  test('kegiatan tetap ada bila penghapusan gagal', () async {
    final AppEvent event = fakeEvent(1);
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[event],
    )..deleteError = const EventFailure('Gagal menghapus.');
    final ProviderContainer container = createContainer(repository);
    final AdminEventsController controller = container.read(
      adminEventsProvider.notifier,
    );
    await controller.ensureLoaded();

    await expectLater(
      controller.deleteEvent(event),
      throwsA(isA<EventFailure>()),
    );

    final AdminEventsState state = container
        .read(adminEventsProvider)
        .requireValue;
    expect(state.events, <AppEvent>[event]);
    expect(state.deletingEventIds, isEmpty);
  });

  test('menahan ketukan hapus ganda selama proses berjalan', () async {
    final AppEvent event = fakeEvent(1);
    final Completer<void> gate = Completer<void>();
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[event],
    )..deleteGate = gate;
    final ProviderContainer container = createContainer(repository);
    final AdminEventsController controller = container.read(
      adminEventsProvider.notifier,
    );
    await controller.ensureLoaded();

    final Future<void> first = controller.deleteEvent(event);
    await controller.deleteEvent(event);

    expect(repository.deleteCalls, 1);
    expect(
      container.read(adminEventsProvider).requireValue.deletingEventIds,
      <String>{event.id},
    );

    gate.complete();
    await first;

    expect(container.read(adminEventsProvider).requireValue.events, isEmpty);
  });
}
