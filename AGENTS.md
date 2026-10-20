# AGENTS.md - Panduan Agent AI untuk Libria

Baca dokumen ini sebelum mengerjakan task apa pun. Baca juga `PRD.md` (apa yang dibuat) dan `TASKS.md` (urutan kerja).

## 1. Ringkasan proyek

Libria adalah aplikasi membaca berbasis Android yang dibuat dengan Flutter. Satu aplikasi melayani dua role (user dan admin) dengan routing berdasarkan role. Antarmuka berbahasa Indonesia. Mendukung offline dan dark mode. Backend memakai Firebase (tidak ada server buatan sendiri).

## 2. Stack

| Kebutuhan | Paket |
|---|---|
| State management | flutter_riverpod |
| Routing | go_router |
| Auth | firebase_core, firebase_auth, google_sign_in |
| Database | cloud_firestore (persistensi offline aktif) |
| File gambar | cloudinary_public, image_picker, cached_network_image |
| Scan ISBN | mobile_scanner |
| Timer latar belakang | flutter_foreground_task |
| Notifikasi lokal dan alarm | flutter_local_notifications, timezone |
| Getar | vibration |
| Grafik statistik | fl_chart |
| Laporan PDF | pdf, printing |
| Penyimpanan lokal kecil | shared_preferences |
| Format tanggal | intl (locale id_ID) |
| Konektivitas | connectivity_plus |

Aturan paket:
- Pasang dengan `flutter pub add <nama>` agar mendapat versi stabil terbaru yang kompatibel.
- Jangan menambah paket di luar tabel ini. Jika benar-benar perlu, tulis alasannya di bagian "Catatan" pada task terkait.
- Jangan memakai code generation (freezed, json_serializable, riverpod_generator, build_runner). Tulis model sebagai kelas Dart biasa dengan `fromMap` dan `toMap`.

## 3. Alur kerja per task

1. Baca task di `TASKS.md`, dan pastikan semua task di "Bergantung pada" sudah bertanda `[x]`.
2. Untuk task yang menyentuh UI, ambil desain layar yang sesuai dari Stitch (lihat bagian 6) sebelum menulis kode.
3. Implementasikan hanya yang diminta task. Jangan mengerjakan task lain sekaligus.
4. Jalankan `dart format .` lalu `flutter analyze`. Hasil analyze harus nol masalah.
5. Jalankan `flutter test` jika task menyebut test atau menyentuh logika.
6. Centang task di `TASKS.md` (`[ ]` menjadi `[x]`) dan isi bagian "Catatan" bila ada asumsi atau penyimpangan.
7. Commit dengan pesan `T-0xx: judul task`.

Jika ada yang ambigu, pilih opsi paling sederhana yang tidak bertentangan dengan PRD, catat asumsinya di "Catatan", lalu lanjutkan. Jangan menambah fitur yang tidak ada di PRD.

## 4. Larangan emoji

Dilarang memakai emoji atau emotikon di mana pun di dalam kode: komentar, string, print/log, teks UI, nama berkas, dan pesan commit. Gunakan ikon Material (`Icons.*`) atau aset SVG untuk kebutuhan visual.

## 5. Arsitektur dan konvensi kode

Struktur folder berbasis fitur:

```
lib/
  main.dart
  app.dart
  core/
    constants/      (app_strings.dart, firestore_paths.dart)
    theme/          (app_colors.dart, app_text_styles.dart, app_theme.dart)
    router/         (app_router.dart)
    widgets/        (komponen UI bersama)
    utils/          (formatter tanggal, durasi, validator)
    services/       (connectivity, notifikasi lokal, getar)
  features/
    <nama_fitur>/
      data/         (model, repository)
      presentation/ (screens, widgets, providers)
```

Aturan:
- Nama berkas `snake_case`, kelas `PascalCase`, identifier kode dalam bahasa Inggris, teks yang tampil ke pengguna dalam bahasa Indonesia.
- Semua teks UI diletakkan di `core/constants/app_strings.dart`, bukan ditulis langsung di widget.
- Widget tidak boleh memanggil Firestore, Auth, atau Storage secara langsung. Semua akses lewat repository, dan repository diakses lewat provider Riverpod.
- Gunakan `AsyncValue` untuk state yang dimuat dari data, dan selalu tangani tiga keadaan: loading, error, kosong.
- Tampilkan pesan error yang ramah dalam bahasa Indonesia. Jangan menampilkan stack trace ke pengguna.
- Tanggal dan waktu diformat dengan locale `id_ID`.
- Semua `createdAt` dan `updatedAt` memakai `FieldValue.serverTimestamp()`.
- Counter (jumlah like, balasan, rating) diubah dengan `FieldValue.increment` di dalam transaksi atau batch.
- Query daftar panjang (feed, katalog) wajib memakai `limit` dan paginasi.
- Jangan menaruh rahasia, kunci pribadi, atau token di repo. Berkas `google-services.json` disediakan pemilik proyek.

## 6. Acuan desain (Stitch)

Desain UI Libria ada di proyek Stitch milik pemilik proyek, dan diakses lewat Stitch MCP (server `stitch` di `opencode.json`).

Aturan:
- Stitch adalah sumber kebenaran untuk tampilan. Sebelum membuat layar atau komponen, ambil layar yang bersangkutan lewat Stitch MCP: daftar proyek, daftar layar, lalu ambil layar yang dimaksud. Hasilnya berupa HTML/CSS dan tangkapan layar.
- Stitch menghasilkan HTML/CSS (web), bukan Flutter. Jangan menyalin HTML. Baca struktur, urutan elemen, teks, warna, tipografi, radius, dan jarak, lalu terjemahkan ke widget Flutter dan token tema.
- Daftar layar Stitch dan padanannya dengan rute aplikasi dicatat di `docs/stitch-screens.md` (nama layar di Stitch, ID layar, rute di PRD bagian 4). Pakai berkas itu untuk menemukan layar yang tepat. Jika layar yang dikerjakan belum tercatat, cari lewat Stitch MCP berdasarkan nama, lalu tambahkan ke berkas itu.
- Panggilan Stitch MCP bisa dibatasi kuota. Ambil satu layar sekali, simpan hasil pentingnya (token, ukuran, teks, struktur) ke `docs/DESIGN.md` atau `docs/design/`, dan jangan memanggil ulang layar yang sama tanpa alasan.
- Jika Stitch MCP tidak tersedia, pakai berkas di `docs/design/` bila ada, dan token di `docs/DESIGN.md`.
- Warna, tipografi, radius, dan jarak hanya boleh berasal dari `lib/core/theme/`. Dilarang menulis kode warna hex atau ukuran font langsung di widget.
- Jika sebuah layar tidak ada di Stitch, gunakan spesifikasi di PRD bagian 7, dan catat di "Catatan" task bahwa layar itu belum punya desain.
- Dukung light dan dark mode untuk setiap layar. Jika Stitch hanya memuat satu mode, turunkan mode lainnya dari token yang sama secara konsisten.
- Jangan pernah menulis API key Stitch di berkas mana pun di repo. Key hanya dibaca dari variabel lingkungan.

## 7. Definisi selesai (berlaku untuk semua task)

- `flutter analyze` tanpa masalah dan `dart format` sudah dijalankan.
- Aplikasi berjalan tanpa crash pada alur yang disentuh task.
- Keadaan loading, error, dan kosong sudah ditangani.
- Tidak ada emoji, tidak ada warna atau teks yang ditulis langsung di widget.
- Task sudah dicentang di `TASKS.md` dan sudah di-commit.

## Agent skills

### Issue tracker

Issue dan spesifikasi dilacak di GitHub Issues repo ini memakai `gh`. Lihat `docs/agents/issue-tracker.md`.

### Triage labels

Lima label triage standar dipakai apa adanya. Lihat `docs/agents/triage-labels.md`.

### Domain docs

Layout single-context: `GLOSSARY.md` dan `docs/adr/` di root repo. Lihat `docs/agents/domain.md`.
