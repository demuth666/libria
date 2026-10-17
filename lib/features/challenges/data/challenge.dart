import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Tantangan pada dokumen `challenges/{challengeId}` (PRD bagian 8).
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.createdBy,
    this.startDate,
    this.endDate,
    this.participantCount = 0,
    this.createdAt,
  });

  static const String typeBooks = 'books';
  static const String typeMinutes = 'minutes';

  /// ID dokumen `challenges/{challengeId}`.
  final String id;
  final String title;
  final String description;
  final String type;
  final int targetValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final int participantCount;
  final String createdBy;
  final DateTime? createdAt;

  factory Challenge.fromMap(String id, Map<String, dynamic> map) {
    return Challenge(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: map['type'] as String? ?? typeBooks,
      targetValue: (map['targetValue'] as num?)?.toInt() ?? 0,
      startDate: dateFromFirestore(map['startDate']),
      endDate: dateFromFirestore(map['endDate']),
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 0,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: dateFromFirestore(map['createdAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore. `createdAt` selalu memakai
  /// server timestamp sesuai konvensi proyek.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'type': type,
      'targetValue': targetValue,
      'startDate': timestampToFirestore(startDate),
      'endDate': timestampToFirestore(endDate),
      'participantCount': participantCount,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
