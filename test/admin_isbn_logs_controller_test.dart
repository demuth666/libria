import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/admin/presentation/admin_isbn_logs_providers.dart';
import 'package:libria/features/isbn_logs/data/isbn_log.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';

import 'support/fake_isbn_log_repository.dart';

void main() {
  ProviderContainer createContainer(FakeIsbnLogRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        isbnLogRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    // Provider autoDispose dibuang tanpa pendengar; uji ini perlu
    // mempertahankan state di antara beberapa pembacaan.
    container.listen<AsyncValue<AdminIsbnLogsState>>(
      adminIsbnLogsProvider,
      (
        AsyncValue<AdminIsbnLogsState>? previous,
        AsyncValue<AdminIsbnLogsState> next,
      ) {},
    );
    return container;
  }

  test('memuat halaman pertama lalu menambahkan halaman berikutnya', () async {
    final List<IsbnLog> firstPage = List<IsbnLog>.generate(
      isbnLogPageSize,
      (int index) => fakeIsbnLog(index),
    );
    final List<IsbnLog> secondPage = <IsbnLog>[
      // Sengaja mengulang log terakhir halaman pertama untuk memastikan
      // penggabungan tidak menghasilkan duplikat.
      firstPage.last,
      ...List<IsbnLog>.generate(4, (int index) => fakeIsbnLog(index + 20)),
    ];
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
      ..pages = <List<IsbnLog>>[firstPage, secondPage];
    final ProviderContainer container = createContainer(repository);
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );

    await controller.ensureLoaded();

    AdminIsbnLogsState state = container
        .read(adminIsbnLogsProvider)
        .requireValue;
    expect(state.logs, hasLength(isbnLogPageSize));
    expect(state.hasMore, isTrue);
    expect(state.isEmpty, isFalse);
    expect(repository.requestedLimits, <int>[isbnLogPageSize]);

    await controller.loadMore();

    state = container.read(adminIsbnLogsProvider).requireValue;
    expect(state.logs, hasLength(24));
    expect(state.logs.map((IsbnLog log) => log.isbn).toSet(), hasLength(24));
    expect(state.hasMore, isFalse);
    expect(repository.fetchPageCalls, 2);
  });

  test('hanya memuat sekali saat layar dibuka berulang kali', () async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[fakeIsbnLog(1)],
    );
    final ProviderContainer container = createContainer(repository);
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );

    await controller.ensureLoaded();
    await controller.ensureLoaded();

    expect(repository.fetchPageCalls, 1);
    expect(
      container.read(adminIsbnLogsProvider).requireValue.logs,
      hasLength(1),
    );
  });

  test('daftar kosong menjadi keadaan kosong yang sah', () async {
    final ProviderContainer container = createContainer(
      FakeIsbnLogRepository(),
    );
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );

    await controller.ensureLoaded();

    final AdminIsbnLogsState state = container
        .read(adminIsbnLogsProvider)
        .requireValue;
    expect(state.logs, isEmpty);
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('galat halaman pertama dapat dipulihkan lewat muat ulang', () async {
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[fakeIsbnLog(1)],
    )..fetchPageFailuresRemaining = 1;
    final ProviderContainer container = createContainer(repository);
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );

    await controller.ensureLoaded();

    expect(container.read(adminIsbnLogsProvider).hasError, isTrue);

    await controller.reload();

    expect(container.read(adminIsbnLogsProvider).hasError, isFalse);
    expect(
      container.read(adminIsbnLogsProvider).requireValue.logs,
      hasLength(1),
    );
    expect(repository.fetchPageCalls, 2);
  });

  test(
    'galat muat lebih banyak mempertahankan baris dan bisa dicoba lagi',
    () async {
      final List<IsbnLog> firstPage = List<IsbnLog>.generate(
        isbnLogPageSize,
        (int index) => fakeIsbnLog(index),
      );
      final List<IsbnLog> secondPage = List<IsbnLog>.generate(
        2,
        (int index) => fakeIsbnLog(index + 20),
      );
      final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
        ..pages = <List<IsbnLog>>[firstPage, secondPage];
      final ProviderContainer container = createContainer(repository);
      final AdminIsbnLogsController controller = container.read(
        adminIsbnLogsProvider.notifier,
      );
      await controller.ensureLoaded();

      repository.fetchPageFailuresRemaining = 1;
      await controller.loadMore();

      AdminIsbnLogsState state = container
          .read(adminIsbnLogsProvider)
          .requireValue;
      expect(state.logs, hasLength(isbnLogPageSize));
      expect(state.loadMoreFailed, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.canLoadMore, isTrue);

      await controller.loadMore();

      state = container.read(adminIsbnLogsProvider).requireValue;
      expect(state.logs, hasLength(isbnLogPageSize + 2));
      expect(state.loadMoreFailed, isFalse);
      expect(state.hasMore, isFalse);
    },
  );

  test('menandai log membuang baris tanpa memuat ulang halaman', () async {
    final IsbnLog first = fakeIsbnLog(1);
    final IsbnLog second = fakeIsbnLog(2);
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[first, second],
    );
    final ProviderContainer container = createContainer(repository);
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );
    await controller.ensureLoaded();

    await controller.markHandled(first);

    final AdminIsbnLogsState state = container
        .read(adminIsbnLogsProvider)
        .requireValue;
    expect(state.logs, <IsbnLog>[second]);
    expect(state.markingHandledIsbns, isEmpty);
    expect(repository.markHandledCalls, 1);
    expect(repository.handledIsbns, <String>[first.isbn]);
    expect(repository.fetchPageCalls, 1);
  });

  test('klik ganda selama penyimpanan hanya menulis sekali', () async {
    final IsbnLog log = fakeIsbnLog(1);
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository(
      logs: <IsbnLog>[log],
    );
    final ProviderContainer container = createContainer(repository);
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );
    await controller.ensureLoaded();

    final Completer<void> gate = Completer<void>();
    repository.markHandledGate = gate;
    final Future<void> first = controller.markHandled(log);
    final Future<void> second = controller.markHandled(log);

    expect(repository.markHandledCalls, 1);
    expect(
      container.read(adminIsbnLogsProvider).requireValue.markingHandledIsbns,
      <String>{log.isbn},
    );

    gate.complete();
    await Future.wait(<Future<void>>[first, second]);

    final AdminIsbnLogsState state = container
        .read(adminIsbnLogsProvider)
        .requireValue;
    expect(repository.markHandledCalls, 1);
    expect(state.logs, isEmpty);
    expect(state.markingHandledIsbns, isEmpty);
  });

  test(
    'kegagalan menandai mempertahankan baris dan meneruskan galat',
    () async {
      final IsbnLog log = fakeIsbnLog(1);
      final FakeIsbnLogRepository repository =
          FakeIsbnLogRepository(logs: <IsbnLog>[log])
            ..markHandledError = const IsbnLogFailure(
              AppStrings.isbnLogHandleNetworkError,
            );
      final ProviderContainer container = createContainer(repository);
      final AdminIsbnLogsController controller = container.read(
        adminIsbnLogsProvider.notifier,
      );
      await controller.ensureLoaded();

      await expectLater(
        controller.markHandled(log),
        throwsA(
          isA<IsbnLogFailure>().having(
            (IsbnLogFailure failure) => failure.message,
            'message',
            AppStrings.isbnLogHandleNetworkError,
          ),
        ),
      );

      final AdminIsbnLogsState state = container
          .read(adminIsbnLogsProvider)
          .requireValue;
      expect(state.logs, <IsbnLog>[log]);
      expect(state.markingHandledIsbns, isEmpty);
      expect(state.isEmpty, isFalse);
    },
  );

  test('menandai baris terakhir menjadi keadaan kosong', () async {
    final IsbnLog log = fakeIsbnLog(1);
    final ProviderContainer container = createContainer(
      FakeIsbnLogRepository(logs: <IsbnLog>[log]),
    );
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );
    await controller.ensureLoaded();

    await controller.markHandled(log);

    final AdminIsbnLogsState state = container
        .read(adminIsbnLogsProvider)
        .requireValue;
    expect(state.logs, isEmpty);
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('menandai baris terakhir halaman memuat sisa antrean', () async {
    final List<IsbnLog> firstPage = <IsbnLog>[fakeIsbnLog(1)];
    final List<IsbnLog> secondPage = <IsbnLog>[fakeIsbnLog(2)];
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
      ..pages = <List<IsbnLog>>[firstPage, secondPage];
    final ProviderContainer container = createContainer(repository);
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );
    await controller.ensureLoaded();

    await controller.markHandled(firstPage.single);

    final AdminIsbnLogsState state = container
        .read(adminIsbnLogsProvider)
        .requireValue;
    expect(state.logs, <IsbnLog>[secondPage.single]);
    expect(state.hasMore, isFalse);
    expect(repository.fetchPageCalls, 2);
  });

  test(
    'halaman terlambat tidak memunculkan kembali log yang ditandai',
    () async {
      final List<IsbnLog> firstPage = List<IsbnLog>.generate(
        isbnLogPageSize,
        (int index) => fakeIsbnLog(index + 1),
      );
      final IsbnLog handled = firstPage.last;
      final IsbnLog fresh = fakeIsbnLog(isbnLogPageSize + 1);
      final List<IsbnLog> secondPage = <IsbnLog>[handled, fresh];
      final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
        ..pages = <List<IsbnLog>>[firstPage, secondPage]
        ..removeHandledFromPages = false;
      final ProviderContainer container = createContainer(repository);
      final AdminIsbnLogsController controller = container.read(
        adminIsbnLogsProvider.notifier,
      );
      await controller.ensureLoaded();

      await controller.markHandled(handled);
      await controller.loadMore();

      final AdminIsbnLogsState state = container
          .read(adminIsbnLogsProvider)
          .requireValue;
      expect(
        state.logs.map((IsbnLog log) => log.isbn).toSet(),
        isNot(contains(handled.isbn)),
      );
      expect(state.logs.map((IsbnLog log) => log.isbn), contains(fresh.isbn));
    },
  );

  test('respons halaman lama diabaikan setelah muat ulang', () async {
    final List<IsbnLog> firstPage = List<IsbnLog>.generate(
      isbnLogPageSize,
      (int index) => fakeIsbnLog(index),
    );
    final List<IsbnLog> stalePage = List<IsbnLog>.generate(
      5,
      (int index) => fakeIsbnLog(index + 20),
    );
    final List<IsbnLog> freshPage = List<IsbnLog>.generate(
      2,
      (int index) => fakeIsbnLog(index + 30),
    );
    final FakeIsbnLogRepository repository = FakeIsbnLogRepository()
      ..pages = <List<IsbnLog>>[firstPage, stalePage, freshPage];
    final ProviderContainer container = createContainer(repository);
    final AdminIsbnLogsController controller = container.read(
      adminIsbnLogsProvider.notifier,
    );
    await controller.ensureLoaded();

    final Completer<void> gate = Completer<void>();
    repository.fetchPageGate = gate;
    final Future<void> staleLoadMore = controller.loadMore();
    repository.fetchPageGate = null;
    await controller.reload();
    gate.complete();
    await staleLoadMore;

    final AdminIsbnLogsState state = container
        .read(adminIsbnLogsProvider)
        .requireValue;
    expect(state.logs, hasLength(2));
    expect(
      state.logs.map((IsbnLog log) => log.isbn),
      freshPage.map((IsbnLog log) => log.isbn),
    );
  });
}
