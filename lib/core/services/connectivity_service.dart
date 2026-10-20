import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Layanan status konektivitas perangkat berbasis `connectivity_plus`.
///
/// `connectivity_plus` melaporkan jenis jaringan yang tersedia, bukan apakah
/// internet benar-benar dapat dijangkau. Karena itu layanan ini hanya
/// membedakan "ada koneksi" dari "tidak ada koneksi sama sekali".
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Status koneksi saat ini, lalu setiap perubahannya.
  ///
  /// Emisi pertama adalah hasil pemeriksaan langsung supaya banner offline
  /// sudah benar saat aplikasi dibuka dalam keadaan tanpa koneksi; emisi
  /// berikutnya mengikuti perubahan konektivitas perangkat.
  Stream<bool> get statusChanges async* {
    yield await _currentStatus();
    yield* _connectivity.onConnectivityChanged.map(isOnline).distinct();
  }

  /// `true` bila hasil pemeriksaan memuat jaringan selain `none`.
  static bool isOnline(List<ConnectivityResult> results) {
    return results.any(
      (ConnectivityResult result) => result != ConnectivityResult.none,
    );
  }

  /// Status saat ini.
  ///
  /// Bila pemeriksaan gagal, perangkat dianggap online agar banner offline
  /// tidak salah tampil dan unggahan tetap dicoba.
  Future<bool> isConnected() async {
    try {
      return isOnline(await _connectivity.checkConnectivity());
    } on Exception {
      return true;
    }
  }

  Future<bool> _currentStatus() => isConnected();
}

/// Status koneksi perangkat untuk dipakai bersama seluruh layar.
///
/// Bernilai `true` saat perangkat memiliki koneksi (wifi, seluler, ethernet,
/// atau lainnya) dan `false` saat tidak ada koneksi. Selama status belum
/// diketahui (loading atau gagal diperiksa), nilai belum dapat dipastikan;
/// pemakai memperlakukannya sebagai online.
final StreamProvider<bool> connectivityProvider = StreamProvider<bool>(
  (Ref ref) => ConnectivityService().statusChanges,
);
