import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Entri rak pada dokumen `users/{uid}/library/{bookId}` (PRD bagian 8).
class LibraryEntry {
  const LibraryEntry({
    required this.bookId,
    required this.status,
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookTotalPages,
    this.currentPage = 0,
    this.bookCoverUrl,
    this.addedAt,
    this.finishedAt,
  });

  static const String statusWant = 'want';
  static const String statusReading = 'reading';
  static const String statusFinished = 'finished';

  /// ID dokumen `users/{uid}/library/{bookId}`.
  final String bookId;
  final String status;
  final int currentPage;
  final String bookTitle;
  final String bookAuthor;
  final String? bookCoverUrl;
  final int bookTotalPages;
  final DateTime? addedAt;
  final DateTime? finishedAt;

  factory LibraryEntry.fromMap(String bookId, Map<String, dynamic> map) {
    return LibraryEntry(
      bookId: bookId,
      status: map['status'] as String? ?? statusWant,
      currentPage: (map['currentPage'] as num?)?.toInt() ?? 0,
      bookTitle: map['bookTitle'] as String? ?? '',
      bookAuthor: map['bookAuthor'] as String? ?? '',
      bookCoverUrl: map['bookCoverUrl'] as String?,
      bookTotalPages: (map['bookTotalPages'] as num?)?.toInt() ?? 0,
      addedAt: dateFromFirestore(map['addedAt']),
      finishedAt: dateFromFirestore(map['finishedAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore.
  ///
  /// `addedAt` diisi server timestamp bila belum ada. `finishedAt` ditulis
  /// sesuai nilai model agar tanggal selesai tidak berubah saat entri dibaca
  /// ulang.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'status': status,
      'currentPage': currentPage,
      'addedAt': addedAt == null
          ? FieldValue.serverTimestamp()
          : timestampToFirestore(addedAt),
      'finishedAt': timestampToFirestore(finishedAt),
      'bookTitle': bookTitle,
      'bookAuthor': bookAuthor,
      'bookCoverUrl': bookCoverUrl,
      'bookTotalPages': bookTotalPages,
    };
  }
}
