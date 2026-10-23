import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/session_alarm_service.dart';

/// Layanan alarm palsu yang mencatat setiap penyelarasan sesi.
///
/// Dipakai uji pengendali sesi aktif agar tidak menyentuh plugin notifikasi
/// lokal atau getar.
class FakeSessionAlarmService implements SessionAlarmService {
  final List<ActiveSession?> syncedSessions = <ActiveSession?>[];
  final List<bool> permissionRequests = <bool>[];
  final List<bool> targetAnnouncements = <bool>[];
  int cancelCalls = 0;

  void Function()? _onTargetReached;

  ActiveSession? get lastSession =>
      syncedSessions.isEmpty ? null : syncedSessions.last;

  bool get lastPermissionRequest =>
      permissionRequests.isEmpty ? false : permissionRequests.last;

  bool get lastTargetAnnouncement =>
      targetAnnouncements.isEmpty ? false : targetAnnouncements.last;

  /// Memicu callback target layaknya timer alarm asli.
  void fireTargetReached() => _onTargetReached?.call();

  @override
  Future<void> sync(
    ActiveSession? session, {
    bool requestPermissions = false,
    bool announceTargetReached = false,
    void Function()? onTargetReached,
  }) async {
    syncedSessions.add(session);
    permissionRequests.add(requestPermissions);
    targetAnnouncements.add(announceTargetReached);
    _onTargetReached = onTargetReached;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
  }
}
