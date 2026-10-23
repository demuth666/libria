import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/stats/data/reading_stats_repository.dart';

void main() {
  test('memetakan galat jaringan menjadi pesan koneksi', () {
    expect(
      ReadingStatsRepository.mapFirestoreReadError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      AppStrings.statsNetworkError,
    );
    expect(
      ReadingStatsRepository.mapFirestoreReadError(
        FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded'),
      ),
      AppStrings.statsNetworkError,
    );
  });

  test('memetakan galat izin dan sesi menjadi pesan yang sesuai', () {
    expect(
      ReadingStatsRepository.mapFirestoreReadError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      AppStrings.statsPermissionDenied,
    );
    expect(
      ReadingStatsRepository.mapFirestoreReadError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
      ),
      AppStrings.statsSignInRequired,
    );
  });

  test('memakai pesan umum untuk galat lain', () {
    expect(
      ReadingStatsRepository.mapFirestoreReadError(
        FirebaseException(plugin: 'cloud_firestore', code: 'internal'),
      ),
      AppStrings.statsLoadError,
    );
  });
}
