import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libria/core/utils/firestore_value.dart';

/// Data buku pada dokumen `books/{bookId}` (PRD bagian 8).
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.publisher,
    required this.year,
    required this.totalPages,
    required this.category,
    required this.synopsis,
    required this.createdBy,
    this.coverUrl,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// ID dokumen `books/{bookId}`.
  final String id;
  final String title;
  final String author;
  final String isbn;
  final String publisher;
  final int year;
  final int totalPages;
  final String category;
  final String synopsis;
  final String? coverUrl;
  final double ratingAverage;
  final int ratingCount;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Judul huruf kecil untuk pencarian awalan (PRD bagian 8).
  String get titleLower => title.toLowerCase();

  /// Nama penulis huruf kecil untuk pencarian awalan (PRD bagian 8).
  String get authorLower => author.toLowerCase();

  factory Book.fromMap(String id, Map<String, dynamic> map) {
    return Book(
      id: id,
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      isbn: map['isbn'] as String? ?? '',
      publisher: map['publisher'] as String? ?? '',
      year: (map['year'] as num?)?.toInt() ?? 0,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? '',
      synopsis: map['synopsis'] as String? ?? '',
      coverUrl: map['coverUrl'] as String?,
      ratingAverage: (map['ratingAverage'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: dateFromFirestore(map['createdAt']),
      updatedAt: dateFromFirestore(map['updatedAt']),
    );
  }

  /// Representasi untuk disimpan ke Firestore.
  ///
  /// `createdAt` dan `updatedAt` selalu dikirim sebagai
  /// `FieldValue.serverTimestamp()` sesuai konvensi proyek. Method ini
  /// ditujukan untuk membuat dokumen baru; pembaruan sebagian sebaiknya
  /// memakai peta field khusus di repository.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'author': author,
      'isbn': isbn,
      'publisher': publisher,
      'year': year,
      'totalPages': totalPages,
      'category': category,
      'synopsis': synopsis,
      'coverUrl': coverUrl,
      'ratingAverage': ratingAverage,
      'ratingCount': ratingCount,
      'createdBy': createdBy,
      'titleLower': titleLower,
      'authorLower': authorLower,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
