import 'package:libria/core/utils/firestore_value.dart';
import 'package:libria/core/utils/isbn.dart';

/// Log ISBN pada dokumen `isbn_logs/{isbn}` (PRD bagian 8).
class IsbnLog {
  IsbnLog({
    required String isbn,
    this.scanCount = 1,
    this.lastScannedAt,
    this.lastScannedBy = '',
    this.handled = false,
  }) : isbn = Isbn.normalize(isbn);

  /// ISBN ternormalisasi sekaligus ID dokumen `isbn_logs/{isbn}`.
  ///
  /// Normalisasi memakai [Isbn.normalize] agar variasi spasi, tanda hubung,
  /// dan huruf `x` kecil selalu menunjuk dokumen log yang sama.
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
