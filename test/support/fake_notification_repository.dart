import 'dart:async';

import 'package:libria/features/notifications/data/app_notification.dart';
import 'package:libria/features/notifications/data/notification_repository.dart';

/// Membuat notifikasi contoh untuk uji daftar dan lencana.
AppNotification fakeNotification(
  int index, {
  String type = AppNotification.typeReply,
  String refType = AppNotification.refTypePost,
  String? refId,
  String? text,
  String actorId = 'user-2',
  String actorName = 'Rian Hidayat',
  bool read = false,
  DateTime? createdAt,
}) {
  return AppNotification(
    id: 'notif-$index',
    type: type,
    actorId: actorId,
    actorName: actorName,
    refType: refType,
    refId: refId ?? 'post-$index',
    text: text ?? 'Kegiatan $index',
    read: read,
    createdAt:
        createdAt ?? DateTime(2026, 10, 24, 9).add(Duration(hours: index)),
  );
}

/// Repository notifikasi palsu tanpa Firestore atau Auth.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification>? notifications})
    : notifications = List<AppNotification>.of(
        notifications ?? <AppNotification>[],
      );

  final List<AppNotification> notifications;

  final List<String> markedReadIds = <String>[];
  int markAllCalls = 0;
  int? lastLimit;
  Object? readError;
  Object? writeError;
  Completer<void>? readGate;
  Completer<void>? writeGate;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void dispose() {
    _changes.close();
  }

  /// Memancarkan daftar terbaru, misalnya setelah data diubah dari perangkat
  /// lain.
  void emit() {
    _changes.add(null);
  }

  int get unreadCount =>
      notifications.where((AppNotification n) => !n.read).length;

  @override
  Stream<List<AppNotification>> watchNotifications({
    int limit = notificationPageSize,
  }) async* {
    lastLimit = limit;
    if (readGate != null) {
      await readGate!.future;
    }
    final Object? failure = readError;
    if (failure != null) {
      throw failure;
    }
    yield _page(limit);
    await for (final _ in _changes.stream) {
      final Object? nextError = readError;
      if (nextError != null) {
        throw nextError;
      }
      yield _page(limit);
    }
  }

  @override
  Stream<int> watchUnreadCount() async* {
    if (readGate != null) {
      await readGate!.future;
    }
    final Object? failure = readError;
    if (failure != null) {
      throw failure;
    }
    yield unreadCount;
    await for (final _ in _changes.stream) {
      final Object? nextError = readError;
      if (nextError != null) {
        throw nextError;
      }
      yield unreadCount;
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    markedReadIds.add(notificationId);
    if (writeGate != null) {
      await writeGate!.future;
    }
    final Object? failure = writeError;
    if (failure != null) {
      throw failure;
    }
    final int index = notifications.indexWhere(
      (AppNotification notification) => notification.id == notificationId,
    );
    if (index >= 0 && !notifications[index].read) {
      notifications[index] = _withRead(notifications[index]);
      _changes.add(null);
    }
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    if (writeGate != null) {
      await writeGate!.future;
    }
    final Object? failure = writeError;
    if (failure != null) {
      throw failure;
    }
    int updated = 0;
    for (int index = 0; index < notifications.length; index++) {
      if (!notifications[index].read) {
        notifications[index] = _withRead(notifications[index]);
        updated++;
      }
    }
    if (updated > 0) {
      _changes.add(null);
    }
    return updated;
  }

  List<AppNotification> _page(int limit) {
    final int pageSize = limit < 1 ? 1 : limit;
    final List<AppNotification> ordered =
        List<AppNotification>.of(notifications)
          ..sort((AppNotification a, AppNotification b) {
            return _dateOf(b).compareTo(_dateOf(a));
          });
    return ordered.take(pageSize).toList(growable: false);
  }

  static DateTime _dateOf(AppNotification notification) {
    return notification.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static AppNotification _withRead(AppNotification notification) {
    return AppNotification(
      id: notification.id,
      type: notification.type,
      actorId: notification.actorId,
      actorName: notification.actorName,
      refType: notification.refType,
      refId: notification.refId,
      text: notification.text,
      read: true,
      createdAt: notification.createdAt,
    );
  }
}
