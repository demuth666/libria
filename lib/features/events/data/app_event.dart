import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Kegiatan pada dokumen `events/{eventId}` (PRD bagian 8).
class AppEvent {
  const AppEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.createdBy,
    this.startAt,
    this.participantCount = 0,
    this.createdAt,
  });

  /// ID dokumen `events/{eventId}`.
  final String id;
  final String title;
  final String description;
  final DateTime? startAt;

  /// Lokasi fisik atau tautan kegiatan (FR-E1).
  final String location;
  final int participantCount;
  final String createdBy;
  final DateTime? createdAt;

  factory AppEvent.fromMap(String id, Map<String, dynamic> map) {
    return AppEvent(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      startAt: dateFromFirestore(map['startAt']),
      location: map['location'] as String? ?? '',
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
      'startAt': timestampToFirestore(startAt),
      'location': location,
      'participantCount': participantCount,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
