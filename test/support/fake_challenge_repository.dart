import 'dart:async';

import 'package:libria/features/challenges/data/challenge.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';

/// Membuat tantangan contoh untuk uji daftar dan formulir admin.
Challenge fakeChallenge(
  int index, {
  String? title,
  String? description,
  String type = Challenge.typeBooks,
  int? targetValue,
  DateTime? startDate,
  DateTime? endDate,
  int participantCount = 0,
  String createdBy = 'admin-1',
  DateTime? createdAt,
}) {
  return Challenge(
    id: 'challenge-$index',
    title: title ?? 'Tantangan $index',
    description: description ?? 'Deskripsi tantangan $index.',
    type: type,
    targetValue: targetValue ?? index + 1,
    startDate: startDate ?? DateTime(2026, 11, 1),
    endDate: endDate ?? DateTime(2026, 11, 30),
    participantCount: participantCount,
    createdBy: createdBy,
    createdAt: createdAt ?? DateTime(2026, 10, 1).add(Duration(days: index)),
  );
}

/// Repository tantangan palsu tanpa Firestore atau Auth.
///
/// [pages] dipakai bila uji butuh lebih dari satu halaman; setiap pemanggilan
/// [fetchChallengesPage] mengambil halaman berikutnya. Bila [pages] kosong,
/// seluruh [challenges] dikembalikan sebagai satu halaman.
class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository({List<Challenge>? challenges})
    : challenges = List<Challenge>.of(challenges ?? <Challenge>[]);

  final List<Challenge> challenges;
  List<List<Challenge>>? pages;

  int fetchPageCalls = 0;
  int fetchPageFailuresRemaining = 0;
  Object? fetchError;
  Completer<void>? fetchPageGate;
  final List<int> requestedLimits = <int>[];

  int getByIdCalls = 0;
  Object? getByIdError;

  int createCalls = 0;
  String? lastCreatedTitle;
  String? lastCreatedDescription;
  String? lastCreatedType;
  int? lastCreatedTargetValue;
  DateTime? lastCreatedStartDate;
  DateTime? lastCreatedEndDate;
  Object? createError;
  Completer<void>? createGate;

  int updateCalls = 0;
  String? lastUpdatedId;
  String? lastUpdatedTitle;
  String? lastUpdatedDescription;
  String? lastUpdatedType;
  int? lastUpdatedTargetValue;
  DateTime? lastUpdatedStartDate;
  DateTime? lastUpdatedEndDate;
  Object? updateError;
  Completer<void>? updateGate;

  int deleteCalls = 0;
  String? lastDeletedId;
  Object? deleteError;
  Completer<void>? deleteGate;

  int _autoIncrement = 0;

  @override
  Future<ChallengePage> fetchChallengesPage({
    int limit = challengePageSize,
    ChallengeCursor? cursor,
  }) async {
    fetchPageCalls++;
    requestedLimits.add(limit);
    if (fetchPageGate != null) {
      await fetchPageGate!.future;
    }
    if (fetchPageFailuresRemaining > 0) {
      fetchPageFailuresRemaining--;
      throw StateError('Gagal memuat tantangan.');
    }
    if (fetchError != null) {
      throw fetchError!;
    }

    final List<List<Challenge>>? configuredPages = pages;
    if (configuredPages != null && configuredPages.isNotEmpty) {
      int index = fetchPageCalls - 1;
      if (index >= configuredPages.length) {
        index = configuredPages.length - 1;
      }
      return ChallengePage(
        challenges: List<Challenge>.of(configuredPages[index]),
        hasMore: index < configuredPages.length - 1,
      );
    }

    return ChallengePage(
      challenges: List<Challenge>.of(challenges),
      hasMore: false,
    );
  }

  @override
  Future<Challenge?> getById(String challengeId) async {
    getByIdCalls++;
    if (getByIdError != null) {
      throw getByIdError!;
    }
    for (final Challenge challenge in challenges) {
      if (challenge.id == challengeId) {
        return challenge;
      }
    }
    return null;
  }

  @override
  Future<String> createChallenge({
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    createCalls++;
    lastCreatedTitle = title;
    lastCreatedDescription = description;
    lastCreatedType = type;
    lastCreatedTargetValue = targetValue;
    lastCreatedStartDate = startDate;
    lastCreatedEndDate = endDate;
    if (createGate != null) {
      await createGate!.future;
    }
    if (createError != null) {
      throw createError!;
    }
    final Challenge created = Challenge(
      id: 'challenge-${challenges.length + ++_autoIncrement}',
      title: title.trim(),
      description: description.trim(),
      type: type,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
      createdBy: 'admin-1',
      createdAt: DateTime(2026, 10, 24, 12),
    );
    challenges.insert(0, created);
    return created.id;
  }

  @override
  Future<void> updateChallenge({
    required String challengeId,
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    updateCalls++;
    lastUpdatedId = challengeId;
    lastUpdatedTitle = title;
    lastUpdatedDescription = description;
    lastUpdatedType = type;
    lastUpdatedTargetValue = targetValue;
    lastUpdatedStartDate = startDate;
    lastUpdatedEndDate = endDate;
    if (updateGate != null) {
      await updateGate!.future;
    }
    if (updateError != null) {
      throw updateError!;
    }
    final int index = challenges.indexWhere(
      (Challenge challenge) => challenge.id == challengeId,
    );
    if (index >= 0) {
      final Challenge existing = challenges[index];
      challenges[index] = Challenge(
        id: existing.id,
        title: title.trim(),
        description: description.trim(),
        type: type,
        targetValue: targetValue,
        startDate: startDate,
        endDate: endDate,
        participantCount: existing.participantCount,
        createdBy: existing.createdBy,
        createdAt: existing.createdAt,
      );
    }
  }

  @override
  Future<void> deleteChallenge(String challengeId) async {
    deleteCalls++;
    lastDeletedId = challengeId;
    if (deleteGate != null) {
      await deleteGate!.future;
    }
    if (deleteError != null) {
      throw deleteError!;
    }
    challenges.removeWhere(
      (Challenge challenge) => challenge.id == challengeId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
