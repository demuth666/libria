import 'dart:async';

/// Melepas penantian konfirmasi server pada penulisan Firestore saat offline.
///
/// Firestore menerapkan `set`, `update`, dan `commit` ke cache lokal segera
/// setelah dipanggil, lalu mengantrekan penulisan ke server. Akan tetapi
/// [Future] dari operasi tersebut baru selesai setelah server mengonfirmasi,
/// sehingga menunggunya saat perangkat offline membuat layar berhenti pada
/// keadaan "Menyimpan..." sampai koneksi pulih.
///
/// Fungsi ini dipakai hanya ketika perangkat diketahui offline. Penulisan
/// tetap dijalankan dan masuk antrean Firestore; kegagalan yang baru diketahui
/// setelah koneksi pulih tidak dapat dilaporkan pada aksi ini, sehingga layar
/// menampilkan pemberitahuan bahwa data tersimpan di perangkat.
void queueOfflineWrite(Future<void> write) {
  unawaited(
    write.then<void>(
      (void value) {},
      // Penolakan dari server setelah koneksi pulih tidak dapat ditampilkan di
      // layar yang mungkin sudah ditutup. Data lokal tetap ada sampai
      // Firestore memproses ulang antreannya.
      onError: (Object error, StackTrace stackTrace) {},
    ),
  );
}
