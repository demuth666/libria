import 'package:cloud_firestore/cloud_firestore.dart';

/// Data pengguna pada dokumen `users/{uid}` (PRD bagian 8).
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.photoUrl,
    this.createdAt,
  });

  /// Role baku yang diberikan otomatis saat pendaftaran atau login pertama
  /// (FR-A3).
  static const String roleUser = 'user';

  /// Role yang hanya diatur manual lewat Firebase Console (PRD bagian 2).
  static const String roleAdmin = 'admin';

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String role;
  final DateTime? createdAt;

  /// `true` bila role pengguna adalah admin.
  bool get isAdmin => role == roleAdmin;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final Object? createdAtValue = map['createdAt'];
    return AppUser(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? roleUser,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
    );
  }

  /// Representasi untuk disimpan ke Firestore. `createdAt` selalu dikirim
  /// sebagai `FieldValue.serverTimestamp()` sesuai konvensi proyek, sehingga
  /// hanya sesuai dipakai saat membuat dokumen baru.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
