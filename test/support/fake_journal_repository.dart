import 'dart:async';

import 'package:libria/features/journal/data/journal.dart';
import 'package:libria/features/journal/data/journal_repository.dart';

/// Membuat entri jurnal contoh untuk uji daftar dan formulir Jurnal.
Journal fakeJournal(
  int index, {
  String? bookId,
  String? bookTitle,
  String? content,
  String? sessionId,
  DateTime? createdAt,
}) {
  return Journal(
    id: 'journal-$index',
    bookId: bookId ?? 'book-$index',
    bookTitle: bookTitle ?? 'Buku $index',
    content: content ?? 'Isi jurnal $index',
    sessionId: sessionId,
    createdAt: createdAt ?? DateTime(2026, 1, index),
    updatedAt: createdAt ?? DateTime(2026, 1, index),
  );
}

/// Penyimpanan jurnal palsu tanpa Firestore atau Auth.
///
/// Dipakai uji widget daftar dan formulir Jurnal agar CRUD dapat diuji tanpa
/// Firebase. Aturan validasi dipakai langsung dari [JournalRepository] karena
/// bersifat statis dan bebas dari Firestore.
class FakeJournalRepository implements JournalRepository {
  FakeJournalRepository({List<Journal>? journals})
    : journals = journals ?? <Journal>[];

  final List<Journal> journals;

  int addCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  String? lastAddedBookId;
  String? lastAddedBookTitle;
  String? lastAddedContent;
  String? lastAddedSessionId;
  String? lastUpdatedId;
  String? lastUpdatedContent;
  String? lastDeletedId;

  Object? addError;
  Object? updateError;
  Object? deleteError;
  Object? readError;

  int _autoIncrement = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void dispose() {
    _changes.close();
  }

  void _emit() {
    _changes.add(null);
  }

  @override
  Future<String> addJournal({
    required String bookId,
    required String bookTitle,
    required String content,
    String? sessionId,
  }) async {
    addCalls++;
    lastAddedBookId = bookId;
    lastAddedBookTitle = bookTitle;
    lastAddedContent = content;
    lastAddedSessionId = sessionId;
    if (addError != null) {
      throw addError!;
    }
    final String id = 'journal-new-${_autoIncrement++}';
    journals.insert(
      0,
      Journal(
        id: id,
        bookId: bookId,
        bookTitle: bookTitle,
        content: content,
        sessionId: sessionId,
        createdAt: DateTime(2026, 6, 1 + _autoIncrement),
        updatedAt: DateTime(2026, 6, 1 + _autoIncrement),
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<void> updateJournal(
    String journalId, {
    required String content,
  }) async {
    updateCalls++;
    lastUpdatedId = journalId;
    lastUpdatedContent = content;
    if (updateError != null) {
      throw updateError!;
    }
    final int index = journals.indexWhere((Journal j) => j.id == journalId);
    if (index < 0) {
      throw const JournalFailure('Jurnal tidak ditemukan.');
    }
    final Journal current = journals[index];
    journals[index] = Journal(
      id: current.id,
      bookId: current.bookId,
      bookTitle: current.bookTitle,
      content: content,
      sessionId: current.sessionId,
      createdAt: current.createdAt,
      updatedAt: DateTime(2026, 6, 15),
    );
    _emit();
  }

  @override
  Future<void> deleteJournal(String journalId) async {
    deleteCalls++;
    lastDeletedId = journalId;
    if (deleteError != null) {
      throw deleteError!;
    }
    journals.removeWhere((Journal j) => j.id == journalId);
    _emit();
  }

  @override
  Stream<List<Journal>> watchJournals({String? bookId, int limit = 20}) async* {
    if (readError != null) {
      throw readError!;
    }
    yield _page(bookId, limit);
    await for (final _ in _changes.stream) {
      if (readError != null) {
        throw readError!;
      }
      yield _page(bookId, limit);
    }
  }

  @override
  Stream<Journal?> watchJournal(String journalId) async* {
    if (readError != null) {
      throw readError!;
    }
    yield _findById(journalId);
    await for (final _ in _changes.stream) {
      if (readError != null) {
        throw readError!;
      }
      yield _findById(journalId);
    }
  }

  Journal? _findById(String journalId) {
    for (final Journal journal in journals) {
      if (journal.id == journalId) {
        return journal;
      }
    }
    return null;
  }

  List<Journal> _page(String? bookId, int limit) {
    final Iterable<Journal> filtered = bookId == null
        ? journals
        : journals.where((Journal j) => j.bookId == bookId);
    final List<Journal> ordered = filtered.toList(growable: false)
      ..sort((Journal a, Journal b) {
        final DateTime left =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime right =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return ordered.take(limit).toList(growable: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
