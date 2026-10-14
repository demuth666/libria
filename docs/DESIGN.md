# DESIGN - Libria

Token desain dan pemetaan layar. Sumber: Stitch, project "Aesthetic Navbar
Redesign" (`2681203562337770535`), design system "Literary Elegance"
(`assets/0d8db770b91346d184451ebbae6b29e8`), dibaca lewat Stitch MCP pada
13-14 Oktober 2026. Ekspor HTML dan tangkapan layar ada di
`docs/design/stitch/`; daftar layar dan padanannya ada di
`docs/stitch-screens.md`.

Aturan pemakaian:

- Widget hanya memakai token dari `lib/core/theme/` atau peran dari
  `ColorScheme`/`TextTheme`: `AppColors` (skema `lightScheme`/`darkScheme` dan
  palet merek), `AppTextStyles`, `AppRadius`, `AppSpacing`, `AppShadows`, serta
  `AppSemanticColors` lewat `Theme.of(context).extension<AppSemanticColors>()`.
  Dilarang menulis warna hex atau ukuran font langsung di widget.
- Implementasi: `lib/core/theme/app_colors.dart`, `app_text_styles.dart`,
  `app_theme.dart` (Material 3, `AppTheme.light` dan `AppTheme.dark`).
- Stitch hanya menyediakan mode terang (`colorMode: LIGHT`). Mode gelap
  diturunkan dari keluarga tonal yang sama; lihat bagian 1.4.

## 1. Warna

### 1.1 Peran utama

| Peran ColorScheme | Light | Dark (turunan) |
|---|---|---|
| primary | `#002045` | `#ADC7F7` |
| onPrimary | `#FFFFFF` | `#0D284C` |
| primaryContainer | `#1A365D` | `#1A365D` |
| onPrimaryContainer | `#86A0CD` | `#D6E3FF` |
| secondary | `#006A61` | `#6BD8CB` |
| onSecondary | `#FFFFFF` | `#003833` |
| secondaryContainer | `#86F2E4` | `#005049` |
| onSecondaryContainer | `#006F66` | `#86F2E4` |
| tertiary | `#002521` | `#4FDBC8` |
| onTertiary | `#FFFFFF` | `#003832` |
| tertiaryContainer | `#003D36` | `#005048` |
| onTertiaryContainer | `#00B2A0` | `#71F8E4` |
| error | `#BA1A1A` | `#FFB4AB` |
| onError | `#FFFFFF` | `#690005` |
| errorContainer | `#FFDAD6` | `#93000A` |
| onErrorContainer | `#93000A` | `#FFDAD6` |

### 1.2 Warna tetap (fixed, sama di kedua mode)

| Peran ColorScheme | Nilai |
|---|---|
| primaryFixed | `#D6E3FF` |
| primaryFixedDim | `#ADC7F7` |
| onPrimaryFixed | `#001B3C` |
| onPrimaryFixedVariant | `#2D476F` |
| secondaryFixed | `#89F5E7` |
| secondaryFixedDim | `#6BD8CB` |
| onSecondaryFixed | `#00201D` |
| onSecondaryFixedVariant | `#005049` |
| tertiaryFixed | `#71F8E4` |
| tertiaryFixedDim | `#4FDBC8` |
| onTertiaryFixed | `#00201C` |
| onTertiaryFixedVariant | `#005048` |

### 1.3 Permukaan dan garis

| Peran ColorScheme | Light | Dark (turunan) |
|---|---|---|
| surface | `#FAF8FF` | `#0D1424` |
| onSurface | `#131B2E` | `#DAE2FD` |
| surfaceDim | `#D2D9F4` | `#0D1424` |
| surfaceBright | `#FAF8FF` | `#2F374B` |
| surfaceContainerLowest | `#FFFFFF` | `#090F1D` |
| surfaceContainerLow | `#F2F3FF` | `#131B2E` |
| surfaceContainer | `#EAEDFF` | `#171F31` |
| surfaceContainerHigh | `#E2E7FF` | `#222A3C` |
| surfaceContainerHighest | `#DAE2FD` | `#2C3447` |
| onSurfaceVariant | `#43474E` | `#C4C6CF` |
| outline | `#74777F` | `#8F9199` |
| outlineVariant | `#C4C6CF` | `#43474E` |
| inverseSurface | `#283044` | `#DAE2FD` |
| onInverseSurface | `#EEF0FF` | `#283044` |
| inversePrimary | `#ADC7F7` | `#2D476F` |
| surfaceTint | `#455F88` | `#ADC7F7` |
| shadow | `#0F172A` | `#000000` |

### 1.4 Penurunan mode gelap

Stitch hanya menghasilkan palet terang. Skema `darkScheme` diturunkan dari
keluarga warna yang sama dengan aturan Material 3:

- Peran utama memakai tone 80 dari keluarga terangnya: `primary` `#ADC7F7`,
  `secondary` `#6BD8CB`, `tertiary` `#4FDBC8` (sama dengan `*FixedDim`).
- `on-*` memakai tone gelap keluarga yang sama (`#0D284C`, `#003833`,
  `#003832`); container memakai tone 30 (`#1A365D`, `#005049`, `#005048`) dan
  on-container memakai tone 90 (`#D6E3FF`, `#86F2E4`, `#71F8E4`).
- Permukaan dan netral mengikuti keluarga navy netral kanvas terang:
  `surface` `#0D1424` dari `onSurface` terang, container `#090F1D` sampai
  `#2C3447`, teks utama `#DAE2FD`, varian `#C4C6CF`, garis `#8F9199`/`#43474E`.
- Pasangan error gelap memakai standar Material 3 (`#FFB4AB`/`#690005`) karena
  token error Stitch hanya ditetapkan untuk mode terang.

### 1.5 Warna naratif design system (rujukan)

Panduan gaya Stitch menyebut warna merek di luar palet tonal di atas; sebagian
sudah tersedia sebagai konstanta `AppColors`. Layar hasil generate memakai
palet bagian 1.1-1.3, jadi nilai berikut hanya rujukan dan tidak boleh ditulis
langsung di widget:

| Warna naratif | Token |
|---|---|
| `#1A365D` Deep Navy | `AppColors.deepNavy`; `primaryContainer` |
| `#0F2942` navy tekan | `AppColors.navyPressed` |
| `#0D9488` Deep Emerald Teal | `AppColors.emeraldTeal`; arah `secondary` |
| `#14B8A6` Soft Mint Teal | `AppColors.mintTeal`; arah `tertiary` |
| `#0F172A` Archival Slate | `AppColors.archivalSlate`; `shadow` skema terang |
| `#64748B` ikon nonaktif | `AppColors.slateIcon` |
| `#F1F5F9` trough segmented | `AppColors.slateTrough` |
| `#F8FAFC`, `#FDFBF7` kanvas | `AppColors.coolCanvas`, `AppColors.creamCanvas` |
| `#E2E8F0`, `#CBD5E1` garis | `AppSemanticColors.cardBorder`, `AppSemanticColors.inputBorder` |
| `#CCFBF1` + `#0F766E` chip | arah `secondaryContainer` + `onSecondaryContainer` |

### 1.6 Token tambahan (AppSemanticColors)

Token di luar peran Material 3 untuk komponen khas Libria, diambil lewat
`Theme.of(context).extension<AppSemanticColors>()`.

| Token | Light | Dark | Pemakaian |
|---|---|---|---|
| cardBorder | `#E2E8F0` | `#2A3246` | garis 1 px tepi kartu |
| inputBorder | `#CBD5E1` | `#43474E` | garis kolom input |
| glassSurface | `0xD9FFFFFF` | `0xD9222A3C` | dasar kaca bilah navigasi (putih 85%) |
| glassHeader | `0xCCFAF8FF` | `0xCC171F31` | dasar kaca header layar (putih 80%) |
| starRating | `#EAB308` | `#FACC15` | bintang rating |
| scrim | `0x660F172A` | `0x99000000` | latar dialog dan bottom sheet |

## 2. Tipografi

Font: Merriweather (judul) dan Plus Jakarta Sans (antarmuka). Keduanya
dibundel di `assets/fonts/` dengan lisensi OFL. Letter spacing Stitch memakai
satuan em; kolom terakhir sudah dikonversi ke piksel logis. Tinggi baris
dikonversi ke faktor `height` Material (line height dibagi ukuran font).

| Token Stitch | Font | Ukuran / line height | Weight | Letter spacing | Gaya Flutter |
|---|---|---|---|---|---|
| headline-xl | Merriweather | 36 / 48 | 700 | -0.02em (-0.72) | `AppTextStyles.headlineXl` |
| headline-xl-mobile | Merriweather | 28 / 36 | 700 | -0.01em (-0.28) | `AppTextStyles.headlineXlMobile` |
| headline-lg | Merriweather | 26 / 34 | 700 | - | `AppTextStyles.headlineLg` |
| headline-md | Merriweather | 20 / 28 | 700 | - | `AppTextStyles.headlineMd` |
| headline-sm | Merriweather | 16 / 24 | 700 | - | `AppTextStyles.headlineSm` |
| body-lg | Plus Jakarta Sans | 16 / 26 | 400 | - | `AppTextStyles.bodyLg` |
| body-md | Plus Jakarta Sans | 14 / 22 | 400 | - | `AppTextStyles.bodyMd` |
| body-sm | Plus Jakarta Sans | 12 / 18 | 400 | - | `AppTextStyles.bodySm` |
| label-lg | Plus Jakarta Sans | 14 / 20 | 600 | 0.01em (0.14) | `AppTextStyles.labelLg` |
| label-md | Plus Jakarta Sans | 12 / 16 | 600 | 0.02em (0.24) | `AppTextStyles.labelMd` |
| label-sm | Plus Jakarta Sans | 11 / 14 | 500 | - | `AppTextStyles.labelSm` |
| timer-display | Plus Jakarta Sans | 40 / 48 | 800 | 0.04em (1.6) | `AppTextStyles.timerDisplay` (angka tabular) |

Pemetaan ke slot `TextTheme` Material 3 (`AppTextStyles.textTheme`):

| Slot TextTheme | Token |
|---|---|
| displayLarge | timer-display |
| displayMedium | headline-xl |
| displaySmall | headline-xl-mobile |
| headlineLarge | headline-lg |
| headlineMedium | headline-md |
| headlineSmall | headline-sm |
| titleLarge | headline-md |
| titleMedium | headline-sm |
| titleSmall | label-lg |
| bodyLarge / bodyMedium / bodySmall | body-lg / body-md / body-sm |
| labelLarge / labelMedium / labelSmall | label-lg / label-md / label-sm |

`AppTextStyles.timerDisplay` juga bisa dipakai langsung untuk layar timer
(T-055).

## 3. Radius

| Token Stitch | Nilai | Konstanta Dart | Pemakaian |
|---|---|---|---|
| sm | 0.25rem = 4 px | `AppRadius.extraSmall` | checkbox |
| default | 0.5rem = 8 px | `AppRadius.small`, `AppRadius.allSmall` | sampul buku, thumbnail |
| md | 0.75rem = 12 px | `AppRadius.medium`, `AppRadius.allMedium` | kartu, tombol, input, segmented |
| lg | 1rem = 16 px | `AppRadius.large`, `AppRadius.allLarge` | kartu hero, baris daftar |
| xl | 1.5rem = 24 px | `AppRadius.extraLarge`, `AppRadius.allExtraLarge` | dialog, bottom sheet |
| full | 9999 px | `AppRadius.full`, `AppRadius.allFull` | chip, pil, avatar |

## 4. Jarak

| Token Stitch | Nilai | Konstanta Dart | Pemakaian |
|---|---|---|---|
| space-xs | 0.25rem = 4 px | `AppSpacing.xs` | jarak dalam komponen rapat |
| space-sm | 0.5rem = 8 px | `AppSpacing.sm` | jarak antar ikon dan label |
| space-md | 1rem = 16 px | `AppSpacing.md` | padding kartu, jarak antar elemen |
| space-lg | 1.5rem = 24 px | `AppSpacing.lg` | jarak antar bagian layar |
| space-xl | 2rem = 32 px | `AppSpacing.xl` | jarak antar blok besar |
| gutter | 1rem = 16 px | `AppSpacing.gridGutter` | jarak grid 2 kolom |
| gutter-sm | 0.75rem = 12 px | `AppSpacing.gridGutterSmall` | jarak grid 2 kolom (rapat) |
| margin | 1.25rem = 20 px | `AppSpacing.screenMargin` | margin tepi layar ponsel |
| margin-mobile | 1rem = 16 px | `AppSpacing.screenMarginSmall` | margin tepi layar sempit |

Catatan tata letak dari panduan Stitch: satu kolom untuk ponsel dengan margin
luar 20 px, kartu berpadding 16 px, dan pemisah antarbagian 16 px atau 24 px.

## 5. Elevasi

| Level | Nilai Stitch | Konstanta Dart | Pemakaian |
|---|---|---|---|
| 0 | tanpa bayangan | - | kanvas |
| 1 | `0 4px 16px -2px rgba(15,23,42,0.04)` + garis 1 px | `AppShadows.level1` | permukaan level 1 |
| 2 | `0 10px 30px -4px rgba(15,23,42,0.12)` + scrim | `AppShadows.level2` | modal dan bottom sheet |
| Kartu | setara shadow-sm `0 1px 2px rgba(0,0,0,0.05)` | `AppShadows.card` | kartu dan tile pada layar Stitch |
| Header | `0 1px 8px rgba(0,0,0,0.04)` | `AppShadows.header` | garis bayangan bawah header layar |
| Sampul | `0 6px 14px rgba(0,32,69,0.12)` | `AppShadows.cover` | sampul buku pada kartu |
| Nav | `0 -4px 20px rgba(15,23,42,0.05)` | `AppShadows.navigationBar` | bilah navigasi bawah |
| Kaca | blur 16 px (CSS) | `AppShadows.glassBlurSigma` (8) | `BackdropFilter` header dan navigasi |

Bayangan dipasang lewat `BoxShadow` pada komponen (bukan `elevation` Material)
agar sesuai bayangan lembut Stitch. `shadow` pada `lightScheme` memakai
`#0F172A` (Archival Slate).

## 6. Komponen (ringkasan panduan Stitch)

- Tombol utama: isian navy (`primary`) dengan teks putih, radius 12 px,
  padding vertikal 14 px, label `label-lg`.
- Tombol sekunder: latar transparan dengan garis 1.5 px warna `primary`.
- Aksi sesi/sukses (tombol "Lanjutkan Membaca", FAB "Tambah Buku"): isian teal
  (`secondary`) dengan teks putih.
- Bilah navigasi bawah: permukaan mengambang frosted (blur 16 px, putih 85%
  sesuai token `glassSurface`), indikator pil navy untuk item aktif, ikon slate
  untuk item tidak aktif.
- Chip dan segmented: bentuk pil penuh; chip status di layar Stitch memakai
  `secondaryContainer` dengan teks `onSecondaryContainer`.
- Kartu buku: sampul radius 8 px dengan rasio 2:3; judul Merriweather 14 bold;
  penulis Plus Jakarta Sans 12 slate.
- Input dan pencarian: latar putih, garis `outlineVariant`, radius 12 px,
  fokus berpindah ke `secondary` dengan garis 1.5 px.
- Callout jurnal: kartu tint dengan garis kiri 3 px `secondary`, kutipan
  Merriweather italic.
- Layar autentikasi (Masuk Akun, Daftar Akun Baru): lambang buku navy dengan
  pita atau huruf mint, judul Merriweather, subjudul teal uppercase dengan
  letter-spacing lebar, kolom input putih atau lavender dengan ikon depan dan
  radius 12 px, tombol "Masuk dengan Google" berupa tombol putih bergaris
  dengan ikon Google, serta pemisah "Atau masuk dengan". Pemetaan warna dan
  catatan penyimpangan kedua layar ada di `docs/stitch-screens.md`.

Implementasi tema (T-004) sudah mengatur gaya dasar untuk: AppBar,
NavigationBar (kaca), Card, Chip, InputDecoration, FilledButton,
OutlinedButton, TextButton, IconButton, BottomSheet, Dialog, SnackBar,
Checkbox, Radio, Switch, Divider, ProgressIndicator, dan ListTile.
Komponen bersama di T-005 dibangun di atas tema ini.

## 7. Pemetaan layar

| Layar Stitch | ID | Rute aplikasi | Ekspor |
|---|---|---|---|
| Libria - Beranda & Dasbor Membaca | `539c298ebf244868a18e30a14323f8cf` | `/home` | `docs/design/stitch/beranda.*` |
| Libria - Koleksi Saya | `b5d9431b60e74d5e8d1aec57eb6cfe5c` | `/home/library` | `docs/design/stitch/koleksi.*` |
| Libria - Komunitas Literasi | `34a5279f8709401ca6fb616840a041dc` | `/home/community` | `docs/design/stitch/komunitas.*` |
| Libria - Profil & Ringkasan Pengguna | `f8641f6ee84c4d80ac3f58b371d42cae` | `/home/settings` | `docs/design/stitch/profil.*` |
| Libria - Masuk Akun | `9e49eeff703444c9a38baa5eb57e3272` | `/login` | `docs/design/stitch/masuk-akun.*` |
| Libria - Daftar Akun Baru | `43d4c2e5b2c54ceaa954ded44334b3fe` | `/register` | `docs/design/stitch/daftar-akun.*` |

Rincian elemen dan penyimpangan layar autentikasi ada di
`docs/stitch-screens.md` bagian "Layar autentikasi". Layar Lupa Kata Sandi
belum ada di Stitch dan memakai spesifikasi PRD bagian 7.

Delapan layar referensi lain (unggahan pemilik) beserta perkiraan rutenya
dicatat di `docs/stitch-screens.md`. Layar yang belum ada di Stitch memakai
spesifikasi PRD bagian 7 dan dicatat di Catatan task masing-masing.
