import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Peserta tantangan pada dokumen
/// `challenges/{challengeId}/participants/{uid}` (PRD bagian 8).
class ChallengeParticipant {
  const ChallengeParticipant({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.progress = 0,
    this.joinedAt,
  });

  /// ID dokumen `challenges/{challengeId}/participants/{uid}`.
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final int progress;
  final DateTime? joinedAt;

  factory ChallengeParticipant.fromMap(
    String userId,
    Map<String, dynamic> map,
  ) {
    return ChallengeParticipant(
      userId: userId,
      userName: map['userName'] as String? ?? '',
      userPhotoUrl: map['userPhotoUrl'] as String?,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      joinedAt: dateFromFirestore(map['joinedAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore.
  ///
  /// `joinedAt` diisi server timestamp bila belum ada.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'progress': progress,
      'joinedAt': joinedAt == null
          ? FieldValue.serverTimestamp()
          : timestampToFirestore(joinedAt),
    };
  }
}
