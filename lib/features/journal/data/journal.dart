import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Entri jurnal pada dokumen `users/{uid}/journals/{journalId}`
/// (PRD bagian 8).
class Journal {
  const Journal({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.content,
    this.sessionId,
    this.createdAt,
    this.updatedAt,
  });

  /// ID dokumen `users/{uid}/journals/{journalId}`.
  final String id;
  final String bookId;
  final String bookTitle;
  final String? sessionId;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Journal.fromMap(String id, Map<String, dynamic> map) {
    return Journal(
      id: id,
      bookId: map['bookId'] as String? ?? '',
      bookTitle: map['bookTitle'] as String? ?? '',
      sessionId: map['sessionId'] as String?,
      content: map['content'] as String? ?? '',
      createdAt: dateFromFirestore(map['createdAt']),
      updatedAt: dateFromFirestore(map['updatedAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore. `createdAt` dan `updatedAt`
  /// selalu memakai server timestamp sesuai konvensi proyek.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'bookId': bookId,
      'bookTitle': bookTitle,
      'sessionId': sessionId,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
