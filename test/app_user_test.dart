import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/features/auth/data/app_user.dart';

void main() {
  group('AppUser.fromMap', () {
    test('membaca semua field dari map lengkap', () {
      final Timestamp createdAt = Timestamp.fromDate(DateTime(2024, 1, 2));
      final AppUser user = AppUser.fromMap('uid-1', <String, dynamic>{
        'displayName': 'Budi Santoso',
        'email': 'budi@contoh.com',
        'photoUrl': 'https://contoh.com/foto.png',
        'role': 'admin',
        'createdAt': createdAt,
      });

      expect(user.uid, 'uid-1');
      expect(user.displayName, 'Budi Santoso');
      expect(user.email, 'budi@contoh.com');
      expect(user.photoUrl, 'https://contoh.com/foto.png');
      expect(user.role, 'admin');
      expect(user.createdAt, createdAt.toDate());
      expect(user.isAdmin, isTrue);
    });

    test('memakai role "user" sebagai cadangan bila field role tidak ada', () {
      final AppUser user = AppUser.fromMap('uid-2', <String, dynamic>{
        'displayName': 'Siti',
        'email': 'siti@contoh.com',
      });

      expect(user.role, AppUser.roleUser);
      expect(user.isAdmin, isFalse);
      expect(user.photoUrl, isNull);
      expect(user.createdAt, isNull);
    });
  });

  group('AppUser.toMap', () {
    test(
      'menyertakan field dan FieldValue.serverTimestamp untuk createdAt',
      () {
        const AppUser user = AppUser(
          uid: 'uid-3',
          displayName: 'Dewi',
          email: 'dewi@contoh.com',
          role: AppUser.roleUser,
          photoUrl: null,
        );

        final Map<String, dynamic> map = user.toMap();

        expect(map['displayName'], 'Dewi');
        expect(map['email'], 'dewi@contoh.com');
        expect(map['photoUrl'], isNull);
        expect(map['role'], AppUser.roleUser);
        expect(map['createdAt'], isA<FieldValue>());
      },
    );
  });
}
