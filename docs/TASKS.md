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

### [x] T-005 Komponen UI bersama
- Bergantung pada: T-004
- Kerjakan: di `core/widgets/` buat tombol utama dan sekunder, kolom teks, kartu buku, kartu postingan dasar, indikator loading, tampilan error dengan tombol coba lagi, tampilan kosong, dialog konfirmasi, dan banner offline (tampilan saja). Ikuti Figma.
- Selesai jika: halaman uji internal (hapus sebelum commit) menampilkan semua komponen di light dan dark.
- Catatan:
  - Sembilan komponen dibuat di `core/widgets/`: `PrimaryButton` dan `SecondaryButton` (`app_button.dart`), `AppTextField`, `BookCard`, `PostCard`, `LoadingView`, `ErrorView`, `EmptyView`, `showConfirmDialog` (`confirm_dialog.dart`), dan `OfflineBanner`.
  - Acuan tampilan memakai ekspor desain yang berlaku di repo (`docs/design/stitch/beranda.*`, `koleksi.*`, `komunitas.*`) dan ringkasan komponen `docs/DESIGN.md` bagian 6. Tidak ada layar yang dipanggil ulang dari Stitch MCP karena seluruh elemennya sudah tercatat dan kuota MCP terbatas; permintaan "Ikuti Figma" pada task ini dipenuhi lewat acuan desain resmi proyek (Stitch) sesuai AGENTS.md bagian 6.
  - Kartu buku mengikuti kartu daftar layar Koleksi: sampul 80x112 radius 8 dengan `AppShadows.cover`, judul Merriweather, penulis, chip kategori, dan bar progres opsional dari `currentPage`/`totalPages`. Varian grid pada desain belum dibuat karena belum dipakai task lain.
  - Kartu postingan mengikuti kartu feed Komunitas tanpa baris judul karena model `posts` (PRD bagian 8) hanya punya `content`; `timeLabel` diformat pemanggil dan penautan buku hanya menampilkan `bookTitle`.
  - Indikator loading, tampilan error, tampilan kosong, dialog konfirmasi, dan banner offline tidak ada di Stitch; tampilannya diturunkan dari token tema dan PRD bagian 6 (teks banner "Anda sedang offline"). Banner memakai `inverseSurface` agar kontras di kedua mode.
  - Teks baru dikumpulkan di bagian "Komponen bersama" pada `core/constants/app_strings.dart`; label berangka (halaman, persentase, jumlah tanggapan) dibuat lewat helper statis di kelas yang sama agar teks tetap terpusat.
  - Halaman uji internal `test/widget_gallery_page.dart` beserta uji `test/widget_gallery_test.dart` dan `test/widget_gallery_golden_test.dart` dipakai untuk menampilkan seluruh komponen pada mode terang dan gelap, lalu dihapus sebelum commit sesuai instruksi task.
  - Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (4 uji baru di `test/widgets_test.dart` ditambah 2 uji lama). Galeri juga dijalankan di perangkat Infinix X1201 (Android 15) dan diperiksa lewat tangkapan layar pada mode terang dan gelap untuk semua komponen termasuk dialog konfirmasi.

### [x] T-006 Layanan konektivitas dan banner offline
- Bergantung pada: T-005
- Kerjakan: provider `connectivityProvider` berbasis `connectivity_plus`, dan pasang banner "Anda sedang offline" di atas shell aplikasi.
- Selesai jika: banner muncul saat mode pesawat dinyalakan dan hilang saat dimatikan.
- Catatan:
  - `ConnectivityService` dan `connectivityProvider` (`StreamProvider<bool>`) dibuat di `lib/core/services/connectivity_service.dart`. Nilai `true` berarti perangkat punya koneksi; hanya `ConnectivityResult.none` yang dianggap offline. Emisi pertama dari `checkConnectivity()` supaya banner langsung benar bila aplikasi dibuka dalam keadaan offline, lalu diikuti perubahan dari `onConnectivityChanged`. Kegagalan pemeriksaan awal dianggap online agar banner tidak salah tampil, dan perubahan berikutnya tetap dipantau.
  - Banner dipasang global lewat `MaterialApp.builder` di `lib/app.dart` memakai `OfflineBannerHost` baru di `lib/core/widgets/offline_banner.dart`, yang menyisipkan `OfflineBanner` (T-005) di atas konten. Karena shell baru dibuat pada T-007, posisi ini sudah berada di atas calon shell dan tidak perlu dipindah saat router dibuat.
  - Saat banner tampil, konten digeser turun; inset atas dihapus dari `MediaQuery` anak supaya bilah aplikasi tidak menambahkan jarak bilah status dua kali. Area bilah status diwarnai sama dengan banner ditambah `AnnotatedRegion<SystemUiOverlayStyle>` agar ikon bilah status tetap kontras di kedua mode. Susunan widget dijaga tetap supaya anak tidak dibuat ulang saat banner muncul atau hilang.
  - Banner offline tidak ada di Stitch (sudah dicatat pada T-005) dan tampilannya tidak diubah, jadi tidak ada panggilan Stitch baru demi menghemat kuota MCP.
  - Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (11 uji; 3 uji layanan konektivitas dan 2 uji widget banner pada tema terang dan gelap termasuk memastikan banner tidak tampil selama status belum diketahui). Di perangkat Infinix X1201 (Android 15, mode gelap): banner muncul saat mode pesawat dinyalakan dan hilang saat dimatikan (mode pesawat dikendalikan lewat `adb shell cmd connectivity airplane-mode`).

### [x] T-007 Kerangka router
- Bergantung pada: T-005
- Kerjakan: `core/router/app_router.dart` dengan go_router berisi semua rute pada PRD bagian 4 (layar placeholder), shell user dengan navigasi bawah, dan provider router yang membaca state auth dan role (redirect diisi di T-015).
- Selesai jika: semua rute bisa dibuka dari kode, navigasi bawah berpindah tab.
- Catatan:
  - `routerProvider` (`Provider<GoRouter>`) dibuat di `lib/core/router/app_router.dart` memakai `StatefulShellRoute.indexedStack` untuk shell user dan `GoRoute` datar untuk rute lain, semuanya memakai layar `RoutePlaceholderScreen` (`lib/core/router/placeholder_screen.dart`) sampai layar aslinya dibangun pada task fitur masing-masing. Path dikumpulkan sebagai konstanta `AppRoutes` di `lib/core/router/app_routes.dart` agar dipakai ulang oleh T-015 dan layar lain tanpa literal string. `lib/app.dart` diubah dari `MaterialApp` ke `MaterialApp.router` dan `LibriaApp` menjadi `ConsumerWidget` yang membaca `routerProvider`; `PlaceholderScreen` lama dihapus karena digantikan rute `/splash`.
  - Susunan bilah navigasi bawah mengikuti catatan di `docs/stitch-screens.md` bagian "Bilah navigasi bawah (redesain)" dan diverifikasi ulang dari Stitch pada 18 Oktober 2026: bilah kaca (`AppSemanticColors.glassSurface`) selebar layar yang menempel di tepi bawah berisi Beranda, Koleksi, tombol "Sesi Baca" di tengah (bukan tab, membuka `/session/setup` lewat `context.push`), Komunitas, dan Profil. Setiap item menampilkan ikon di atas label; item aktif berupa kotak navy `primaryContainer` radius 12 px dengan ikon dan label putih, item tidak aktif memakai `onSurfaceVariant`. Tombol "Sesi Baca" memakai lingkaran `secondaryContainer` 24 px, bukan lingkaran teal besar. Dibuat di `lib/core/router/app_shell.dart` (`HomeShell`).
  - Cabang `StatefulShellRoute` mengikuti urutan tab PRD bagian 4 (Beranda, Koleksi, Komunitas, Statistik, Profil) supaya `/home/stats` tetap terdaftar dan bisa dibuka lewat kode, meski desain Stitch tidak memberinya ikon navigasi tersendiri (sesuai catatan "ringkasan statistik tampil di Beranda dan Profil" pada `docs/stitch-screens.md`); rute ini akan ditautkan dari layar Beranda/Profil pada task terkait.
  - Rute `/admin/books/new` dan `/admin/books/:id/edit` didaftarkan sebagai `GoRoute` datar terpisah (bukan dibuat nested di bawah `/admin/books`) karena jumlah segmen path keduanya berbeda sehingga tidak ambigu; ini cukup untuk kerangka placeholder dan tidak menghalangi task admin menata ulang strukturnya bila perlu.
  - Redirect auth/role (disebut di instruksi task) sengaja belum ditambahkan karena itu pekerjaan T-015 yang baru bisa dibuat setelah provider auth (T-012) ada; `routerProvider` sudah disiapkan agar penambahan parameter `redirect` nanti tidak mengubah cara widget mengambil router.
  - Label dan judul layar placeholder baru ditambahkan ke `core/constants/app_strings.dart` pada bagian yang sudah sesuai fiturnya (Autentikasi, Katalog buku admin, dst.) plus bagian baru "Kerangka router (layar sementara T-007)" untuk pesan isi placeholder; label ini kemungkinan dipakai ulang oleh layar sungguhan pada task berikutnya.
  - Uji baru `test/router_test.dart` memastikan seluruh 29 rute pada PRD bagian 4 bisa dibuka lewat `router.go` tanpa galat, navigasi bawah berpindah antar tab (Beranda, Koleksi, Komunitas, Profil), dan tombol "Sesi Baca" membuka `/session/setup` tanpa mengubah tab aktif. `test/widget_test.dart` diperbarui mengikuti rute awal `/splash` menggantikan layar placeholder lama.
  - Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (43 uji, termasuk uji baru router).

---

## Fase 1 - Autentikasi dan role

### [x] T-010 Repository autentikasi
- Bergantung pada: T-002
- Kerjakan: `features/auth/data/auth_repository.dart` dengan `signInWithGoogle()`, `signInWithEmail()`, `registerWithEmail()`, `sendEmailVerification()`, `sendPasswordResetEmail()`, `signOut()`, dan `authStateChanges`. Tangani pembatalan pengguna dan error jaringan dengan pesan Indonesia.
- Selesai jika: pendaftaran dan login (email maupun Google) serta logout berfungsi lewat tombol uji.
- Catatan:
  - `google_sign_in` 7.2.0 memakai API baru (`GoogleSignIn.instance.initialize()` lalu `.authenticate()`); inisialisasi dilakukan sekali secara lazy di dalam repository.
  - `signInWithGoogle()` selalu mengembalikan `UserCredential` atau melempar `AuthFailure` berpesan Indonesia, termasuk saat pengguna membatalkan proses (`GoogleSignInExceptionCode.canceled`), sesuai FR-A7.
  - `registerWithEmail()` langsung mengatur `displayName` dan mengirim email verifikasi (FR-A4); penegakan "akun belum terverifikasi ditolak saat masuk, keluar otomatis, tombol kirim ulang" sengaja belum ditambahkan di sini karena itu kriteria selesai T-014 (Layar Login), bukan T-010.
  - `sendPasswordResetEmail()` mengabaikan galat `user-not-found` agar pesan hasil selalu sama baik email terdaftar maupun tidak (FR-A5); kesamaan pesan sepenuhnya ditampilkan oleh layar Lupa Kata Sandi di T-016.
  - Repository diekspos lewat `authRepositoryProvider` (Riverpod) mengikuti pola `connectivity_service.dart`, agar widget pada task berikutnya tidak memanggil `FirebaseAuth`/`GoogleSignIn` langsung.
  - Tidak ada perangkat Android/emulator yang tersedia di lingkungan pengerjaan task ini (sandbox agent tanpa akses perangkat atau proyek Firebase langsung), sehingga "tombol uji" manual pada kriteria selesai tidak dapat dijalankan. Sebagai gantinya, logika pemetaan pesan galat (`mapFirebaseAuthError`, `mapGoogleSignInError`) diuji lewat `test/auth_repository_test.dart`, serta `flutter analyze` dan `flutter test` (58 test) dijalankan dan lulus. Verifikasi end-to-end dengan tombol uji sungguhan disarankan dilakukan manual oleh pemilik proyek, atau menyatu dengan verifikasi T-014/T-016.

### [x] T-011 Model user dan pembuatan dokumen saat pendaftaran atau login pertama
- Bergantung pada: T-003, T-010
- Kerjakan: model `AppUser` (`fromMap`, `toMap`), `user_repository.dart` yang membuat `users/{uid}` dengan `role = user` bila belum ada (tanpa menimpa role yang sudah ada).
- Selesai jika: pendaftaran atau login pertama membuat dokumen, login berikutnya tidak mengubah role.
- Catatan:
  - `AppUser` (`lib/features/auth/data/app_user.dart`) memetakan field PRD bagian 8 (`displayName`, `email`, `photoUrl`, `role`, `createdAt`) dan menyediakan konstanta `roleUser`/`roleAdmin` serta getter `isAdmin`. `toMap()` selalu mengirim `createdAt` sebagai `FieldValue.serverTimestamp()` sesuai AGENTS.md, sehingga method ini hanya dipakai saat membuat dokumen baru.
  - `UserRepository.ensureUserDocument()` (`lib/features/auth/data/user_repository.dart`) memakai transaksi Firestore: baca dokumen `users/{uid}`, dan hanya menulis bila belum ada. Ini mencegah role (termasuk yang diubah manual lewat Console) tertimpa saat login berikutnya, tanpa perlu membaca field `role` secara eksplisit sebelum menulis.
  - Repository diekspos lewat `userRepositoryProvider` (Riverpod), mengikuti pola `authRepositoryProvider`/`connectivityProvider`, agar widget tidak memanggil `FirebaseFirestore` langsung untuk data pengguna.
  - Task ini sengaja belum memanggil `ensureUserDocument()` dari layar mana pun; pemanggilannya setelah login/daftar berhasil termasuk kriteria selesai T-014 (Layar Login) dan T-016 (Daftar Akun Baru), sama seperti pola yang dicatat di T-010 untuk penegakan verifikasi email.
  - Seperti pada T-010, tidak ada perangkat/proyek Firebase langsung di lingkungan pengerjaan task ini, dan proyek tidak memakai paket mocking (`mockito`/`fake_cloud_firestore`) karena berada di luar tabel paket yang diizinkan. Karena itu perilaku transaksi `ensureUserDocument()` terhadap Firestore sungguhan belum diuji otomatis; yang diuji lewat `test/app_user_test.dart` adalah logika murni `AppUser.fromMap`/`toMap` (termasuk cadangan role `user` dan konversi `Timestamp`). `flutter analyze` (nol masalah) dan `flutter test` (61 test) dijalankan dan lulus. Verifikasi end-to-end pembuatan dokumen disarankan menyatu dengan verifikasi manual T-014/T-016, atau dengan Firebase Emulator Suite bila tersedia.

### [x] T-012 Provider auth dan role
- Bergantung pada: T-011
- Kerjakan: `authStateProvider`, `currentUserProvider` (stream dokumen `users/{uid}`), `isAdminProvider`.
- Selesai jika: perubahan role di Console langsung tercermin di provider.
- Catatan:
  - Provider baru ada di `lib/features/auth/presentation/auth_providers.dart`: `authStateProvider` (`StreamProvider<User?>`) membungkus `AuthRepository.authStateChanges`; `currentUserProvider` (`StreamProvider<AppUser?>`) memakai method baru `UserRepository.watchUser(uid)` (`snapshots()` pada `users/{uid}`, dipetakan ke `AppUser`, `null` bila dokumen belum ada atau belum ada pengguna masuk); `isAdminProvider` (`Provider<bool>`) membaca `currentUserProvider.value?.isAdmin`.
  - Karena `currentUserProvider` dibangun dari `watchUser().snapshots()`, perubahan role lewat Firebase Console terdorong lewat listener Firestore secara realtime ke provider tanpa perlu memuat ulang aplikasi, memenuhi kriteria selesai.
  - Provider belum dipakai dari widget mana pun pada task ini (belum ada layar); pemakaiannya untuk redirect berdasarkan role termasuk kriteria selesai T-015, sama seperti pola yang dicatat di T-011 untuk `ensureUserDocument()`.
  - Seperti pada T-010/T-011, tidak ada perangkat/proyek Firebase langsung di lingkungan pengerjaan dan proyek tidak memakai paket mocking, sehingga perilaku stream terhadap Firestore/Firebase Auth sungguhan belum diuji otomatis. `flutter analyze` (nol masalah) dan `flutter test` (61 test, tidak ada test baru) dijalankan dan lulus. Verifikasi end-to-end (termasuk perubahan role di Console tercermin realtime) disarankan menyatu dengan verifikasi manual T-015, atau dengan Firebase Emulator Suite bila tersedia.

### [x] T-013 Layar Splash
- Bergantung pada: T-005, T-012
- Kerjakan: layar Splash sesuai Stitch atau PRD bagian 7.
- Selesai jika: tampil saat aplikasi dibuka dan berpindah otomatis setelah status login diketahui.
- Catatan:
  - Desain Stitch "Libria - Splash Screen" (`0ad5036a0beb41d991455e2181bc39e0`, 17 Oktober 2026) tersedia di `docs/design/stitch/splash-screen.*`. Progres pemuatan harus mengikuti pemeriksaan status login, bukan timer hiasan seperti pada HTML Stitch. Status bar dan bilah home pada tangkapan layar adalah chrome sistem.
  - `SplashScreen` dibuat di `lib/features/auth/presentation/splash_screen.dart` dan dipasang pada rute `/splash` di `app_router.dart`. Tampilannya menerjemahkan struktur Stitch: latar dengan lingkaran blur dan motif halaman arsip, ikon buku 96 px bergradien dengan cincin cahaya, judul Merriweather, tagline, kartu kutipan bergaris kiri `secondary`, bilah progres bergradien, dan footer. Mode gelap memakai token yang sama.
  - Progres 65% dipakai selama status Firebase Auth dimuat, 85% saat dokumen `users/{uid}` (role) dimuat, dan 100% saat status siap. Setelah status diketahui, layar langsung berpindah: tanpa pengguna ke `/login`, role user ke `/home`, role admin ke `/admin`. Dokumen `users/{uid}` yang belum ada dianggap role user karena pembuatannya adalah tugas alur login/pendaftaran (T-014/T-016). Navigasi dilewati bila router sudah berpindah lebih dulu, sehingga tidak menimpa redirect terpusat T-015.
  - Keadaan galat pada stream auth atau role menampilkan pesan `AppStrings.splashError` dengan tombol "Coba Lagi" yang menginvalidasi kedua provider. Tidak ada keadaan kosong karena splash hanya menunggu status.
  - Teks versi "v2.4" pada desain tidak dipakai; karena `package_info_plus` di luar tabel paket yang diizinkan, footer memakai "Libria • Literary Elegance" tanpa nomor versi (sesuai catatan desain).
  - Uji baru `test/splash_screen_test.dart` memeriksa tampilan selama status dimuat, pengalihan ke login/home/admin, dan keadaan galat. `test/widget_test.dart` dan `test/router_test.dart` disesuaikan agar provider auth diisolasi dari Firebase. Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (66 uji), aplikasi berjalan di perangkat Infinix X1201 (Android 15) dan berpindah dari Splash ke placeholder `/login` saat tidak ada pengguna. Tampilan juga diperiksa lewat tangkapan layar sementara 390 x 740 (berkas uji dihapus sebelum commit).

### [x] T-014 Layar Login
- Bergantung pada: T-010, T-005
- Kerjakan: layar masuk sesuai desain Stitch "Libria - Masuk Akun" (`docs/design/stitch/masuk-akun.*`): kolom email dan kata sandi dengan tombol lihat sandi, tautan "Lupa Kata Sandi?", tombol "Masuk ke Akun", pemisah "Atau masuk dengan", dan tombol "Masuk dengan Google", lengkap dengan status loading dan pesan error. Tautan "Daftar Sekarang" membuka `/register`.
- Selesai jika: login Google dan email berhasil membawa ke rute sesuai role (setelah T-015); kegagalan menampilkan pesan dan tetap di layar; email belum terverifikasi ditolak dengan pesan dan tombol kirim ulang.
- Catatan:
  - Desain 17 Oktober 2026 tidak lagi memuat bilah tab bawah. Checkbox "Ingat Saya" tetap ada dan tercentang, tetapi aplikasi tidak menyediakan opsi lupa sesi (FR-A6), jadi checkbox hanya menjadi penanda visual atau dihilangkan bila tidak diperlukan.
  - Kolom pertama pada desain baru sudah berlabel "Email"; tidak ada lagi "Email atau ID Anggota".
  - `LoginScreen` dibuat di `lib/features/auth/presentation/login_screen.dart` dan dipasang pada rute `/login`, menggantikan placeholder. Tampilannya memakai ekspor `docs/design/stitch/masuk-akun.*` (tanpa panggilan Stitch MCP baru): latar gradien, monogram 64 px dengan lencana buku, kartu `surfaceContainerLowest`, kolom berikon dengan tombol lihat sandi, tautan "Lupa Kata Sandi?", tombol navy berikon panah, pemisah uppercase, tombol Google, dan footer "Daftar Sekarang". Tautan lupa sandi membuka `/forgot-password`; tombol daftar membuka `/register`.
  - Checkbox "Ingat Saya" dihilangkan karena aplikasi tidak menyediakan opsi lupa sesi (FR-A6) dan kontrol tanpa fungsi berpotensi menyesatkan; baris "Lupa Kata Sandi?" tetap di sisi kanan. Ini pilihan yang diizinkan oleh catatan desain.
  - Validasi memakai `AppValidators.isValidEmail` baru di `lib/core/utils/validators.dart` untuk email wajib dan format email, serta kata sandi wajib. Galat Firebase Auth ditampilkan inline di dalam kartu dan pengguna tetap di layar.
  - Email belum terverifikasi: setelah masuk, aplikasi mengirim email verifikasi, keluar otomatis, menampilkan pesan, dan menyediakan tombol kirim ulang. Tombol kirim ulang masuk sebentar memakai kredensial yang hanya disimpan di memori layar, mengirim ulang email, lalu keluar lagi. Akun Google dianggap sudah terverifikasi sehingga pemeriksaan ini dilewati (FR-A4). T-015 perlu ikut memeriksa `emailVerified` pada redirect agar pengguna yang belum terverifikasi tidak sempat diarahkan ke `/home`.
  - Setelah masuk berhasil, `UserRepository.ensureUserDocument()` dipanggil, role dibaca dari `users/{uid}`, lalu layar mengarahkan ke `/admin` atau `/home`. Ini membuat kriteria selesai sudah berlaku sebelum redirect terpusat T-015 ada; T-015 dapat menggantikan navigasi ini.
  - Logo Google berwarna digambar lewat `CustomPainter` di `lib/core/widgets/google_logo.dart`; warna mereknya dikumpulkan di `GoogleBrandColors` pada `app_colors.dart` supaya widget tidak menulis kode warna. Tidak ada aset atau paket baru.
  - Teks baru diletakkan di bagian autentikasi `core/constants/app_strings.dart`. Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (76 uji; 10 uji baru di `test/login_screen_test.dart`), dan tampilan diperiksa di perangkat Infinix X1201 (Android 15) pada mode terang dan gelap. Login end-to-end dengan akun Firebase sungguhan belum dijalankan karena tidak ada kredensial uji; alur masuk, penolakan email belum terverifikasi, kirim ulang, loading, dan navigasi role diuji memakai repository palsu.

### [x] T-015 Redirect router berdasarkan auth dan role
- Bergantung pada: T-007, T-012, T-013, T-014
- Kerjakan: terapkan aturan redirect PRD bagian 4. User tidak bisa membuka `/admin/*`.
- Selesai jika: akun user masuk ke `/home`, akun admin ke `/admin`, belum login ke `/login`, dan membuka `/admin` sebagai user ditolak.
- Catatan:
  - Aturan redirect ditulis sebagai fungsi murni `resolveAuthRedirect()` di `lib/core/router/auth_redirect.dart` dan dipasang pada parameter `redirect` `GoRouter` di `lib/core/router/app_router.dart` memakai `state.uri.path`.
    - Belum login: hanya `/login`, `/register`, dan `/forgot-password` yang dibuka apa adanya; rute lain diarahkan ke `/login`.
    - Sudah login: rute autentikasi diarahkan ke area role masing-masing; role user yang membuka `/admin` atau turunannya dikembalikan ke `/home`; role admin diarahkan ke `/admin` dari rute user maupun autentikasi.
    - Email belum terverifikasi diperlakukan seperti belum login, sesuai catatan T-014, sehingga tidak sempat diarahkan ke `/home` sebelum sesinya ditutup oleh alur login.
  - `/splash` sengaja tidak di-redirect karena layar Splash (T-013) yang memeriksa status login dan role saat aplikasi dibuka. Redirect juga ditunda selama status auth atau role masih dimuat, serta saat provider gagal (layar Splash yang menampilkan galat dan tombol coba lagi), agar tidak terjadi perpindahan sebelum hasil pemeriksaan diketahui.
  - `RouterRefreshNotifier` baru di `lib/core/router/app_router_refresh.dart` dipasang sebagai `refreshListenable` go_router dan mendengarkan `authStateProvider` serta `currentUserProvider`. Dengan begitu keluar, masuk, dan perubahan role lewat Firebase Console langsung memindahkan rute yang sedang terbuka tanpa memulai ulang aplikasi.
  - Asumsi: karena PRD bagian 4 menandai seluruh rute `/home/*`, `/book/:id`, sesi, jurnal, laporan, notifikasi, kegiatan, tantangan, dan `/post/:id` sebagai akses user, admin yang membuka rute tersebut diarahkan ke `/admin` (admin tidak memakai area user, sesuai PRD bagian 11 butir 7). Dokumen `users/{uid}` yang belum ada tetap dianggap role user, sama seperti Splash dan login.
  - Navigasi manual setelah login di `LoginScreen` (T-014) tidak dihapus; redirect router tetap menjadi penentu akhir bila role berubah atau pengguna membuka rute lain. Tidak ada perubahan UI pada task ini, sehingga tidak ada panggilan Stitch baru.
  - Uji baru `test/auth_redirect_test.dart` mencakup seluruh aturan di atas, termasuk email belum terverifikasi dan penundaan saat status dimuat/galat. `test/router_test.dart` diperbarui agar memakai sesi user/admin, menguji penolakan `/admin` oleh user, pengalihan admin dari rute user, penolakan rute autentikasi bagi pengguna yang sudah masuk, serta perubahan role dan keluar yang langsung memindahkan rute lewat `refreshListenable`.
  - Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (93 uji). Aplikasi juga dijalankan di perangkat Infinix X1201 (Android 15) dan sesi pengguna yang tersimpan langsung membuka `/home` tanpa galat. Alur admin, tamu, dan penolakan `/admin` oleh user diverifikasi lewat uji otomatis dengan provider auth dan role palsu karena tidak ada kredensial admin di lingkungan ini.

### [x] T-016 Layar Daftar Akun Baru dan Lupa Kata Sandi
- Bergantung pada: T-010, T-005
- Kerjakan: layar pendaftaran sesuai desain Stitch "Libria - Daftar Akun Baru" (`docs/design/stitch/daftar-akun.*`): nama lengkap, email, kata sandi, konfirmasi kata sandi, checkbox persetujuan Syarat & Ketentuan, tombol "Daftar Sekarang", pemisah "Atau daftar dengan", dan tombol "Daftar dengan Google"; kirim email verifikasi setelah akun dibuat. Lanjutkan dengan layar `/forgot-password` sesuai PRD bagian 7 (kolom email, kirim tautan reset, pesan hasil).
- Selesai jika: akun baru lewat email maupun Google terbentuk, dokumen `users/{uid}` dibuat dengan `role = user`, validasi kolom memakai pesan bahasa Indonesia, dan tautan reset terkirim.
- Catatan:
  - Desain 17 Oktober 2026 menambahkan panel hero bergradien, pil "3.420+ Buku Dibaca Pekan Ini", petunjuk "Wajib diisi" pada nama, dan "Minimal 8 karakter" pada kata sandi. Kutipan di bawah form pada versi lama sudah dihapus. Rincian ada di `docs/stitch-screens.md`.
  - `RegisterScreen` (`lib/features/auth/presentation/register_screen.dart`) memakai ekspor `docs/design/stitch/daftar-akun.*` tanpa panggilan Stitch MCP baru: panel hero bergradien dengan monogram dan pil statistik, kartu formulir `surfaceContainerLowest`, empat kolom berikon dengan petunjuk di sisi label, checkbox persetujuan, CTA navy berikon panah, pemisah "ATAU DAFTAR DENGAN", tombol Google, dan footer "Masuk di sini". `ForgotPasswordScreen` (`lib/features/auth/presentation/forgot_password_screen.dart`) belum ada di Stitch sehingga memakai PRD bagian 7 dengan bahasa visual layar autentikasi yang sama.
  - Alur pendaftaran email: `registerWithEmail()` membuat akun dan mengirim email verifikasi, `ensureUserDocument()` membuat `users/{uid}` dengan role user, lalu sesi ditutup otomatis karena email belum terverifikasi (FR-A4). Pengguna melihat kartu "Akun Berhasil Dibuat" berisi alamat email dan arahan memeriksa kotak masuk, lalu kembali ke `/login` untuk masuk setelah verifikasi. Alur Google: `signInWithGoogle()`, `ensureUserDocument()`, lalu langsung ke `/home` atau `/admin` sesuai role.
  - Validasi memakai pesan bahasa Indonesia di `AppStrings`: nama wajib, email wajib dan formatnya lewat `AppValidators.isValidEmail`, kata sandi wajib dengan minimal 8 karakter lewat `AppValidators.isValidPassword`, konfirmasi wajib dan harus sama, serta persetujuan wajib dicentang. Kesalahan ditampilkan di bawah kolom atau di bawah checkbox tanpa meninggalkan layar.
  - Tautan "Syarat & Ketentuan" dan "Kebijakan Privasi" pada checkbox ditampilkan sebagai teks yang ditekankan, tetapi belum punya tujuan karena PRD tidak mencantumkan rute atau halaman dokumen hukum tersebut. Ini asumsi paling sederhana agar tidak menambah fitur di luar PRD.
  - Lupa kata sandi memakai `sendPasswordResetEmail()`; pesan hasil selalu sama baik email terdaftar maupun tidak karena repository mengabaikan galat `user-not-found` (FR-A5). Pesan sukses memakai kalimat PRD bagian 7, dan tautan kembali memakai `pop` bila layar dibuka dari login atau `go` bila dibuka langsung.
  - Komponen formulir autentikasi yang dipakai kedua layar baru (kolom teks, banner pesan, pemisah, tombol utama, tombol Google) dikumpulkan di `lib/features/auth/presentation/widgets/auth_widgets.dart`.
  - Tata letak autentikasi dibuat responsif lewat `AuthScreenLayout` (`lib/features/auth/presentation/widgets/auth_screen_layout.dart`). Di ponsel, hero dan formulir ditumpuk dalam satu kolom selebar maksimal 440 px. Mulai lebar 720 px, keduanya tampil berdampingan (hero 4 bagian, formulir 5 bagian) dengan lebar maksimal 960 px, latar gradien memenuhi seluruh layar, dan konten yang lebih pendek dari layar dipusatkan vertikal. Layout ini dipakai oleh Daftar Akun Baru, Lupa Kata Sandi, dan juga Login agar konsisten saat dibuka di tablet.
  - Rute `/register` dan `/forgot-password` di `app_router.dart` menggantikan layar placeholder dengan layar sungguhan; tidak ada perubahan rute atau aturan redirect.
  - Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (110 uji; 17 uji baru di `test/auth_screens_test.dart` mencakup elemen desain, validasi, pendaftaran email/Google, kegagalan, lupa kata sandi, tata letak 390 px mode gelap, serta tata letak dua kolom pada 1024 px). Aplikasi dijalankan di perangkat Infinix X1201 (Android 15) dan tampilan Daftar Akun Baru serta Lupa Kata Sandi diperiksa lewat tangkapan layar pada mode terang dan gelap.

---

## Fase 2 - Fondasi data

### [x] T-020 Model data inti
- Bergantung pada: T-003
- Kerjakan: model Dart biasa dengan `fromMap` dan `toMap` untuk Book, LibraryEntry, ReadingSession, Journal, Review, Post, Reply, Report, AppEvent, Challenge, ChallengeParticipant, AppNotification, IsbnLog sesuai PRD bagian 8. Tambahkan test pemetaan untuk Book, LibraryEntry, ReadingSession.
- Selesai jika: `flutter test` lulus untuk pemetaan model.
- Catatan:
  - Ketiga belas model dibuat sebagai kelas Dart biasa tanpa code generation di folder fitur masing-masing: `Book` dan `Review` (`features/books/data/` dan `features/reviews/data/`), `LibraryEntry` (`features/library/data/`), `ReadingSession` (`features/session/data/`), `Journal` (`features/journal/data/`), `Post` dan `Reply` (`features/community/data/`), `Report` (`features/reports/data/`), `AppEvent` (`features/events/data/`), `Challenge` dan `ChallengeParticipant` (`features/challenges/data/`), `AppNotification` (`features/notifications/data/`), serta `IsbnLog` (`features/isbn_logs/data/`). Semuanya memiliki `fromMap` dan `toMap`.
  - Mengikuti pola `AppUser`, `fromMap` menerima ID dokumen sebagai argumen pertama. ID pada dokumen `users/{uid}/library/{bookId}`, `books/{bookId}/reviews/{uid}`, `challenges/{challengeId}/participants/{uid}`, dan `isbn_logs/{isbn}` diambil dari path dokumen, bukan dari field di map. `toMap` tidak menulis ID dokumen tersebut.
  - Tanggal dibaca lewat helper `dateFromFirestore` di `core/utils/firestore_value.dart` yang menerima `Timestamp` maupun `DateTime`; tanggal domain ditulis dengan `Timestamp.fromDate`. Semua field `createdAt` dan `updatedAt` pada `toMap` memakai `FieldValue.serverTimestamp()` sesuai AGENTS.md. `addedAt` dan `joinedAt` memakai server timestamp bila kosong, sedangkan tanggal kegiatan, tantangan, sesi, dan pemindaian ISBN mengikuti nilai model.
  - `titleLower` dan `authorLower` tidak disimpan sebagai field terpisah pada `Book`; keduanya getter turunan dari `title` dan `author`, lalu tetap ditulis ke map agar pencarian awalan T-030 bisa memakainya.
  - `AppEvent` dan `AppNotification` memakai nama tersebut agar tidak bentrok dengan tipe bawaan Flutter. Model peserta kegiatan (`events/{eventId}/participants/{uid}`) tidak dibuat karena tidak tercantum pada daftar model task ini; dapat ditambahkan saat T-088 membutuhkannya.
  - Task ini tidak menyentuh UI sehingga tidak ada panggilan Stitch MCP. Uji baru `test/core_models_test.dart` berisi 10 uji pemetaan untuk Book, LibraryEntry, dan ReadingSession. Verifikasi: `dart format .` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (138 uji).

### [x] T-021 Aktifkan persistensi offline Firestore
- Bergantung pada: T-002
- Kerjakan: set `Settings(persistenceEnabled: true, cacheSizeBytes: CACHE_SIZE_UNLIMITED)` saat startup.
- Selesai jika: data yang sudah dimuat tetap tampil saat mode pesawat.
- Catatan:
  - `lib/main.dart` memasang `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)` tepat setelah `Firebase.initializeApp()` dan sebelum Firestore dipakai. Ini mengikuti ketentuan Firebase bahwa settings hanya boleh dipasang sebelum pemanggilan Firestore pertama.
  - Pengaturan berlaku untuk instance Firestore default yang dipakai seluruh repository, sehingga tidak perlu konfigurasi tambahan per repository.
  - Task ini tidak menyentuh UI, sehingga tidak ada panggilan Stitch MCP dan tidak ada teks baru di `app_strings.dart`.
  - Tidak ada uji otomatis baru karena `Settings` hanya bisa dipasang pada instance Firestore sungguhan dan tidak dapat diuji lewat widget test. Verifikasi: `dart format` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (138 uji).
  - Uji mode pesawat end-to-end belum dijalankan karena belum ada kredensial Firebase uji dan layar yang menampilkan daftar data Firestore baru dibuat pada T-030 dan seterusnya. Konfigurasi ini adalah prasyarat agar cache lokal tersebut aktif.

### [x] T-022 Firestore rules, indexes, dan Storage rules
- Bergantung pada: T-020
- Kerjakan: tulis `firestore.rules`, `firestore.indexes.json`, dan `storage.rules` sesuai PRD bagian 9. Buat helper `isAdmin()`, `isOwner(uid)`. Pembatasan field `role` dan pembatasan perubahan counter pada `posts` wajib ada. Tambahkan `firebase.json` yang menunjuk ke berkas tersebut.
- Selesai jika: berkas valid (`firebase deploy --only firestore:rules --dry-run` bila CLI tersedia) dan setiap baris tabel di PRD bagian 9 terwakili.
- Catatan: pemilik proyek men-deploy lewat M-05.
  - `firestore.rules` memuat helper `isAdmin()` (membaca `users/{uid}.role`), `isOwner(uid)`, `signedIn()`, dan `changedOnly()`. Seluruh baris tabel PRD bagian 9 tercakup: profil pengguna dan subkoleksi pribadi, notifikasi, katalog dan ulasan, postingan/balasan/like, laporan, kegiatan/tantangan/peserta, serta log ISBN. Koleksi di luar daftar ditolak oleh aturan penutup.
  - Field `role` tidak dapat diubah pemilik: pembuatan `users/{uid}` mewajibkan `role == 'user'`, dan pembaruan hanya boleh mengubah `displayName`, `email`, dan `photoUrl`. Perubahan role tetap hanya lewat Firebase Console yang memakai Admin SDK.
  - Perubahan `likeCount` dan `replyCount` pada `posts` dibatasi ke satu field per pembaruan dan selisih paling banyak satu langkah, sehingga `FieldValue.increment` dari like/balasan tetap berjalan tanpa membuka perubahan bebas pada counter. Like disimpan pada `posts/{postId}/likes/{uid}` dengan id sama dengan UID.
  - Dua pengecualian sempit ditambahkan agar task lanjutan dapat berjalan tanpa Cloud Functions: pemilik ulasan boleh memperbarui hanya `ratingAverage` dan `ratingCount` saat dokumen ulasannya berubah (T-062), dan peserta boleh mengubah hanya `participantCount` sebesar satu langkah bila dokumen peserta ikut berubah dalam batch/transaksi yang sama (T-088, T-090). Di luar itu, `books`, `events`, dan `challenges` hanya dapat ditulis admin.
  - `storage.rules` membatasi `covers/{bookId}`: dibaca semua pengguna login, ditulis admin, hanya `image/*`, maksimal 2 MB. Foto profil tetap memakai URL Google sehingga tidak ada aturan unggahan foto profil.
  - `firestore.indexes.json` memuat enam indeks komposit untuk query yang melibatkan filter dan urutan: `library` (status, addedAt), `sessions` (bookId, startedAt), `journals` (bookId, createdAt), `notifications` (read, createdAt), `reports` (status, createdAt), dan `isbn_logs` (handled, lastScannedAt). Indeks satu field seperti `events.startAt` dan `challenges.endDate` dibuat otomatis oleh Firestore sehingga tidak didaftarkan sebagai indeks komposit.
  - `firebase.json` menunjuk ke ketiga berkas aturan/indeks. `.firebaserc` ditambahkan dengan default project `libria-6bbe0` (diambil dari `android/app/google-services.json`) agar perintah deploy M-05 langsung memilih proyek yang benar; berkas ini bukan rahasia dan tidak memuat kredensial.
  - Verifikasi: Firebase CLI 15.34.0 (lewat `npx`) dan Firestore/Storage Emulator berhasil memuat kedua berkas aturan tanpa galat kompilasi. Uji aturan sementara memakai `@firebase/rules-unit-testing` di luar repo menjalankan 44 pemeriksaan akses (role, counter, notifikasi, ulasan, laporan, peserta, log ISBN, dan data pribadi) dan semuanya lulus. `dart format .` tidak mengubah berkas, `flutter analyze` nol masalah, dan `flutter test` lulus (138 uji). Deploy sungguhan tetap dilakukan pemilik lewat M-05 karena lingkungan ini tidak memiliki kredensial Firebase.

---

## Fase 3 - Admin: katalog buku

### [x] T-030 Repository buku
- Bergantung pada: T-020, T-022
- Kerjakan: `BookRepository` dengan tambah, ubah, hapus, ambil per id, cari berdasarkan ISBN, pencarian awalan judul/penulis (`titleLower`, `authorLower`), dan daftar berpaginasi. Validasi ISBN unik sebelum menyimpan.
- Selesai jika: semua operasi bisa dipanggil lewat provider, ISBN duplikat ditolak dengan pesan jelas.
- Catatan:
  - `BookRepository` berada di `lib/features/books/data/book_repository.dart` dan diekspos lewat `bookRepositoryProvider` di berkas yang sama, mengikuti pola `UserRepository`. Widget tidak perlu menyentuh `FirebaseFirestore`.
  - ISBN dinormalisasi dengan membuang spasi dan tanda hubung lalu mengubah semua huruf menjadi huruf besar, sehingga `x` pada ISBN-10 menjadi `X`. Normalisasi dipakai saat mencari, memeriksa duplikat, dan menyimpan, sehingga variasi format menunjuk ke buku yang sama.
  - Getter `titleLower` dan `authorLower` pada `Book` kini membuang spasi awal dan akhir sebelum dijadikan huruf kecil, sehingga cocok dengan input pencarian yang juga di-trim. Perubahan ini juga membuat `Book.toMap` menulis field turunan yang konsisten.
  - Pencarian awalan judul dan penulis memakai rentang `>= prefix` dan `< prefix\uf8ff` pada `titleLower`/`authorLower`. Input kosong mengembalikan `BookPage` kosong tanpa membaca koleksi. Hasil pencarian berpaginasi memakai `BookPage`/`BookCursor` yang sama seperti daftar, dengan `limit` default 20 dan maksimum 50.
  - Daftar diurutkan `createdAt` menurun. Daftar dan pencarian sama-sama mengambil `limit + 1` dokumen untuk mengetahui `hasMore`, membentuk kursor dari dokumen terakhir yang dikembalikan, lalu meneruskannya ke `startAfterDocument`, sehingga halaman berikutnya tidak mengulang item. `countBooks()` memakai agregasi `count()` untuk kartu total buku pada T-031.
  - `createBook` memakai ID dokumen baru dan menulis seluruh field lewat `buildCreateMap`: ISBN ternormalisasi, `titleLower`, `authorLower`, `createdBy`, serta `createdAt`/`updatedAt` dari `FieldValue.serverTimestamp()`. `updateBook` memakai `buildUpdateMap` yang hanya menulis field isi, field turunan, dan `updatedAt`, sehingga `ratingAverage`, `ratingCount`, `createdBy`, dan `createdAt` tidak tersentuh. `deleteBook` menghapus dokumen berdasarkan ID.
  - Pemeriksaan ISBN duplikat dilakukan dengan query sebelum penulisan dan melempar `BookFailure` berpesan bahasa Indonesia (`AppStrings.bookIsbnDuplicate`). Untuk ubah, dokumen yang sedang diedit dikecualikan. Pemeriksaan ini bukan transaksi atomik karena Firestore tidak mendukung query di dalam transaksi; penulisan bersamaan yang sama-sama lolos pre-check masih mungkin terjadi. Bila buku yang diubah tidak ada, `BookFailure` dengan `AppStrings.bookNotFound` dilempar.
  - Validasi panjang ISBN 10 atau 13 digit (FR-B3) tetap dilakukan di formulir T-033; repository ini hanya menjaga keunikan ISBN.
  - Task ini tidak menyentuh UI sehingga tidak ada panggilan Stitch MCP. Uji baru `test/book_repository_test.dart` berisi 6 uji untuk normalisasi ISBN, pembentukan peta create/update, dan pemangkasan field turunan. Verifikasi: `dart format .`, `flutter analyze` nol masalah, dan `flutter test` lulus (144 uji).

### [x] T-031 Dashboard Admin
- Bergantung pada: T-015, T-030
- Kerjakan: layar `/admin` sesuai PRD bagian 7: kartu angka (pakai query `count()`), menu, dan Keluar.
- Selesai jika: angka tampil dan semua menu membuka rutenya.
- Catatan:
  - Rute `/admin` sekarang memakai `AdminDashboardScreen` di `lib/features/admin/presentation/`. Layar ini belum punya desain Stitch, jadi susunannya mengikuti PRD bagian 7 dan token tema yang ada tanpa memanggil Stitch MCP. Menu tidak lagi berupa kartu di dashboard; seluruh area admin dibungkus `AdminShell` dengan bottom navigation tetap dan AppBar bersama.
  - `AdminShell` memakai `StatefulShellRoute.indexedStack` dengan enam cabang: Dashboard, Buku, Log ISBN, Laporan, Kegiatan, dan Tantangan. Tab mempertahankan tumpukan halaman masing-masing. Formulir tambah/ubah buku tetap di luar shell agar tampil penuh dengan tombol kembali sendiri. Judul AppBar mengikuti cabang aktif, dan aksi Keluar berada di AppBar sehingga tersedia dari semua tab.
  - Empat angka diambil lewat agregasi Firestore `count()`: `BookRepository.countBooks()` (sudah ada sejak T-030), `ReportRepository.countOpenReports()` dengan filter `status == open`, `IsbnLogRepository.countUnhandledIsbnLogs()` dengan filter `handled == false`, dan `UserRepository.countUsers()` untuk seluruh dokumen `users`. `AdminDashboardRepository.fetchStats()` menjalankan keempatnya paralel lewat record `.wait`, lalu `adminDashboardStatsProvider` (FutureProvider) menyajikannya ke widget. Tidak ada koleksi yang dibaca penuh dan widget tidak menyentuh Firestore.
  - `ReportRepository` dan `IsbnLogRepository` baru berisi metode hitung; operasi lain akan ditambahkan pada T-034/T-035 dan T-084/T-085. Keduanya diekspos lewat provider di berkas yang sama, mengikuti pola repository lain.
  - Auto-retry Riverpod dimatikan khusus `adminDashboardStatsProvider` agar galat tetap terlihat sampai pengguna menekan "Coba Lagi"; tombol itu memanggil `ref.invalidate` sehingga keempat agregasi dijalankan ulang. Angka 0 ditampilkan sebagai nilai valid, bukan keadaan kosong. Angka juga dimuat ulang setiap tab Dashboard dipilih kembali, sehingga perubahan dari layar admin lain terlihat.
  - Kartu angka memakai dua kolom di ponsel/tablet portrait dan empat kolom pada layar expanded. Seluruh warna, tipografi, radius, dan jarak berasal dari `ColorScheme`, `AppSemanticColors`, `TextTheme`, dan token `AppSpacing`/`AppRadius`; tidak ada teks UI yang ditulis langsung di widget. Mode gelap diuji pada ukuran tablet.
  - Keluar memakai `showConfirmDialog` dari AppBar shell; Batal tidak melakukan apa pun. Konfirmasi memanggil `AuthRepository.signOut()`, lalu redirect router yang sudah ada memindahkan pengguna ke `/login` setelah status auth berubah. Kegagalan sign-out menampilkan pesan ramah lewat SnackBar dan tetap di layar admin aktif.
  - Uji baru: `test/admin_dashboard_repository_test.dart` (komposisi empat angka dan nilai 0) dan `test/admin_dashboard_screen_test.dart` (loading, sukses termasuk 0, galat dan retry, enam tab bottom navigation yang tetap tampil, Batal/konfirmasi/gagal keluar, serta tata letak 360x800, 800x1280, dan 1280x800). `test/router_test.dart` menambahkan repository dashboard palsu agar uji rute tidak membutuhkan Firebase, dan fake `UserRepository` di uji autentikasi menambahkan `countUsers`.
  - Verifikasi: `dart format .` tidak mengubah berkas, `flutter analyze` nol masalah, dan `flutter test` lulus (156 uji).

### [x] T-032 Daftar buku admin
- Bergantung pada: T-031
- Kerjakan: layar `/admin/books` dengan pencarian (judul, penulis, ISBN), paginasi, tombol tambah, dan geser atau tombol hapus dengan konfirmasi.
- Selesai jika: pencarian dan hapus berfungsi.
- Catatan:
  - Rute `/admin/books` sekarang memakai `AdminBooksScreen` di dalam `AdminShell`, menggantikan placeholder. Layar ini belum punya desain Stitch, jadi susunannya mengikuti PRD bagian 5.2 dan 7 serta bahasa visual Dashboard Admin (T-031): kartu pencarian di atas, kartu buku per baris, aksi hapus berikon, dan tombol tambah. Tidak ada panggilan Stitch MCP.
  - `BookRepository.searchByIsbnPrefix()` ditambahkan untuk pencarian awalan ISBN. Input dinormalisasi dengan `normalizeIsbn()` (spasi dan tanda hubung dibuang, huruf kecil dinaikkan), lalu dicari pada field `isbn` yang sudah tersimpan ternormalisasi. Pencarian judul dan penulis tetap memakai method awalan yang sudah ada.
  - Pencarian memakai satu kolom dengan `SegmentedButton` Judul/Penulis/ISBN. Debounce 300 ms ditangani layar; submit pada papan ketik, perubahan cakupan, dan tombol hapus pencarian langsung menjalankan query. Query baru mereset daftar dan paginasi, dan `AdminBooksController` memakai penghitung generasi agar respons query lama yang datang terlambat diabaikan.
  - `AdminBooksController` (`Notifier` dengan provider `autoDispose`) mengelola halaman pertama, "Muat Lebih Banyak", penghapusan, dan keadaan memuat/galat lewat `AsyncValue<AdminBooksState>`. Halaman memakai `bookPageSize` (20); penggabungan halaman membuang ID yang sudah ada. Provider dibuang saat area admin ditinggalkan sehingga sesi admin berikutnya memuat data terbaru.
  - Hapus memakai `IconButton` dengan tooltip yang menyebut judul buku, dialog `showConfirmDialog`, lalu `BookRepository.deleteBook`. Baris baru dibuang dari daftar setelah repository berhasil; kegagalan menampilkan SnackBar ramah dan mempertahankan baris. ID yang sedang dihapus disimpan di state sehingga ketukan ganda diabaikan dan ikon diganti indikator loading. Penghapusan berlaku pada daftar lengkap maupun hasil pencarian; bila halaman yang terlihat habis padahal masih ada halaman lain, halaman pertama dimuat ulang agar sisa katalog tetap terjangkau.
  - Tombol tambah membuka `/admin/books/new` dan ketuk baris membuka `/admin/books/:id/edit` lewat `context.push`. Keduanya masih placeholder sampai T-033, dan daftar belum memuat ulang otomatis saat kembali; T-033 yang akan memicu pemuatan ulang setelah perubahan tersimpan.
  - Seluruh isi layar memakai `CustomScrollView` agar header pencarian bisa digulir pada layar pendek (misalnya ponsel landscape) tanpa overflow. `BookCard` mendapat parameter opsional `isbn` dan `trailing` agar baris admin menampilkan ISBN dan tombol hapus tanpa membuat komponen duplikat. `AppTextField` mendapat parameter opsional `onSubmitted` dan `suffixIcon` untuk tombol hapus pencarian; pemakaian lama tidak berubah.
  - Uji baru: `test/admin_books_controller_test.dart` (paginasi tanpa duplikat, reset query dan respons lama, tiga cakupan pencarian, hapus ganda/gagal, dan pemuatan halaman berikutnya saat halaman kosong) serta `test/admin_books_screen_test.dart` (loading, data, paginasi, debounce, pencarian tiga cakupan, kosong, galat/retry, navigasi tambah/ubah, Batal/konfirmasi/gagal hapus, hapus hasil pencarian, dan tata letak 360x800, 640x360, 800x1280, 1280x800 pada mode terang/gelap). `test/book_repository_test.dart` menambah uji nilai rentang query ISBN ternormalisasi lewat fake Firestore, dan `test/router_test.dart` serta `test/admin_dashboard_screen_test.dart` memakai `FakeBookRepository` agar tidak membutuhkan Firebase.
  - Verifikasi: `dart format .` tanpa perubahan, `flutter analyze` nol masalah, `flutter test` lulus (181 uji). Verifikasi pada perangkat Android belum dijalankan di lingkungan ini; cakupan ponsel/tablet dan mode terang/gelap diverifikasi lewat widget test.

### [x] T-033 Formulir tambah dan ubah buku
- Bergantung pada: T-032
- Kerjakan: formulir sesuai FR-B1 dengan validasi (judul, penulis, ISBN 10 atau 13 digit, jumlah halaman lebih dari 0). Unggah sampul ke Cloudinary (kompres, maksimal lebar 800 px, kualitas 85) atau isi URL manual. Terima parameter ISBN awal untuk dipakai T-035.
- Selesai jika: tambah dan ubah berhasil, sampul tampil, validasi menolak data salah.
- Catatan:
  - Rute `/admin/books/new` dan `/admin/books/:id/edit` sekarang memakai `AdminBookFormScreen` di `lib/features/admin/presentation/`, menggantikan placeholder. Formulir tambah membaca ISBN awal dari query `?isbn=...` lewat `state.uri.queryParameters`, dan formulir ubah memuat buku lewat `adminBookByIdProvider` (`FutureProvider.autoDispose.family`).
  - Layar ini belum punya desain Stitch, jadi tidak ada panggilan Stitch MCP. Susunannya mengikuti PRD bagian 5.2 dan 7 serta bahasa visual Dashboard Admin: kartu permukaan bergaris tipis, kolom `AppTextField`, dan tombol utama penuh. Responsif lewat `ContentWidth` (maksimum 720 dp); warna, tipografi, radius, dan jarak hanya dari token tema sehingga mode terang/gelap didukung.
  - Validasi per kolom memakai `BookValidators` (`lib/features/books/data/book_validators.dart`): judul dan penulis wajib, ISBN dinormalisasi lalu harus 10 atau 13 karakter (ISBN-10 boleh berakhir `X`), tahun boleh kosong tetapi harus angka bila diisi, dan jumlah halaman bilangan bulat lebih dari 0. Pesan kesalahan berada di bawah kolom masing-masing dan dibersihkan saat isian berubah.
  - `BookRepository.newBookId()` dipakai formulir agar ID dokumen diketahui sebelum `createBook`; `createBook` memakai ID itu bila `Book.id` terisi dan tetap membuat ID baru bila kosong. `updateBook` yang sudah ada tetap hanya menulis field isi, field turunan, dan `updatedAt`, sehingga rating, `createdBy`, dan `createdAt` tidak berubah. `BookFailure` mendapat `BookFailureCode` opsional agar formulir dapat mengenali galat ISBN duplikat tanpa membandingkan teks pesan.
  - Sampul dikelola `BookCoverService` dan `BookCoverPicker` (`lib/features/books/data/book_cover_service.dart`) yang diekspos lewat provider; widget tidak menyentuh `CloudinaryPublic`/`ImagePicker` langsung. Cloud name dan upload preset unsigned `libria` berada di `lib/core/config/cloudinary_config.dart`; tidak ada API secret. Picker meminta `image_picker` memperkecil gambar ke lebar maksimum 800 px dan kualitas 85. Galeri gagal dibuka, unggahan gagal, dan perangkat offline menampilkan pesan bahasa Indonesia tanpa mengosongkan formulir. Sebelum sampul diunggah, `BookRepository.assertIsbnAvailable` memeriksa duplikat agar ISBN yang sudah dipakai tidak meninggalkan berkas sampul baru; pemeriksaan tetap diulang saat dokumen ditulis. Kegagalan jaringan tepat setelah unggahan berhasil masih dapat meninggalkan berkas sampul baru di Cloudinary, tetapi data buku dan isian formulir tidak berubah. URL manual tetap tersedia sebagai alternatif dan menjadi nilai awal saat mengubah buku lama. Mengubah buku tanpa memilih sampul baru atau mengubah URL mempertahankan `coverUrl` lama. Semua penampil sampul memakai `BookCoverImage` dengan `CachedNetworkImage` dan `coverUrlSized` (400 px untuk daftar/grid, 800 px untuk detail), sehingga sampul yang pernah dimuat tetap tampil saat offline dan URL non-Cloudinary lama dikembalikan apa adanya.
  - Seluruh isian dibaca sekali sebelum menunggu unggahan sampul, dan kolom dinonaktifkan selama `_isSaving`, sehingga data yang disimpan selalu sama dengan data yang lolos validasi. Untuk buku baru, `createdBy` diambil dari pengguna yang sedang masuk dan penyimpanan dibatalkan dengan pesan ramah bila data akun belum tersedia.
  - Setelah simpan berhasil, formulir selalu menaikkan `adminBooksReloadProvider` lalu `context.go('/admin/books')`, bukan kembali ke layar sebelumnya. `AdminBooksScreen` mendengarkan penanda itu dan memuat ulang halaman pertama bila daftar masih aktif; bila formulir dibuka dari layar lain seperti Log ISBN (T-035), daftar yang baru dipasang memuat data terbaru saat dibuka. Tombol simpan memakai `_isSaving` dan indikator loading untuk menahan klik ganda.
  - `_ButtonContent` di `lib/core/widgets/app_button.dart` sekarang membungkus label dengan `Flexible` dan elipsis agar label panjang (misalnya "Kembali ke Daftar Buku") tidak meluber pada layar sempit atau skala font besar. Perubahan ini berlaku untuk seluruh tombol bersama dan tidak mengubah perilaku aksi.
  - Uji baru: `test/admin_book_form_test.dart` (field FR-B1, prefill ISBN, validasi per kolom, tambah, klik ganda, ISBN duplikat, ISBN duplikat sebelum unggah sampul, ubah, sampul lama dipertahankan, unggah sampul berhasil/gagal/offline, URL manual, hapus URL manual, batal memilih gambar, simpan dari rute formulir langsung, buku tidak ditemukan, loading/galat dan retry, serta tata letak 360x800, 640x360, 800x1280, 1280x800 pada mode terang/gelap), `test/book_validators_test.dart` (validasi ISBN, tahun, halaman), `test/book_cover_service_test.dart` (sukses, offline, gagal unggah, berkas kosong, `secureUrl` kosong), `test/book_cover_picker_test.dart` (lebar 800 px, kualitas 85, batal, berkas kosong), dan `test/cloudinary_url_test.dart` (transformasi 400/800, URL non-Cloudinary, idempotensi, placeholder). `FakeBookRepository` di `test/support/` mendapat `getById`, `newBookId`, `assertIsbnAvailable`, `createBook`, dan `updateBook` agar uji router/layar tidak membutuhkan Firebase.
  - Verifikasi: `dart format .` tanpa perubahan, `flutter analyze` nol masalah, dan `flutter test` lulus (229 uji). Verifikasi pada perangkat Android dan unggahan nyata ke Cloudinary belum dijalankan di lingkungan ini; cakupan ponsel/tablet dan mode terang/gelap diverifikasi lewat widget test.

### [x] T-034a Normalisasi ISBN bersama
- Bergantung pada: T-030
- Kerjakan: satu aturan normalisasi ISBN di lapisan bersama yang dipakai katalog buku dan log ISBN; perilaku lama tidak berubah.
- Selesai jika: hanya ada satu implementasi aturan normalisasi dan seluruh uji katalog lama tetap lulus.
- Catatan:
  - `Isbn.normalize` di `lib/core/utils/isbn.dart` menjadi satu-satunya implementasi aturan: membuang spasi dan tanda hubung lalu menaikkan semua huruf sehingga `x` pada ISBN-10 menjadi `X`.
  - `BookRepository.normalizeIsbn` tetap ada sebagai delegasi ke `Isbn.normalize` agar pemanggil lama, termasuk `FakeBookRepository` dan uji katalog, tetap berfungsi. Pemakaian di dalam repository, `BookValidators`, dan formulir admin sekarang memanggil helper bersama secara langsung.
  - `IsbnLog` menormalkan ISBN saat dibuat karena `isbn` adalah ID dokumen `isbn_logs/{isbn}`. Dengan begitu, nilai berformat apa pun menunjuk dokumen yang sama; pencatatan log pada T-034 tetap menormalkan ISBN sebelum menulis dokumen. Konstruktor `IsbnLog` tidak lagi `const` karena normalisasi berjalan saat pembuatan; tidak ada pemanggil lama yang memakai `const`.
  - Uji baru: `test/isbn_test.dart` (spasi, tanda hubung, `x` kecil/besar, nilai sudah normal, dan string kosong) serta satu uji `IsbnLog` di `test/core_models_test.dart`. Uji `BookRepository.normalizeIsbn` yang lama tetap lulus tanpa perubahan.
  - Verifikasi: `dart format .` tidak mengubah berkas, `flutter analyze` nol masalah, dan `flutter test` lulus (234 uji).

### [x] T-034 (T-034b) Log ISBN: pencatatan
- Bergantung pada: T-030
- Kerjakan: `IsbnLogRepository.record(isbn)` yang membuat atau menaikkan `scanCount` pada `isbn_logs/{isbn}` secara transaksi dan mengisi `lastScannedAt`, `lastScannedBy`, `handled = false`.
- Selesai jika: pemanggilan berulang menaikkan `scanCount`, tidak membuat dokumen ganda.
- Catatan:
  - Task ini dipecah menjadi T-034a (normalisasi ISBN bersama) dan T-034b (pencatatan atomik). `IsbnLogRepository.record(isbn)` menjadi satu-satunya jalur tulis ke `isbn_logs` dan tetap diekspos lewat `isbnLogRepositoryProvider`.
  - `record` menormalkan ISBN dengan `Isbn.normalize` sebelum dipakai sebagai ID dokumen. ISBN kosong setelah normalisasi ditolak lebih awal dengan `AppStrings.isbnLogUnreadableIsbn` agar tidak mencoba menulis dokumen ber-ID kosong. `FirebaseAuth` dapat diinjeksi seperti repository lain; pengguna yang belum masuk ditolak dengan `IsbnLogFailure` berpesan `AppStrings.isbnLogSignInRequired` sebelum Firestore disentuh.
  - Transaksi membaca dokumen lebih dulu. Bila belum ada, `set` menulis `isbn`, `scanCount = 1`, `lastScannedAt` dari `FieldValue.serverTimestamp()`, `lastScannedBy` UID pengguna, dan `handled = false`. Bila sudah ada, `update` memakai `FieldValue.increment(1)` untuk `scanCount`, memperbarui waktu serta pemindai, dan mengisi `handled = false` sehingga log yang sudah ditandai admin muncul lagi. Dua pemindaian bersamaan tetap menghasilkan hitungan yang benar dan tidak membuat dokumen ganda karena ID dokumen deterministik dan transaksi Firestore.
  - Aturan `isbn_logs` diperbarui: `create` mewajibkan lima field, ISBN sama dengan ID dokumen, `scanCount == 1`, `lastScannedAt == request.time`, `lastScannedBy == request.auth.uid`, dan `handled == false`. `update` oleh pengguna login hanya boleh mengubah `scanCount` (tepat satu), `lastScannedAt`, `lastScannedBy`, dan `handled` (menjadi `false`); admin tetap satu-satunya yang boleh mengubah `handled` menjadi `true`. Field lain dan penghapusan tetap ditolak.
  - Satu pengecualian disengaja pada aturan baca: `allow get: if signedIn()` diperlukan agar transaksi dapat membaca `scanCount` sebelum menulis, sedangkan `allow list: if isAdmin()` menjaga daftar log tetap hanya untuk admin. Pengecualian ini tidak membuka daftar; hanya satu dokumen yang diketahui ISBN-nya. PRD bagian 9 sudah diperbarui untuk mencatat pengecualian dan transisi `handled = false` oleh pengguna.
  - Galat Firestore dipetakan ke pesan Indonesia lewat `IsbnLogRepository.mapFirestoreError`: `unavailable`/`deadline-exceeded` menjadi pesan koneksi, `permission-denied`/`unauthenticated` menjadi pesan izin, dan galat lain menjadi pesan simpan umum. Tidak ada stack trace yang ditampilkan.
  - Uji baru `test/isbn_log_repository_test.dart` (pembuatan dengan ISBN ternormalisasi, kenaikan berulang, dua pemindaian bersamaan, pembukaan ulang log yang sudah ditangani, pengguna belum masuk, ISBN kosong, pemetaan tiga jenis galat, dan kegagalan tulis). Fake Firestore meniru transaksi dengan antrean agar dua transaksi bersamaan tidak kehilangan hitungan.
  - Aturan diuji dengan Firestore Emulator (`firebase-tools` 15.34.0, Java dari Android Studio JBR) memakai `@firebase/rules-unit-testing` dan `firebase-admin` di luar repo. Seluruh 16 pemeriksaan lulus: pembuatan, kenaikan berulang, dua transaksi bersamaan, tanda tangan admin, pembukaan ulang log, penolakan `handled = true` tanpa scan, perubahan field lain, kenaikan lebih dari satu, UID orang lain, `scanCount` awal selain 1, ISBN tidak sama dengan ID, tamu, `get` vs `list`, daftar admin, dan tidak ada dokumen ganda. Skrip uji berada di direktori sementara dan tidak di-commit.
  - Verifikasi: `dart format .` tidak mengubah berkas, `flutter analyze` nol masalah, dan `flutter test` lulus (244 uji). Verifikasi pada perangkat Android dan layar pemindai belum dijalankan karena layar tersebut baru dibuat pada T-044.

### [x] T-035a Daftar log ISBN belum ditangani
- Bergantung pada: T-033, T-034
- Kerjakan: `/admin/isbn-logs` menampilkan antrean log ISBN belum ditangani di dalam shell admin, dengan paginasi dan keadaan memuat, galat, serta kosong.
- Selesai jika: daftar tampil terurut `lastScannedAt` menurun dan "Muat Lebih Banyak" bekerja tanpa duplikat.
- Catatan:
  - Rute `/admin/isbn-logs` sekarang memakai `AdminIsbnLogsScreen` di `lib/features/admin/presentation/`, menggantikan placeholder. Layar ini belum punya desain Stitch, jadi susunannya mengikuti PRD bagian 7 dan bahasa visual layar admin lain tanpa memanggil Stitch MCP: subjudul di atas daftar, satu kartu per log berisi ISBN, jumlah pemindaian, waktu terakhir dipindai, dan pil status "Belum ditangani", lalu tombol "Muat Lebih Banyak" di kaki daftar. Aksi per baris dikerjakan pada T-035b.
  - `IsbnLogRepository.fetchUnhandledPage` memakai filter `handled == false`, urutan `lastScannedAt` menurun, dan `limit + 1` untuk mengetahui `hasMore`. Halaman memakai `isbnLogPageSize` (20) dan maksimum 50; kursor `IsbnLogCursor` diteruskan lewat `startAfterDocument` sehingga halaman berikutnya tidak mengulang atau melewati baris. Indeks komposit `handled` + `lastScannedAt` sudah tersedia di `firestore.indexes.json`. Galat baca Firestore dipetakan ke pesan bahasa Indonesia lewat `mapFirestoreReadError`.
  - `AdminIsbnLogsController` dengan provider `autoDispose` mengelola halaman pertama, "Muat Lebih Banyak", muat ulang, dan keadaan memuat/galat lewat `AsyncValue<AdminIsbnLogsState>`. Penggabungan halaman membuang ISBN yang sudah ada, dan penghitung generasi mengabaikan respons halaman lama yang datang setelah muat ulang.
  - Waktu terakhir dipindai diformat `AppDateFormatter.dateTime` dengan locale `id_ID`, contoh "21 Oktober 2026, 14.05". Seluruh warna, tipografi, radius, dan jarak berasal dari token tema; tidak ada teks UI di luar `AppStrings`. Tata letak diuji pada 360x800 mode terang serta 640x360, 800x1280, dan 1280x800 mode gelap. Galat `IsbnLogFailure` dari repository ditampilkan apa adanya karena pesannya sudah ramah; galat lain memakai pesan umum tanpa detail teknis.
  - Uji baru: `test/isbn_log_repository_test.dart` (filter, urutan, batas 20 + 1, kursor, pemetaan galat), `test/admin_isbn_logs_controller_test.dart` (halaman pertama, muat lebih banyak tanpa duplikat, hanya memuat sekali, kosong, galat dan retry, kegagalan halaman berikutnya, respons lama), `test/admin_isbn_logs_screen_test.dart` (loading, data dan format tanggal, paginasi, kosong, galat, gagal muat lebih banyak, serta tata letak responsif), dan `test/date_formatter_test.dart`. `test/router_test.dart` dan `test/admin_dashboard_screen_test.dart` memakai `FakeIsbnLogRepository` agar tidak membutuhkan Firebase; uji navigasi dashboard tidak lagi mengharapkan placeholder Log ISBN.
  - Verifikasi: `dart format .` tanpa perubahan, `flutter analyze` nol masalah, dan `flutter test` lulus (267 uji). Verifikasi pada perangkat Android belum dijalankan di lingkungan ini.

### [ ] T-035 (T-035b) Aksi log ISBN
- Bergantung pada: T-033, T-034, T-035a
- Kerjakan: tambahkan aksi per baris pada daftar T-035a: "Tambah buku" (membuka T-033 dengan ISBN terisi) dan "Tandai ditangani".
- Selesai jika: kedua aksi berfungsi.
- Catatan:
  - Bagian daftar sudah dikerjakan pada T-035a. Task ini menyisakan kedua aksi per baris sesuai issue #8.

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
