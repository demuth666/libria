import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Postingan pada dokumen `posts/{postId}` (PRD bagian 8).
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    this.authorPhotoUrl,
    this.bookId,
    this.bookTitle,
    this.likeCount = 0,
    this.replyCount = 0,
    this.createdAt,
  });

  /// ID dokumen `posts/{postId}`.
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final String? bookId;
  final String? bookTitle;
  final int likeCount;
  final int replyCount;
  final DateTime? createdAt;

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    return Post(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      content: map['content'] as String? ?? '',
      bookId: map['bookId'] as String?,
      bookTitle: map['bookTitle'] as String?,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (map['replyCount'] as num?)?.toInt() ?? 0,
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
      'bookId': bookId,
      'bookTitle': bookTitle,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
