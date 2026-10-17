import 'package:cloud_firestore/cloud_firestore.dart';

/// Membaca nilai tanggal dari Firestore.
///
/// Firestore mengembalikan [Timestamp], sedangkan nilai tanggal yang belum
/// terkirim ke server dapat berupa [DateTime]. Keduanya diterima agar model
/// dapat dipakai untuk data server maupun data lokal.
DateTime? dateFromFirestore(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

/// Mengubah [DateTime] menjadi [Timestamp] yang siap ditulis ke Firestore.
Timestamp? timestampToFirestore(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}
