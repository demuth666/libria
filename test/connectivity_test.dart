import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/offline_banner.dart';

void main() {
  group('ConnectivityService', () {
    test('isOnline benar selama ada jaringan selain none', () {
      expect(
        ConnectivityService.isOnline(<ConnectivityResult>[
          ConnectivityResult.wifi,
        ]),
        isTrue,
      );
      expect(
        ConnectivityService.isOnline(<ConnectivityResult>[
          ConnectivityResult.mobile,
        ]),
        isTrue,
      );
      expect(
        ConnectivityService.isOnline(<ConnectivityResult>[
          ConnectivityResult.ethernet,
        ]),
        isTrue,
      );
      expect(
        ConnectivityService.isOnline(<ConnectivityResult>[
          ConnectivityResult.none,
        ]),
        isFalse,
      );
    });

    test(
      'statusChanges memancarkan status awal lalu setiap perubahan',
      () async {
        final StreamController<List<ConnectivityResult>> changes =
            StreamController<List<ConnectivityResult>>();
        addTearDown(changes.close);
        final ConnectivityService service = ConnectivityService(
          connectivity: _FakeConnectivity(
            initial: <ConnectivityResult>[ConnectivityResult.wifi],
            events: changes.stream,
          ),
        );

        final Future<void> expectation = expectLater(
          service.statusChanges,
          emitsInOrder(<bool>[true, false, true]),
        );

        await pumpEventQueue();
        changes
          ..add(<ConnectivityResult>[ConnectivityResult.none])
          ..add(<ConnectivityResult>[ConnectivityResult.mobile]);
        await expectation;
      },
    );

    test('pemeriksaan awal yang gagal dianggap online', () async {
      final ConnectivityService service = ConnectivityService(
        connectivity: _FakeConnectivity(
          initial: <ConnectivityResult>[ConnectivityResult.none],
          events: const Stream<List<ConnectivityResult>>.empty(),
          failOnCheck: true,
        ),
      );

      await expectLater(service.statusChanges, emits(true));
    });
  });

  final Map<String, ThemeData> themes = <String, ThemeData>{
    'terang': AppTheme.light,
    'gelap': AppTheme.dark,
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    testWidgets('Banner offline muncul dan hilang mengikuti status koneksi '
        'pada tema ${entry.key}', (WidgetTester tester) async {
      final StreamController<bool> status = StreamController<bool>();
      addTearDown(status.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((Ref ref) => status.stream),
          ],
          child: MaterialApp(
            theme: entry.value,
            builder: (BuildContext context, Widget? child) =>
                OfflineBannerHost(child: child ?? const SizedBox.shrink()),
            home: const Scaffold(body: Text('Konten')),
          ),
        ),
      );

      // Selama status belum diketahui, banner belum tampil.
      expect(find.byType(OfflineBanner), findsNothing);

      // Satu pump untuk memproses event stream, satu pump untuk membangun
      // ulang widget setelah provider berubah.
      status.add(false);
      await tester.pump();
      await tester.pump();
      expect(find.text(AppStrings.offlineBanner), findsOneWidget);
      expect(find.text('Konten'), findsOneWidget);

      status.add(true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(OfflineBanner), findsNothing);
    });
  }
}

/// `Connectivity` tiruan agar uji tidak memanggil plugin platform.
class _FakeConnectivity implements Connectivity {
  _FakeConnectivity({
    required this.initial,
    required this.events,
    this.failOnCheck = false,
  });

  final List<ConnectivityResult> initial;
  final Stream<List<ConnectivityResult>> events;
  final bool failOnCheck;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (failOnCheck) {
      throw Exception('konektivitas tidak tersedia');
    }
    return initial;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => events;
}
