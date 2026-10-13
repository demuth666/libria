/// Nama koleksi Firestore sesuai PRD bagian 8.
///
/// Berisi nama koleksi tingkat atas dan subkoleksi. Pembentukan path lengkap
/// (misalnya `users/{uid}/library`) dilakukan di repository fitur terkait.
class FirestorePaths {
  const FirestorePaths._();

  // Koleksi tingkat atas.
  static const String users = 'users';
  static const String books = 'books';
  static const String posts = 'posts';
  static const String reports = 'reports';
  static const String events = 'events';
  static const String challenges = 'challenges';
  static const String isbnLogs = 'isbn_logs';

  // Subkoleksi users/{uid}.
  static const String library = 'library';
  static const String sessions = 'sessions';
  static const String journals = 'journals';
  static const String notifications = 'notifications';

  // Subkoleksi books/{bookId}.
  static const String reviews = 'reviews';

  // Subkoleksi posts/{postId}.
  static const String replies = 'replies';
  static const String likes = 'likes';

  // Subkoleksi events/{eventId} dan challenges/{challengeId}.
  static const String participants = 'participants';
}
