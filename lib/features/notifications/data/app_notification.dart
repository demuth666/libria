import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Notifikasi pada dokumen `users/{uid}/notifications/{notifId}`
/// (PRD bagian 8).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.refType,
    required this.refId,
    required this.text,
    this.actorId,
    this.actorName,
    this.read = false,
    this.createdAt,
  });

  static const String typeReply = 'reply';
  static const String typeLike = 'like';
  static const String typeEvent = 'event';
  static const String typeChallenge = 'challenge';
  static const String typeReport = 'report';

  /// ID dokumen `users/{uid}/notifications/{notifId}`.
  final String id;
  final String type;
  final String? actorId;
  final String? actorName;

  /// Jenis dokumen yang dirujuk, misalnya `post`, `event`, atau `challenge`.
  final String refType;
  final String refId;
  final String text;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: map['type'] as String? ?? typeReply,
      actorId: map['actorId'] as String?,
      actorName: map['actorName'] as String?,
      refType: map['refType'] as String? ?? '',
      refId: map['refId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      createdAt: dateFromFirestore(map['createdAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore. `createdAt` selalu memakai
  /// server timestamp sesuai konvensi proyek.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type,
      'actorId': actorId,
      'actorName': actorName,
      'refType': refType,
      'refId': refId,
      'text': text,
      'read': read,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
