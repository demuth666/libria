import 'dart:async';

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
