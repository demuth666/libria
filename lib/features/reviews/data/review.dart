import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Ulasan pada dokumen `books/{bookId}/reviews/{uid}` (PRD bagian 8).
class Review {
  const Review({
    required this.userId,
    required this.rating,
    required this.text,
    required this.userName,
    this.userPhotoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// ID dokumen `books/{bookId}/reviews/{uid}`, sekaligus UID penulis.
  final String userId;
  final int rating;
  final String text;
  final String userName;
  final String? userPhotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Review.fromMap(String userId, Map<String, dynamic> map) {
    return Review(
      userId: userId,
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      text: map['text'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userPhotoUrl: map['userPhotoUrl'] as String?,
      createdAt: dateFromFirestore(map['createdAt']),
      updatedAt: dateFromFirestore(map['updatedAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore. `createdAt` dan `updatedAt`
  /// selalu memakai server timestamp sesuai konvensi proyek.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rating': rating,
      'text': text,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
