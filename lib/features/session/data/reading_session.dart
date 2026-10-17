import 'package:libria/core/utils/firestore_value.dart';

/// Data sesi membaca pada dokumen `users/{uid}/sessions/{sessionId}`
/// (PRD bagian 8).
class ReadingSession {
  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.durationSeconds,
    required this.targetSeconds,
    this.startedAt,
    this.endedAt,
    this.startPage = 0,
    this.endPage = 0,
    this.targetReached = false,
  });

  /// ID dokumen `users/{uid}/sessions/{sessionId}`.
  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int targetSeconds;
  final int startPage;
  final int endPage;
  final bool targetReached;

  factory ReadingSession.fromMap(String id, Map<String, dynamic> map) {
    return ReadingSession(
      id: id,
      bookId: map['bookId'] as String? ?? '',
      bookTitle: map['bookTitle'] as String? ?? '',
      startedAt: dateFromFirestore(map['startedAt']),
      endedAt: dateFromFirestore(map['endedAt']),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      targetSeconds: (map['targetSeconds'] as num?)?.toInt() ?? 0,
      startPage: (map['startPage'] as num?)?.toInt() ?? 0,
      endPage: (map['endPage'] as num?)?.toInt() ?? 0,
      targetReached: map['targetReached'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'bookId': bookId,
      'bookTitle': bookTitle,
      'startedAt': timestampToFirestore(startedAt),
      'endedAt': timestampToFirestore(endedAt),
      'durationSeconds': durationSeconds,
      'targetSeconds': targetSeconds,
      'startPage': startPage,
      'endPage': endPage,
      'targetReached': targetReached,
    };
  }
}
