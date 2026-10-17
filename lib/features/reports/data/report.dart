import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Laporan konten pada dokumen `reports/{reportId}` (PRD bagian 8).
class Report {
  const Report({
    required this.id,
    required this.targetType,
    required this.postId,
    required this.targetAuthorId,
    required this.targetPreview,
    required this.reason,
    required this.reporterId,
    required this.status,
    this.replyId,
    this.createdAt,
  });

  static const String targetPost = 'post';
  static const String targetReply = 'reply';

  static const String statusOpen = 'open';
  static const String statusResolved = 'resolved';
  static const String statusDismissed = 'dismissed';

  /// ID dokumen `reports/{reportId}`.
  final String id;
  final String targetType;
  final String postId;
  final String? replyId;
  final String targetAuthorId;
  final String targetPreview;
  final String reason;
  final String reporterId;
  final String status;
  final DateTime? createdAt;

  factory Report.fromMap(String id, Map<String, dynamic> map) {
    return Report(
      id: id,
      targetType: map['targetType'] as String? ?? targetPost,
      postId: map['postId'] as String? ?? '',
      replyId: map['replyId'] as String?,
      targetAuthorId: map['targetAuthorId'] as String? ?? '',
      targetPreview: map['targetPreview'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      reporterId: map['reporterId'] as String? ?? '',
      status: map['status'] as String? ?? statusOpen,
      createdAt: dateFromFirestore(map['createdAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore. `createdAt` selalu memakai
  /// server timestamp sesuai konvensi proyek.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'targetType': targetType,
      'postId': postId,
      'replyId': replyId,
      'targetAuthorId': targetAuthorId,
      'targetPreview': targetPreview,
      'reason': reason,
      'reporterId': reporterId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
