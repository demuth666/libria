import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../books/data/book.dart';
import '../../books/data/book_repository.dart';
import '../../library/data/library_entry.dart';
import '../../library/presentation/library_providers.dart';
import '../../session/data/reading_session.dart';
import '../data/home_activity.dart';
import '../data/home_repository.dart';

/// Ringkasan menit dan halaman membaca untuk hari ini.
///
/// Dibuang saat Beranda tidak lagi mendengarkan agar membuka kembali tab
/// Beranda mengambil snapshot terbaru, termasuk data cache saat offline.
final StreamProvider<HomeTodaySummary> todayReadingSummaryProvider =
    StreamProvider.autoDispose<HomeTodaySummary>((Ref ref) {
      final HomeRepository repository = ref.watch(homeRepositoryProvider);
      return repository.watchTodaySummary();
    }, retry: (int retryCount, Object error) => null);

/// Sumber waktu Beranda.
///
/// Dapat diganti pada uji agar ringkasan pekan ini dan target harian tidak
/// bergantung pada jam perangkat.
final Provider<DateTime Function()> homeClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Sesi membaca dalam dua pekan terakhir untuk kartu aktivitas Beranda.
final StreamProvider<List<ReadingSession>> homeRecentSessionsProvider =
    StreamProvider.autoDispose<List<ReadingSession>>((Ref ref) {
      final HomeRepository repository = ref.watch(homeRepositoryProvider);
      final DateTime now = ref.watch(homeClockProvider)();
      return repository.watchRecentSessions(now: now);
    }, retry: (int retryCount, Object error) => null);

/// Ringkasan aktivitas pekan ini yang menggabungkan sesi dan rak pengguna.
///
/// Data baru dianggap siap setelah kedua sumber memiliki nilai. Galat awal
/// pada salah satu sumber diteruskan agar Beranda dapat menampilkan pesan dan
/// tombol Coba Lagi; galat pembaruan rak tetap memakai data terakhir.
final Provider<AsyncValue<HomeActivitySummary>> homeActivityProvider =
    Provider.autoDispose<AsyncValue<HomeActivitySummary>>((Ref ref) {
      final AsyncValue<List<ReadingSession>> sessions = ref.watch(
        homeRecentSessionsProvider,
      );
      final AsyncValue<LibraryShelfData> shelf = ref.watch(
        libraryShelfProvider,
      );

      if (sessions.hasError) {
        return AsyncError<HomeActivitySummary>(
          sessions.error!,
          sessions.stackTrace ?? StackTrace.empty,
        );
      }
      if (!sessions.hasValue) {
        return const AsyncLoading<HomeActivitySummary>();
      }

      return AsyncData<HomeActivitySummary>(
        HomeActivityCalculator.summarize(
          sessions: sessions.requireValue,
          libraryEntries: shelf.value?.entries ?? const <LibraryEntry>[],
          today: ref.watch(homeClockProvider)(),
        ),
      );
    });

/// Buku terbaru untuk bagian "Rekomendasi Untuk Anda".
final FutureProvider<List<Book>> homeRecommendedBooksProvider =
    FutureProvider.autoDispose<List<Book>>((Ref ref) async {
      final BookRepository repository = ref.watch(bookRepositoryProvider);
      final BookPage page = await repository.fetchPage(limit: 6);
      return page.books;
    }, retry: (int retryCount, Object error) => null);

/// Kutipan yang berganti setiap hari tanpa memerlukan jaringan.
final Provider<({String text, String source})> homeDailyQuoteProvider =
    Provider<({String text, String source})>((Ref ref) {
      final DateTime now = ref.watch(homeClockProvider)();
      final int dayOfYear = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(now.year)).inDays;
      final List<({String text, String source})> quotes = AppStrings.homeQuotes;
      return quotes[dayOfYear % quotes.length];
    });
