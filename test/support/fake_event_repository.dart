import 'dart:async';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/events/data/app_event.dart';
import 'package:libria/features/events/data/event_repository.dart';

/// Membuat kegiatan contoh untuk uji daftar dan formulir admin.
AppEvent fakeEvent(
  int index, {
  String? title,
  String? description,
  String? location,
  DateTime? startAt,
  int participantCount = 0,
  String createdBy = 'admin-1',
  DateTime? createdAt,
}) {
  return AppEvent(
    id: 'event-$index',
    title: title ?? 'Kegiatan $index',
    description: description ?? 'Deskripsi kegiatan $index.',
    startAt: startAt ?? DateTime(2026, 11, index, 19),
    location: location ?? 'Ruang Baca $index',
    participantCount: participantCount,
    createdBy: createdBy,
    createdAt: createdAt ?? DateTime(2026, 10, index),
  );
}

/// Repository kegiatan palsu tanpa Firestore atau Auth.
///
/// [pages] dipakai bila uji butuh lebih dari satu halaman; setiap pemanggilan
/// [fetchEventsPage] mengambil halaman berikutnya. Bila [pages] kosong,
/// seluruh [events] dikembalikan sebagai satu halaman.
class FakeEventRepository implements EventRepository {
  FakeEventRepository({List<AppEvent>? events})
    : events = List<AppEvent>.of(events ?? <AppEvent>[]);

  final List<AppEvent> events;
  List<List<AppEvent>>? pages;

  int fetchPageCalls = 0;
  int fetchPageFailuresRemaining = 0;
  Object? fetchError;
  Completer<void>? fetchPageGate;
  final List<int> requestedLimits = <int>[];

  int getByIdCalls = 0;
  Object? getByIdError;

  int createCalls = 0;
  String? lastCreatedTitle;
  String? lastCreatedDescription;
  DateTime? lastCreatedStartAt;
  String? lastCreatedLocation;
  Object? createError;
  Completer<void>? createGate;

  int updateCalls = 0;
  String? lastUpdatedId;
  String? lastUpdatedTitle;
  String? lastUpdatedDescription;
  DateTime? lastUpdatedStartAt;
  String? lastUpdatedLocation;
  Object? updateError;
  Completer<void>? updateGate;

  int deleteCalls = 0;
  String? lastDeletedId;
  Object? deleteError;
  Completer<void>? deleteGate;

  /// Daftar yang dikembalikan [watchUpcomingEvents]. Bila `null`, [events]
  /// disaring berdasarkan `startAt` dan diurutkan paling dekat lebih dulu.
  List<AppEvent>? upcomingEvents;
  Stream<List<AppEvent>> Function(int limit)? watchUpcomingEventsFactory;
  Object? watchUpcomingError;
  int watchUpcomingCalls = 0;
  final List<int> requestedUpcomingLimits = <int>[];

  Stream<AppEvent?> Function(String eventId)? watchEventFactory;
  Object? watchEventError;

  Stream<bool> Function(String eventId)? watchIsParticipantFactory;
  Object? watchIsParticipantError;

  final Set<String> joinedEventIds = <String>{};

  int joinCalls = 0;
  String? lastJoinedId;
  Object? joinError;
  Completer<void>? joinGate;

  int leaveCalls = 0;
  String? lastLeftId;
  Object? leaveError;
  Completer<void>? leaveGate;

  int _autoIncrement = 0;

  @override
  Future<EventPage> fetchEventsPage({
    int limit = eventPageSize,
    EventCursor? cursor,
  }) async {
    fetchPageCalls++;
    requestedLimits.add(limit);
    if (fetchPageGate != null) {
      await fetchPageGate!.future;
    }
    if (fetchPageFailuresRemaining > 0) {
      fetchPageFailuresRemaining--;
      throw StateError('Gagal memuat kegiatan.');
    }
    if (fetchError != null) {
      throw fetchError!;
    }

    final List<List<AppEvent>>? configuredPages = pages;
    if (configuredPages != null && configuredPages.isNotEmpty) {
      int index = fetchPageCalls - 1;
      if (index >= configuredPages.length) {
        index = configuredPages.length - 1;
      }
      return EventPage(
        events: List<AppEvent>.of(configuredPages[index]),
        hasMore: index < configuredPages.length - 1,
      );
    }

    return EventPage(events: List<AppEvent>.of(events), hasMore: false);
  }

  @override
  Future<AppEvent?> getById(String eventId) async {
    getByIdCalls++;
    if (getByIdError != null) {
      throw getByIdError!;
    }
    for (final AppEvent event in events) {
      if (event.id == eventId) {
        return event;
      }
    }
    return null;
  }

  @override
  Stream<List<AppEvent>> watchUpcomingEvents({
    int limit = eventPageSize,
    DateTime? now,
  }) {
    watchUpcomingCalls++;
    requestedUpcomingLimits.add(limit);
    final Stream<List<AppEvent>> Function(int limit)? factory =
        watchUpcomingEventsFactory;
    if (factory != null) {
      return factory(limit);
    }
    if (watchUpcomingError != null) {
      return Stream<List<AppEvent>>.error(watchUpcomingError!);
    }
    final List<AppEvent> source = upcomingEvents ?? events;
    final DateTime reference = now ?? DateTime.now();
    final List<AppEvent> filtered =
        source
            .where(
              (AppEvent event) =>
                  event.startAt != null && !event.startAt!.isBefore(reference),
            )
            .toList(growable: false)
          ..sort((AppEvent first, AppEvent second) {
            return first.startAt!.compareTo(second.startAt!);
          });
    return Stream<List<AppEvent>>.value(
      filtered.take(limit).toList(growable: false),
    );
  }

  @override
  Stream<AppEvent?> watchEvent(String eventId) {
    final Stream<AppEvent?> Function(String eventId)? factory =
        watchEventFactory;
    if (factory != null) {
      return factory(eventId);
    }
    if (watchEventError != null) {
      return Stream<AppEvent?>.error(watchEventError!);
    }
    AppEvent? found;
    for (final AppEvent event in events) {
      if (event.id == eventId) {
        found = event;
        break;
      }
    }
    return Stream<AppEvent?>.value(found);
  }

  @override
  Stream<bool> watchIsParticipant(String eventId) {
    final Stream<bool> Function(String eventId)? factory =
        watchIsParticipantFactory;
    if (factory != null) {
      return factory(eventId);
    }
    if (watchIsParticipantError != null) {
      return Stream<bool>.error(watchIsParticipantError!);
    }
    return Stream<bool>.value(joinedEventIds.contains(eventId));
  }

  @override
  Future<void> joinEvent(String eventId) async {
    joinCalls++;
    lastJoinedId = eventId;
    if (joinGate != null) {
      await joinGate!.future;
    }
    if (joinError != null) {
      throw joinError!;
    }
    if (events.every((AppEvent event) => event.id != eventId)) {
      throw const EventFailure(AppStrings.eventsNotFound);
    }
    if (joinedEventIds.contains(eventId)) {
      return;
    }
    joinedEventIds.add(eventId);
    _adjustParticipantCount(eventId, 1);
  }

  @override
  Future<void> leaveEvent(String eventId) async {
    leaveCalls++;
    lastLeftId = eventId;
    if (leaveGate != null) {
      await leaveGate!.future;
    }
    if (leaveError != null) {
      throw leaveError!;
    }
    if (!joinedEventIds.remove(eventId)) {
      return;
    }
    _adjustParticipantCount(eventId, -1);
  }

  void _adjustParticipantCount(String eventId, int delta) {
    void adjust(List<AppEvent> list) {
      final int index = list.indexWhere(
        (AppEvent event) => event.id == eventId,
      );
      if (index < 0) {
        return;
      }
      final AppEvent current = list[index];
      final int count = current.participantCount + delta;
      list[index] = AppEvent(
        id: current.id,
        title: current.title,
        description: current.description,
        startAt: current.startAt,
        location: current.location,
        participantCount: count < 0 ? 0 : count,
        createdBy: current.createdBy,
        createdAt: current.createdAt,
      );
    }

    adjust(events);
    final List<AppEvent>? upcoming = upcomingEvents;
    if (upcoming != null && !identical(upcoming, events)) {
      adjust(upcoming);
    }
  }

  @override
  Future<String> createEvent({
    required String title,
    required String description,
    required DateTime? startAt,
    required String location,
  }) async {
    createCalls++;
    lastCreatedTitle = title;
    lastCreatedDescription = description;
    lastCreatedStartAt = startAt;
    lastCreatedLocation = location;
    if (createGate != null) {
      await createGate!.future;
    }
    if (createError != null) {
      throw createError!;
    }
    final AppEvent created = AppEvent(
      id: 'event-${events.length + ++_autoIncrement}',
      title: title.trim(),
      description: description.trim(),
      startAt: startAt,
      location: location.trim(),
      createdBy: 'admin-1',
      createdAt: DateTime(2026, 10, 24, 12),
    );
    events.insert(0, created);
    return created.id;
  }

  @override
  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime? startAt,
    required String location,
  }) async {
    updateCalls++;
    lastUpdatedId = eventId;
    lastUpdatedTitle = title;
    lastUpdatedDescription = description;
    lastUpdatedStartAt = startAt;
    lastUpdatedLocation = location;
    if (updateGate != null) {
      await updateGate!.future;
    }
    if (updateError != null) {
      throw updateError!;
    }
    final int index = events.indexWhere(
      (AppEvent event) => event.id == eventId,
    );
    if (index >= 0) {
      final AppEvent existing = events[index];
      events[index] = AppEvent(
        id: existing.id,
        title: title.trim(),
        description: description.trim(),
        startAt: startAt,
        location: location.trim(),
        participantCount: existing.participantCount,
        createdBy: existing.createdBy,
        createdAt: existing.createdAt,
      );
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    deleteCalls++;
    lastDeletedId = eventId;
    if (deleteGate != null) {
      await deleteGate!.future;
    }
    if (deleteError != null) {
      throw deleteError!;
    }
    events.removeWhere((AppEvent event) => event.id == eventId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
