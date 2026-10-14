# TASKS - Libria

Dikerjakan berurutan oleh agent AI. Wajib membaca `AGENTS.md` dan `PRD.md` dulu. Satu task = satu commit.

Cara memakai:
- Kerjakan task yang semua "Bergantung pada"-nya sudah `[x]`.
- Untuk task UI, ambil frame Figma yang sesuai nama layar. Jika tidak ada, pakai PRD bagian 7.
- Setelah selesai: centang `[x]`, isi "Catatan" bila ada asumsi.

## Tugas manual pemilik proyek (bukan untuk agent)

- [*] M-01 Buat proyek Firebase, tambahkan aplikasi Android (package name sesuai proyek), tambahkan SHA-1 debug dan release.
- [*] M-02 Aktifkan Authentication dengan provider Google. Aktifkan Firestore (mode produksi) dan Storage.
- [*] M-03 Letakkan `google-services.json` di `android/app/`.
- [ ] M-04 Login sekali dengan akun admin, lalu ubah field `role` di dokumen `users/{uid}` menjadi `admin` lewat Firebase Console.
- [ ] M-05 Setelah T-022 selesai, deploy rules dan indexes: `firebase deploy --only firestore:rules,firestore:indexes,storage`.
- [ ] M-06 Pasang Figma MCP di OpenCode agar agent bisa membaca frame desain.
- [ ] M-07 Aktifkan provider Email/Kata Sandi di Firebase Authentication, lalu sesuaikan template email verifikasi dan reset kata sandi.

---

## Fase 0 - Fondasi

### [x] T-001 Inisialisasi proyek Flutter
- Bergantung pada: -
- Kerjakan: buat proyek Flutter khusus Android, pasang semua paket di tabel `AGENTS.md` bagian 2, buat struktur folder `lib/` sesuai `AGENTS.md` bagian 5. Atur `minSdkVersion` 26.
- Selesai jika: `flutter run` menampilkan layar placeholder, `flutter analyze` bersih.
- Catatan:
  - Proyek awal buatan `flutter create` memuat semua platform; folder `ios/`, `linux/`, `macos/`, `web/`, dan `windows/` dihapus agar sesuai proyek khusus Android, lalu `.metadata` disesuaikan.
  - `lib/app.dart` dibuat sebagai akar aplikasi (`main.dart` hanya memanggilnya) dan layar placeholder sementara ditulis di dalamnya sampai Splash (T-013) dan router (T-007) dibuat.
  - `core/constants/app_strings.dart` sudah dibuat minimal berisi `appName` agar layar placeholder tidak memuat teks langsung di widget; pengisian lengkapnya dilanjutkan pada T-003.
  - Folder struktur yang masih kosong diberi `.gitkeep` agar ikut tersimpan di git.
  - Paket `cupertino_icons` bawaan template dihapus karena tidak dipakai dan di luar tabel paket `AGENTS.md`.
  - Core library desugaring diaktifkan di `android/app/build.gradle.kts` (`desugar_jdk_libs:2.1.4`) karena `flutter_local_notifications` mewajibkannya agar aplikasi bisa dibangun.
  - `applicationId` masih `com.example.libria` (default Flutter); penyesuaian identitas rilis dilakukan pada T-099 dan pemilik memakai nilai ini untuk M-01.
  - Repo git belum tersedia, jadi diinisialisasi (`git init -b main`) dan identitas commit lokal diatur karena environment belum punya konfigurasi git pengguna.
  - Diverifikasi dengan `flutter run --no-resident` di perangkat Infinix X1201 (Android 15): APK debug terbentuk, terpasang, dan layar placeholder tampil.

### [x] T-002 Konfigurasi Firebase di aplikasi
- Bergantung pada: T-001, M-01, M-02, M-03
- Kerjakan: tambahkan plugin google-services pada Gradle, inisialisasi `Firebase.initializeApp()` di `main.dart`, bungkus aplikasi dengan `ProviderScope`, panggil `initializeDateFormatting('id_ID')`.
- Selesai jika: aplikasi berjalan tanpa error inisialisasi Firebase.
- Catatan:
  - Perubahan Gradle (plugin `com.google.gms.google-services` 4.4.2, BOM dan `firebase-analytics` di `android/app/build.gradle.kts`) serta `android/app/google-services.json` sudah disiapkan lewat M-01/M-03 tetapi belum ter-commit; semuanya disertakan dalam commit T-002. Tugas manual M-01, M-02, dan M-03 tetap `[ ]` di TASKS.md karena milik pemilik proyek.
  - Karena proyek khusus Android dan konfigurasi tersedia lewat `google-services.json`, `Firebase.initializeApp()` dipanggil tanpa `DefaultFirebaseOptions` (tanpa berkas `firebase_options.dart`).
  - Urutan startup di `main.dart`: `WidgetsFlutterBinding.ensureInitialized()`, `Firebase.initializeApp()`, `initializeDateFormatting('id_ID')`, lalu `runApp` dengan `ProviderScope` membungkus `LibriaApp`.
  - Diverifikasi dengan `flutter run --no-resident` di perangkat Infinix X1201 (Android 15): log perangkat memuat `FirebaseInitProvider: FirebaseApp initialization successful` dan aplikasi tampil tanpa error.

### [x] T-003 Konstanta string dan path Firestore
- Bergantung pada: T-001
- Kerjakan: buat `core/constants/app_strings.dart` (kerangka, diisi bertahap) dan `core/constants/firestore_paths.dart` berisi nama koleksi sesuai PRD bagian 8.
- Selesai jika: semua nama koleksi di PRD ada sebagai konstanta.
- Catatan:
  - `core/constants/app_strings.dart` sudah ada sejak T-001 (berisi `appName`); T-003 menata kerangkanya dengan penanda bagian per fitur mengikuti urutan PRD, tanpa menambah teks layar baru agar tidak mendahului task layar masing-masing.
  - `core/constants/firestore_paths.dart` memuat seluruh nama koleksi tingkat atas dan subkoleksi di PRD bagian 8. Konstanta `participants` dipakai bersama oleh `events/{eventId}` dan `challenges/{challengeId}` karena namanya sama.
  - Path Storage `covers/{bookId}` (PRD bagian 9) tidak dimasukkan karena bukan koleksi Firestore; akan ditangani pada task unggah sampul (T-033).
  - Berkas ini hanya memuat nama koleksi, tanpa helper pembentuk path; repository tiap fitur yang merangkai path seperti `users/{uid}/library`.

### [x] T-004 Token desain dan tema dari Stitch
- Bergantung pada: T-001, M-06, M-07
- Kerjakan: baca desain di Stitch lewat Stitch MCP (warna, tipografi, radius, jarak, elevasi) untuk mode terang dan gelap, dan buat docs/stitch-screens.md bila belum ada. Tulis ke docs/DESIGN.md (tabel token dan daftar layar beserta nama layar Stitch-nya) dan implementasikan di core/theme/app_colors.dart, app_text_styles.dart, app_theme.dart (Material 3, lightTheme dan darkTheme).
- Selesai jika: MaterialApp memakai kedua tema, dan docs/DESIGN.md memuat pemetaan layar ke layar Stitch.
- Catatan:
  - Desain diambil dari Stitch (project "Aesthetic Navbar Redesign") sesuai instruksi pada task ini dan AGENTS.md bagian 6. Stitch MCP dapat diakses sehingga dependensi M-06/M-07 dianggap sudah efektif; M-07 belum terdaftar sebagai tugas manual di berkas ini.
  - Empat layar utama diambil lewat Stitch MCP dan diekspor ke `docs/design/stitch/` (HTML dan tangkapan layar lebar 780 px). Delapan gambar referensi unggahan pemilik yang tersembunyi di project ikut didokumentasikan di `docs/stitch-screens.md` dan diekspor ke `docs/design/stitch/reference/`.
  - Stitch hanya menyediakan mode terang; mode gelap diturunkan dari keluarga tonal yang sama mengikuti aturan Material 3 dan dirinci di `docs/DESIGN.md` bagian 1.4.
  - Font Merriweather dan Plus Jakarta Sans dibundel di `assets/fonts/` (lisensi OFL disertakan) karena `google_fonts` tidak ada di tabel paket `AGENTS.md`.
  - Token radius, jarak, elevasi, dan warna tambahan diletakkan di `app_theme.dart` dan `app_colors.dart` (`AppRadius`, `AppSpacing`, `AppShadows`, `AppSemanticColors`) tanpa menambah berkas di luar tiga berkas yang disebut task.
  - Komponen tema mengikuti panduan Stitch (tombol, kartu, input, chip, dialog, snackbar, navigasi). Susunan bilah navigasi hasil redesain (Beranda, Koleksi, Sesi Baca, Komunitas, Profil) dicatat di `docs/stitch-screens.md` untuk dipakai T-007.
  - `MaterialApp` di `app.dart` memakai `AppTheme.light` dan `AppTheme.dark`; pemilihan mode mengikuti pengaturan sistem sampai pilihan tampilan T-095 dibuat.
  - Diverifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (2 test termasuk pemeriksaan kedua tema), dan aplikasi berjalan di perangkat Infinix X1201 (Android 15) dengan mode gelap sistem dan font Merriweather tampil.
## Stitch Instructions

Get the images and code for the following Stitch project's screens:

## Project
Title: Aesthetic Navbar Redesign
ID: 2681203562337770535

## Screens:
1. Beranda
    ID: 539c298ebf244868a18e30a14323f8cf

2. Komunitas
    ID: 34a5279f8709401ca6fb616840a041dc

3. Koleksi
    ID: b5d9431b60e74d5e8d1aec57eb6cfe5c

4. Profil
    ID: f8641f6ee84c4d80ac3f58b371d42cae

### [ ] T-005 Komponen UI bersama
- Bergantung pada: T-004
- Kerjakan: di `core/widgets/` buat tombol utama dan sekunder, kolom teks, kartu buku, kartu postingan dasar, indikator loading, tampilan error dengan tombol coba lagi, tampilan kosong, dialog konfirmasi, dan banner offline (tampilan saja). Ikuti Figma.
- Selesai jika: halaman uji internal (hapus sebelum commit) menampilkan semua komponen di light dan dark.
- Catatan:

### [ ] T-006 Layanan konektivitas dan banner offline
- Bergantung pada: T-005
- Kerjakan: provider `connectivityProvider` berbasis `connectivity_plus`, dan pasang banner "Anda sedang offline" di atas shell aplikasi.
- Selesai jika: banner muncul saat mode pesawat dinyalakan dan hilang saat dimatikan.
- Catatan:

### [ ] T-007 Kerangka router
- Bergantung pada: T-005
- Kerjakan: `core/router/app_router.dart` dengan go_router berisi semua rute pada PRD bagian 4 (layar placeholder), shell user dengan navigasi bawah, dan provider router yang membaca state auth dan role (redirect diisi di T-015).
- Selesai jika: semua rute bisa dibuka dari kode, navigasi bawah berpindah tab.
- Catatan:

---

## Fase 1 - Autentikasi dan role

### [ ] T-010 Repository autentikasi
- Bergantung pada: T-002
- Kerjakan: `features/auth/data/auth_repository.dart` dengan `signInWithGoogle()`, `signInWithEmail()`, `registerWithEmail()`, `sendEmailVerification()`, `sendPasswordResetEmail()`, `signOut()`, dan `authStateChanges`. Tangani pembatalan pengguna dan error jaringan dengan pesan Indonesia.
- Selesai jika: pendaftaran dan login (email maupun Google) serta logout berfungsi lewat tombol uji.
- Catatan:

### [ ] T-011 Model user dan pembuatan dokumen saat pendaftaran atau login pertama
- Bergantung pada: T-003, T-010
- Kerjakan: model `AppUser` (`fromMap`, `toMap`), `user_repository.dart` yang membuat `users/{uid}` dengan `role = user` bila belum ada (tanpa menimpa role yang sudah ada).
- Selesai jika: pendaftaran atau login pertama membuat dokumen, login berikutnya tidak mengubah role.
- Catatan:

### [ ] T-012 Provider auth dan role
- Bergantung pada: T-011
- Kerjakan: `authStateProvider`, `currentUserProvider` (stream dokumen `users/{uid}`), `isAdminProvider`.
- Selesai jika: perubahan role di Console langsung tercermin di provider.
- Catatan:

### [ ] T-013 Layar Splash
- Bergantung pada: T-005, T-012
- Kerjakan: layar Splash sesuai Figma atau PRD bagian 7.
- Selesai jika: tampil saat aplikasi dibuka dan berpindah otomatis setelah status login diketahui.
- Catatan:

### [ ] T-014 Layar Login
- Bergantung pada: T-010, T-005
- Kerjakan: layar masuk sesuai desain Stitch "Libria - Masuk Akun" (`docs/design/stitch/masuk-akun.*`): kolom email dan kata sandi dengan tombol lihat sandi, tautan "Lupa Password?", tombol "MASUK", pemisah "Atau masuk dengan", dan tombol "Masuk dengan Google", lengkap dengan status loading dan pesan error. Tautan "Daftar" membuka `/register`.
- Selesai jika: login Google dan email berhasil membawa ke rute sesuai role (setelah T-015); kegagalan menampilkan pesan dan tetap di layar; email belum terverifikasi ditolak dengan pesan dan tombol kirim ulang.
- Catatan:
  - Desain Stitch memuat checkbox "Ingat Saya" dan bilah tab Beranda, Buku, Pengaturan, Profil di bagian bawah. Keduanya tidak dipakai: sesi login memang selalu bertahan (FR-A6) dan bilah tab tidak relevan untuk pengguna yang belum login.

### [ ] T-015 Redirect router berdasarkan auth dan role
- Bergantung pada: T-007, T-012, T-013, T-014
- Kerjakan: terapkan aturan redirect PRD bagian 4. User tidak bisa membuka `/admin/*`.
- Selesai jika: akun user masuk ke `/home`, akun admin ke `/admin`, belum login ke `/login`, dan membuka `/admin` sebagai user ditolak.
- Catatan:

### [ ] T-016 Layar Daftar Akun Baru dan Lupa Kata Sandi
- Bergantung pada: T-010, T-005
- Kerjakan: layar pendaftaran sesuai desain Stitch "Libria - Daftar Akun Baru" (`docs/design/stitch/daftar-akun.*`): nama lengkap, email, kata sandi, konfirmasi kata sandi, checkbox persetujuan Syarat & Ketentuan, tombol "Daftar Sekarang", pemisah "Atau daftar dengan", dan tombol "Daftar dengan Google"; kirim email verifikasi setelah akun dibuat. Lanjutkan dengan layar `/forgot-password` sesuai PRD bagian 7 (kolom email, kirim tautan reset, pesan hasil).
- Selesai jika: akun baru lewat email maupun Google terbentuk, dokumen `users/{uid}` dibuat dengan `role = user`, validasi kolom memakai pesan bahasa Indonesia, dan tautan reset terkirim.
- Catatan:

---

## Fase 2 - Fondasi data

### [ ] T-020 Model data inti
- Bergantung pada: T-003
- Kerjakan: model Dart biasa dengan `fromMap` dan `toMap` untuk Book, LibraryEntry, ReadingSession, Journal, Review, Post, Reply, Report, AppEvent, Challenge, ChallengeParticipant, AppNotification, IsbnLog sesuai PRD bagian 8. Tambahkan test pemetaan untuk Book, LibraryEntry, ReadingSession.
- Selesai jika: `flutter test` lulus untuk pemetaan model.
- Catatan:

### [ ] T-021 Aktifkan persistensi offline Firestore
- Bergantung pada: T-002
- Kerjakan: set `Settings(persistenceEnabled: true, cacheSizeBytes: CACHE_SIZE_UNLIMITED)` saat startup.
- Selesai jika: data yang sudah dimuat tetap tampil saat mode pesawat.
- Catatan:

### [ ] T-022 Firestore rules, indexes, dan Storage rules
- Bergantung pada: T-020
- Kerjakan: tulis `firestore.rules`, `firestore.indexes.json`, dan `storage.rules` sesuai PRD bagian 9. Buat helper `isAdmin()`, `isOwner(uid)`. Pembatasan field `role` dan pembatasan perubahan counter pada `posts` wajib ada. Tambahkan `firebase.json` yang menunjuk ke berkas tersebut.
- Selesai jika: berkas valid (`firebase deploy --only firestore:rules --dry-run` bila CLI tersedia) dan setiap baris tabel di PRD bagian 9 terwakili.
- Catatan: pemilik proyek men-deploy lewat M-05.

---

## Fase 3 - Admin: katalog buku

### [ ] T-030 Repository buku
- Bergantung pada: T-020, T-022
- Kerjakan: `BookRepository` dengan tambah, ubah, hapus, ambil per id, cari berdasarkan ISBN, pencarian awalan judul/penulis (`titleLower`, `authorLower`), dan daftar berpaginasi. Validasi ISBN unik sebelum menyimpan.
- Selesai jika: semua operasi bisa dipanggil lewat provider, ISBN duplikat ditolak dengan pesan jelas.
- Catatan:

### [ ] T-031 Dashboard Admin
- Bergantung pada: T-015, T-030
- Kerjakan: layar `/admin` sesuai PRD bagian 7: kartu angka (pakai query `count()`), menu, dan Keluar.
- Selesai jika: angka tampil dan semua menu membuka rutenya.
- Catatan:

### [ ] T-032 Daftar buku admin
- Bergantung pada: T-031
- Kerjakan: layar `/admin/books` dengan pencarian (judul, penulis, ISBN), paginasi, tombol tambah, dan geser atau tombol hapus dengan konfirmasi.
- Selesai jika: pencarian dan hapus berfungsi.
- Catatan:

### [ ] T-033 Formulir tambah dan ubah buku
- Bergantung pada: T-032
- Kerjakan: formulir sesuai FR-B1 dengan validasi (judul, penulis, ISBN 10 atau 13 digit, jumlah halaman lebih dari 0). Unggah sampul ke Storage `covers/{bookId}` (kompres, maksimal 2 MB). Terima parameter ISBN awal untuk dipakai T-035.
- Selesai jika: tambah dan ubah berhasil, sampul tampil, validasi menolak data salah.
- Catatan:

### [ ] T-034 Log ISBN: pencatatan
- Bergantung pada: T-030
- Kerjakan: `IsbnLogRepository.record(isbn)` yang membuat atau menaikkan `scanCount` pada `isbn_logs/{isbn}` secara transaksi dan mengisi `lastScannedAt`, `lastScannedBy`, `handled = false`.
- Selesai jika: pemanggilan berulang menaikkan `scanCount`, tidak membuat dokumen ganda.
- Catatan:

### [ ] T-035 Layar Log ISBN admin
- Bergantung pada: T-033, T-034
- Kerjakan: `/admin/isbn-logs` sesuai PRD bagian 7: daftar log belum ditangani, tombol "Tambah buku" (membuka T-033 dengan ISBN terisi) dan "Tandai ditangani".
- Selesai jika: kedua tombol berfungsi.
- Catatan:

---

## Fase 4 - Perpustakaan dan beranda (user)

### [ ] T-040 Repository perpustakaan
- Bergantung pada: T-020, T-022
- Kerjakan: `LibraryRepository` dengan tambah buku ke rak (menyimpan salinan ringkas buku), ubah status, ubah halaman terakhir, hapus dari rak, stream seluruh rak, dan stream satu entri. Terapkan aturan status otomatis: bila `currentPage == bookTotalPages` maka `status = finished` dan `finishedAt` terisi. Tambahkan unit test untuk aturan ini.
- Selesai jika: test aturan status lulus.
- Catatan:

### [ ] T-041 Layar Perpustakaan
- Bergantung pada: T-040, T-007
- Kerjakan: tab Perpustakaan dengan segmen Ingin Dibaca, Sedang Dibaca, Selesai, kartu buku dengan progres, dan keadaan kosong. Harus tampil saat offline.
- Selesai jika: data tampil per segmen dan tetap terbuka saat offline.
- Catatan:

### [ ] T-042 Pencarian katalog
- Bergantung pada: T-030, T-007
- Kerjakan: layar pencarian buku (judul, penulis, ISBN) dengan debounce dan paginasi, hasil membuka detail buku.
- Selesai jika: pencarian mengembalikan buku yang benar.
- Catatan:

### [ ] T-043 Layar Detail Buku
- Bergantung pada: T-040, T-042
- Kerjakan: `/book/:id` berisi sampul, metadata, sinopsis, tombol tambah ke rak, pilihan status (ubah manual), input halaman terakhir, tombol "Mulai Sesi". Bagian ulasan diisi di T-062.
- Selesai jika: tambah ke rak, ubah status, dan ubah halaman berfungsi.
- Catatan:

### [ ] T-044 Scan ISBN
- Bergantung pada: T-034, T-043
- Kerjakan: layar pemindai dengan `mobile_scanner` dan izin kamera. Jika ISBN ditemukan buka detail buku. Jika tidak, tampilkan pesan "Buku dengan ISBN ... tidak ditemukan" dan panggil `IsbnLogRepository.record`. Siapkan layar sebagai komponen yang bisa dipakai ulang oleh alur sesi (mengembalikan buku terpilih).
- Selesai jika: ISBN terdaftar membuka buku, ISBN tak terdaftar menghasilkan pesan dan log.
- Catatan:

### [ ] T-045 Layar Beranda
- Bergantung pada: T-041, T-044
- Kerjakan: Beranda sesuai Figma atau PRD bagian 7. Bagian tantangan, kegiatan, dan lencana notifikasi diisi pada task fase 8; sediakan slot yang menampilkan keadaan kosong sementara.
- Selesai jika: kartu Sedang Dibaca, ringkasan hari ini, dan aksi cepat berfungsi.
- Catatan:

---

## Fase 5 - Sesi membaca

### [ ] T-050 Mesin timer berbasis cap waktu
- Bergantung pada: T-020
- Kerjakan: kelas murni `SessionTimerEngine` (tanpa Flutter) dengan state: idle, running, paused, targetReached, finished. Hitung durasi dari `startedAt` dan akumulasi jeda, bukan dari penghitung detik. Sediakan serialisasi ke map. Tulis unit test: berjalan, jeda, lanjut, mencapai target, dipulihkan dari map setelah jeda panjang.
- Selesai jika: semua unit test lulus.
- Catatan:

### [ ] T-051 Penyimpanan sesi aktif lokal
- Bergantung pada: T-050
- Kerjakan: simpan sesi aktif ke `shared_preferences` setiap perubahan state, dan `activeSessionProvider` yang memulihkannya saat aplikasi dibuka (FR-S9).
- Selesai jika: sesi berjalan dipulihkan setelah aplikasi dimatikan paksa dan dibuka lagi.
- Catatan:

### [ ] T-052 Layar pengaturan sesi
- Bergantung pada: T-044, T-051
- Kerjakan: `/session/setup`: pilih buku dari perpustakaan atau katalog, tombol pintasan Scan ISBN (tidak wajib), input target menit, tombol Mulai. Jika buku belum di rak, tambahkan otomatis dengan status Sedang Dibaca (FR-S2).
- Selesai jika: sesi bisa dimulai dengan atau tanpa scan ISBN.
- Catatan:

### [ ] T-053 Timer di latar belakang
- Bergantung pada: T-051
- Kerjakan: integrasi `flutter_foreground_task` dengan notifikasi berkelanjutan berisi judul buku dan waktu berjalan. Tambahkan izin dan deklarasi layanan di `AndroidManifest.xml`. Tangani izin notifikasi Android 13 ke atas.
- Selesai jika: timer tetap akurat setelah layar dimatikan lima menit.
- Catatan:

### [ ] T-054 Alarm getar saat target tercapai
- Bergantung pada: T-053
- Kerjakan: saat target tercapai: getar dengan pola alarm (`vibration`), tampilkan notifikasi lokal, hentikan timer pada nilai target. Jadwalkan juga notifikasi lokal tepat waktu (`zonedSchedule`, mode alarm tepat, tangani izin alarm tepat Android 12 ke atas) sebagai cadangan bila layanan latar belakang dimatikan sistem, dan batalkan jadwal bila sesi selesai lebih awal.
- Selesai jika: dengan layar mati, perangkat bergetar tepat saat target, dan timer berhenti.
- Catatan:

### [ ] T-055 Layar timer
- Bergantung pada: T-052, T-053, T-054
- Kerjakan: `/session/run` sesuai Figma: header hanya judul buku (tanpa bab), waktu berjalan, target, bar progres menuju target, tombol Selesai (dan Jeda atau Lanjut bila ada di Figma). Cegah layar mati otomatis selama layar ini terbuka (opsional, ikuti Figma).
- Selesai jika: tampilan sinkron dengan mesin timer dan tidak ada tulisan bab.
- Catatan:

### [ ] T-056 Penyimpanan sesi dan pembaruan buku
- Bergantung pada: T-040, T-055
- Kerjakan: `/session/finish`: input halaman terakhir (tidak boleh kurang dari halaman awal atau lebih dari total halaman), simpan `ReadingSession`, perbarui halaman terakhir buku dan terapkan status otomatis (FR-L4, FR-S8), bersihkan sesi aktif lokal. Tambahkan test untuk logika penyimpanan.
- Selesai jika: setelah menyimpan halaman terakhir sama dengan total halaman, buku berstatus Selesai.
- Catatan:

### [ ] T-057 Riwayat sesi
- Bergantung pada: T-056
- Kerjakan: daftar sesi per buku (di Detail Buku) dan daftar keseluruhan (dari Statistik), tampil saat offline.
- Selesai jika: sesi yang baru disimpan langsung tampil.
- Catatan:

---

## Fase 6 - Jurnal dan ulasan

### [ ] T-060 Repository dan layar Jurnal
- Bergantung pada: T-056
- Kerjakan: `JournalRepository` (tambah, ubah, hapus, stream per pengguna, filter per buku), layar daftar `/journal` dan formulir `/journal/new` berupa teks biasa.
- Selesai jika: CRUD jurnal berfungsi dan filter per buku bekerja.
- Catatan:

### [ ] T-061 Tawaran jurnal setelah sesi
- Bergantung pada: T-056, T-060
- Kerjakan: setelah sesi tersimpan, tampilkan pilihan "Tulis jurnal" atau "Lewati". Jurnal baru otomatis terkait buku dan sesi tersebut.
- Selesai jika: kedua pilihan bekerja.
- Catatan:

### [ ] T-062 Ulasan buku
- Bergantung pada: T-043
- Kerjakan: `ReviewRepository` dengan simpan, ubah, hapus ulasan (id dokumen = UID). Perbarui `ratingAverage` dan `ratingCount` pada buku di dalam transaksi. Tampilkan formulir rating (1 sampai 5) dan daftar ulasan di Detail Buku.
- Selesai jika: rata-rata rating benar setelah tambah, ubah, hapus ulasan.
- Catatan:

---

## Fase 7 - Statistik dan laporan PDF

### [ ] T-070 Perhitungan statistik
- Bergantung pada: T-057
- Kerjakan: fungsi murni untuk total menit, total halaman, buku selesai, streak, dan menit per hari pada rentang tertentu. Tambahkan unit test (streak lintas hari, hari kosong, rentang 7 dan 30 hari).
- Selesai jika: test lulus.
- Catatan:

### [ ] T-071 Layar Statistik
- Bergantung pada: T-070
- Kerjakan: tab Statistik dengan kartu ringkasan, grafik batang `fl_chart` (pilihan 7 atau 30 hari), dan tautan ke riwayat sesi.
- Selesai jika: angka dan grafik sesuai data, keadaan kosong tampil bila belum ada sesi.
- Catatan:

### [ ] T-072 Pembuat dokumen PDF laporan
- Bergantung pada: T-070
- Kerjakan: fungsi yang menghasilkan PDF sesuai FR-P2 dengan paket `pdf` (tata letak A4, tabel buku, ringkasan harian, paginasi halaman otomatis, font yang mendukung teks Indonesia).
- Selesai jika: PDF terbentuk dan terbaca benar untuk 0, 1, dan banyak sesi.
- Catatan:

### [ ] T-073 Layar Laporan dan cetak
- Bergantung pada: T-072
- Kerjakan: `/report` dengan pemilih rentang tanggal, pratinjau, dan tombol Cetak lewat `printing` (`Printing.layoutPdf`). Tidak ada fitur kirim.
- Selesai jika: dialog cetak sistem terbuka dengan PDF yang benar.
- Catatan:

---

## Fase 8 - Komunitas, kegiatan, tantangan, notifikasi

### [ ] T-080 Repository postingan dan feed
- Bergantung pada: T-020, T-022
- Kerjakan: `PostRepository` (stream feed berpaginasi, buat, hapus, ambil per id) dan layar feed tab Komunitas dengan kartu postingan.
- Selesai jika: feed tampil dengan paginasi dan bisa memuat halaman berikutnya.
- Catatan:

### [ ] T-081 Buat postingan
- Bergantung pada: T-080
- Kerjakan: formulir postingan teks dengan penautan buku opsional (dari perpustakaan). Validasi tidak kosong dan batas panjang 1000 karakter.
- Selesai jika: postingan baru muncul di feed.
- Catatan:

### [ ] T-082 Detail postingan dan balasan
- Bergantung pada: T-080
- Kerjakan: `/post/:id` dengan daftar balasan dan kolom balas. Penambahan balasan menaikkan `replyCount` dalam satu batch. Penulis dapat menghapus balasannya.
- Selesai jika: balasan tampil dan `replyCount` sinkron.
- Catatan:

### [ ] T-083 Like dan batal like
- Bergantung pada: T-080
- Kerjakan: toggle like memakai dokumen `posts/{id}/likes/{uid}` dan `increment` pada `likeCount` dalam transaksi, dengan pembaruan tampilan langsung.
- Selesai jika: satu pengguna tidak bisa menyukai dua kali dan hitungan benar.
- Catatan:

### [ ] T-084 Lapor konten
- Bergantung pada: T-082
- Kerjakan: menu lapor pada postingan dan balasan dengan pilihan alasan (Spam, Kata kasar, Konten tidak pantas, Lainnya) dan penyimpanan ke `reports` dengan `targetPreview`.
- Selesai jika: laporan tersimpan dan pengguna menerima konfirmasi.
- Catatan:

### [ ] T-085 Moderasi laporan (admin)
- Bergantung pada: T-084, T-031
- Kerjakan: `/admin/reports` berisi laporan terbuka dengan isi konten, alasan, tombol Hapus Konten (menghapus postingan atau balasan dan menutup laporan) dan Abaikan.
- Selesai jika: kedua aksi mengubah status laporan dengan benar.
- Catatan:

### [ ] T-086 Notifikasi dalam aplikasi
- Bergantung pada: T-082, T-083
- Kerjakan: `NotificationRepository` (stream, tandai terbaca, tandai semua, hitung belum dibaca). Buat notifikasi dari sisi klien untuk balasan dan like (tidak membuat notifikasi untuk aksi pada postingan sendiri, dan tidak berulang untuk like yang sama). Layar `/notifications` sesuai PRD bagian 7 dan lencana di Beranda.
- Selesai jika: balasan dan like dari akun lain memunculkan notifikasi yang bisa dibuka dan ditandai terbaca.
- Catatan:

### [ ] T-087 Kegiatan: admin
- Bergantung pada: T-031
- Kerjakan: `EventRepository` dan layar `/admin/events` untuk tambah, ubah, hapus kegiatan. Saat membuat kegiatan, tulis notifikasi tipe `event` ke pengguna (batasi maksimal 200 pengguna terbaru agar tidak berat; catat batasan di Catatan).
- Selesai jika: CRUD kegiatan berfungsi.
- Catatan:

### [ ] T-088 Kegiatan: pengguna
- Bergantung pada: T-087, T-086
- Kerjakan: `/events` dan `/events/:id` dengan tombol Ikut atau Batal Ikut yang menaikkan atau menurunkan `participantCount` dalam transaksi. Tampilkan kegiatan terdekat di Beranda.
- Selesai jika: status ikut dan jumlah peserta konsisten.
- Catatan:

### [ ] T-089 Tantangan: admin
- Bergantung pada: T-031
- Kerjakan: `ChallengeRepository` dan layar `/admin/challenges` untuk tambah, ubah, hapus tantangan sesuai FR-C1. Validasi tanggal selesai setelah tanggal mulai.
- Selesai jika: CRUD tantangan berfungsi.
- Catatan:

### [ ] T-090 Tantangan: pengguna dan progres otomatis
- Bergantung pada: T-089, T-056, T-086
- Kerjakan: `/challenges` dan `/challenges/:id` dengan tombol Gabung, bar progres, dan papan peringkat 10 teratas. Pada saat sesi disimpan (T-056) dan saat buku menjadi Selesai, perbarui `progress` pada tantangan aktif yang diikuti pengguna dalam transaksi. Tampilkan tantangan aktif di Beranda. Tambahkan unit test untuk logika progres (di dalam rentang tanggal, di luar rentang, dua jenis tantangan).
- Selesai jika: progres bertambah otomatis setelah sesi dan test lulus.
- Catatan:

---

## Fase 9 - Pengaturan dan penyelesaian

### [ ] T-095 Layar Pengaturan dan dark mode
- Bergantung pada: T-015, T-005
- Kerjakan: tab Pengaturan sesuai Figma atau PRD bagian 7: profil, pilihan tampilan (Ikuti sistem, Terang, Gelap) yang tersimpan di `shared_preferences` dan langsung berlaku, pintasan Jurnal dan Laporan, versi aplikasi, Keluar dengan konfirmasi.
- Selesai jika: pilihan tampilan bertahan setelah aplikasi dibuka ulang.
- Catatan:

### [ ] T-096 Audit loading, error, kosong, dan teks
- Bergantung pada: semua task fitur (T-030 sampai T-095)
- Kerjakan: periksa setiap layar untuk tiga keadaan data, pastikan tidak ada teks yang tertulis langsung di widget, tidak ada warna hex di widget, dan tidak ada emoji di kode (cari dengan pencarian pola Unicode).
- Selesai jika: daftar temuan kosong atau sudah diperbaiki.
- Catatan:

### [ ] T-097 Audit offline
- Bergantung pada: T-096
- Kerjakan: uji manual dan catat hasil untuk: buka perpustakaan, jalankan sesi, simpan sesi, tulis jurnal, ubah status, like, semuanya saat mode pesawat lalu kembali online. Perbaiki yang gagal. Pastikan fitur yang butuh koneksi menampilkan pesan jelas.
- Selesai jika: data offline tersinkron setelah online, dan hasil uji dicatat di bagian Catatan.
- Catatan:

### [ ] T-098 Uji end-to-end alur utama
- Bergantung pada: T-096
- Kerjakan: tulis dan jalankan `flutter test` atau `integration_test` untuk alur: login (dengan Firebase emulator atau mock repository), tambah buku ke rak, jalankan dan simpan sesi, status menjadi Selesai. Jika emulator tidak memungkinkan, tulis checklist uji manual di `docs/QA.md`.
- Selesai jika: ada bukti uji (test lulus atau `docs/QA.md` terisi).
- Catatan:

### [ ] T-099 Persiapan rilis Android
- Bergantung pada: T-098
- Kerjakan: nama aplikasi dan ikon, `applicationId`, konfigurasi penandatanganan rilis (kunci disediakan pemilik, jangan dikomit), pengaturan izin di manifest hanya yang dipakai, `flutter build apk --release` dan `flutter build appbundle`.
- Selesai jika: APK rilis terbentuk dan berjalan di perangkat nyata.
- Catatan:

---

## Opsional

### [ ] T-100 Push notification saat aplikasi tertutup (FCM)
- Bergantung pada: T-086, dan pemilik proyek mengaktifkan paket Firebase yang mendukung Cloud Functions
- Kerjakan: simpan token FCM pengguna, buat Cloud Function yang mengirim push saat dokumen notifikasi baru dibuat, dan tangani ketukan notifikasi menuju rute tujuan.
- Selesai jika: push sampai ke perangkat saat aplikasi tertutup.
- Catatan:

---

## Urutan yang disarankan karena tenggat dekat

1. Fondasi dan login: T-001 sampai T-015.
2. Data inti dan katalog: T-020 sampai T-035 (admin bisa mengisi buku sambil fitur lain dibuat).
3. Inti produk: T-040 sampai T-057 (perpustakaan, scan, sesi membaca).
4. Jurnal, ulasan, statistik, laporan: T-060 sampai T-073.
5. Komunitas dan sisanya: T-080 sampai T-090.
6. Penyelesaian: T-095 sampai T-099.

Jika waktu sangat mepet, bagian yang paling aman ditunda ke akhir adalah T-087 sampai T-090 (kegiatan dan tantangan) dan T-073 (cetak laporan), karena tidak menghalangi alur inti.
