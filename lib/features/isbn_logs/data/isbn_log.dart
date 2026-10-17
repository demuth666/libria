import 'package:libria/core/utils/firestore_value.dart';

/// Log ISBN pada dokumen `isbn_logs/{isbn}` (PRD bagian 8).
class IsbnLog {
  const IsbnLog({
    required this.isbn,
    this.scanCount = 1,
    this.lastScannedAt,
    this.lastScannedBy = '',
    this.handled = false,
  });

  /// ISBN sekaligus ID dokumen `isbn_logs/{isbn}`.
  final String isbn;
  final int scanCount;
  final DateTime? lastScannedAt;
  final String lastScannedBy;
  final bool handled;

  factory IsbnLog.fromMap(String isbn, Map<String, dynamic> map) {
    return IsbnLog(
      isbn: isbn,
      scanCount: (map['scanCount'] as num?)?.toInt() ?? 1,
      lastScannedAt: dateFromFirestore(map['lastScannedAt']),
      lastScannedBy: map['lastScannedBy'] as String? ?? '',
      handled: map['handled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'isbn': isbn,
      'scanCount': scanCount,
      'lastScannedAt': timestampToFirestore(lastScannedAt),
      'lastScannedBy': lastScannedBy,
      'handled': handled,
    };
  }
}
