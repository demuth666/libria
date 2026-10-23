import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/session_background_service.dart';

/// Layanan latar belakang palsu yang mencatat setiap penyelarasan sesi.
///
/// Dipakai uji pengendali sesi aktif agar tidak menyentuh
/// `flutter_foreground_task` atau platform Android.
class FakeSessionBackgroundService implements SessionBackgroundService {
  final List<ActiveSession?> syncedSessions = <ActiveSession?>[];
  final List<bool> notificationPermissionRequests = <bool>[];

  ActiveSession? get lastSession => syncedSessions.last;

  bool get lastPermissionRequest => notificationPermissionRequests.last;

  @override
  Future<void> sync(
    ActiveSession? session, {
    bool requestNotificationPermission = false,
  }) async {
    syncedSessions.add(session);
    notificationPermissionRequests.add(requestNotificationPermission);
  }
}
