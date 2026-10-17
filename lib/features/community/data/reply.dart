import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Balasan pada dokumen `posts/{postId}/replies/{replyId}`
/// (PRD bagian 8).
class Reply {
  const Reply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    this.authorPhotoUrl,
    this.createdAt,
  });

  /// ID dokumen `posts/{postId}/replies/{replyId}`.
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final DateTime? createdAt;

  factory Reply.fromMap(String id, Map<String, dynamic> map) {
    return Reply(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      content: map['content'] as String? ?? '',
      createdAt: dateFromFirestore(map['createdAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore. `createdAt` selalu memakai
  /// server timestamp sesuai konvensi proyek.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
