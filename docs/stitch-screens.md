# Layar Stitch - Libria

Sumber desain UI Libria. Dibaca lewat Stitch MCP pada 13-14 Oktober 2026,
lalu layar autentikasi dan splash diperbarui pada 17 Oktober 2026. Hasilnya
diekspor ke `docs/design/stitch/` agar tidak perlu memanggil ulang layar yang
sama (kuota MCP terbatas). Token desain ada di `docs/DESIGN.md`.

## Proyek

- Nama: Aesthetic Navbar Redesign
- ID proyek: `2681203562337770535`
- Tipe: MOBILE, TEXT_TO_UI_PRO, visibility PRIVATE
- Design system: Literary Elegance (`assets/0d8db770b91346d184451ebbae6b29e8`)

## Layar utama

| Layar Stitch | ID layar | Rute aplikasi (PRD bagian 4) | Ekspor |
|---|---|---|---|
| Libria - Beranda & Dasbor Membaca | `539c298ebf244868a18e30a14323f8cf` | `/home` | `beranda.html`, `beranda.png` |
| Libria - Koleksi Saya | `b5d9431b60e74d5e8d1aec57eb6cfe5c` | `/home/library` | `koleksi.html`, `koleksi.png` |
| Libria - Komunitas Literasi | `34a5279f8709401ca6fb616840a041dc` | `/home/community` | `komunitas.html`, `komunitas.png` |
| Libria - Profil & Ringkasan Pengguna | `f8641f6ee84c4d80ac3f58b371d42cae` | `/home/settings` | `profil.html`, `profil.png` |

Layar `/book/:id` (Detail Buku) tidak ada di Stitch. Jangan memanggil Stitch
MCP untuk layar ini; susunannya mengikuti PRD bagian 5.3 dan 7 serta bahasa
visual Koleksi (T-043).

Layar pemindai ISBN (`/scan`, T-044) juga tidak ada di Stitch. Daftar layar
proyek diperiksa ulang lewat Stitch MCP pada 22 Oktober 2026 dan tidak memuat
layar pemindai. Susunannya mengikuti PRD bagian 5.3 (FR-L5) dan bahasa visual
Koleksi/detail buku, dengan pratinjau kamera dan panel hasil di bagian bawah.

Layar pengaturan sesi (`/session/setup`, T-052) juga tidak ada di Stitch.
Daftar layar proyek diperiksa ulang lewat Stitch MCP pada 23 Oktober 2026 dan
tetap hanya memuat Beranda, Koleksi, Komunitas, Profil, tiga layar autentikasi,
serta Splash Screen. Susunannya mengikuti PRD bagian 5.4 (FR-S1 dan FR-S2) dan
bahasa visual Koleksi/detail buku: header kaca, kartu buku terpilih, pemilih
sumber buku, dan panel target menit tetap di bagian bawah. Tombol pindai ISBN
membuka layar pemindai yang sama dalam mode pemilihan buku.

Layar timer sesi (`/session/run`, T-055) tidak ada di Stitch. Pemeriksaan daftar
layar pada 23 Oktober 2026 yang sama juga tidak menemukan layar timer. Susunannya
mengikuti PRD bagian 5.4 (FR-S3, FR-S4, dan FR-S6) dan bahasa visual
Koleksi/detail buku: header kaca dengan judul buku saja tanpa bab, kartu timer
dengan angka besar memakai token `timer-display`, target durasi, bilah progres,
serta panel aksi tetap berisi Jeda/Lanjut dan Selesai. Tidak ada layar baru yang
perlu ditambahkan ke tabel proyek.

## Layar autentikasi dan splash

| Layar Stitch | ID layar | Rute aplikasi (PRD bagian 4) | Ekspor |
|---|---|---|---|
| Libria - Masuk Akun | `aa4f2efeb635478d93d2237433c77fca` | `/login` | `masuk-akun.html`, `masuk-akun.png` |
| Libria - Daftar Akun Baru | `c5cccaa142f14acfa8e009cdc49ac389` | `/register` | `daftar-akun.html`, `daftar-akun.png` |
| Libria - Splash Screen | `0ad5036a0beb41d991455e2181bc39e0` | `/splash` | `splash-screen.html`, `splash-screen.png` |

Ketiga layar diambil pada 17 Oktober 2026, mode terang. Tangkapan layar asli
selebar 390 px: Masuk Akun 390 x 710 px, Daftar Akun Baru 390 x 1026 px, dan
Splash Screen 390 x 740 px. Kedua layar autentikasi menggantikan versi
sebelumnya (`9e49eeff703444c9a38baa5eb57e3272` dan
`43d4c2e5b2c54ceaa954ded44334b3fe`) yang sudah tidak ada di proyek Stitch.
Layar Splash baru ditambahkan pada tanggal yang sama. Ketiganya sekarang
memakai palet Literary Elegance tanpa warna di luar token.

### Libria - Masuk Akun (`/login`)

Urutan elemen:

1. Latar gradien vertikal `surface` ke `surfaceBright` lalu
   `surfaceContainerLow`.
2. Monogram 64 px bersudut 16 px berwarna `primary`, berisi huruf "L" putih
   miring 34 px, dengan dua lingkaran dekoratif (`secondaryFixed` 40% dan
   `secondary` 30%) dan lencana 24 px `secondaryContainer` berisi ikon
   `auto_stories` 14 px di sudut kanan bawah.
3. Judul "Selamat Datang Kembali" (Merriweather 26/34 bold, `primary`, rata
   tengah).
4. Kalimat "Masuk untuk melanjutkan petualangan membacamu dan membuka catatan
   refleksi pribadimu." (Plus Jakarta Sans 12/18, `onSurfaceVariant`, maksimal
   320 px, rata tengah).
5. Kartu putih `surfaceContainerLowest` bersudut 16 px, padding 20 px, dengan
   bayangan `0 4px 24px -2px rgba(0,32,69,0.06)`.
6. Di dalam kartu: "Email" (ikon `mail`, placeholder `nama@email.com`) dan
   "Kata Sandi" (ikon `lock`, tombol lihat sandi). Latar kolom
   `surfaceContainerLow` bersudut 12 px, ikon `onSurfaceVariant`.
7. Baris "Ingat Saya" dengan checkbox 16 px tercentang (`secondary` saat
   aktif) dan tautan "Lupa Kata Sandi?" (`secondary`, label 12 px).
8. Tombol utama "Masuk ke Akun" dengan ikon `arrow_forward`, latar `primary`,
   teks `onPrimary`, radius 12 px.
9. Pemisah "ATAU MASUK DENGAN" (label 11 px uppercase) di atas garis
   `surfaceContainerHigh`.
10. Tombol "Masuk dengan Google" berlatar `surfaceContainerLow` bersudut
    12 px dengan ikon Google 16 px (bukan tombol bergaris).
11. Footer "Belum memiliki akun Libria?" (14 px, `onSurfaceVariant`) dan
    tautan "Daftar Sekarang" (14 px bold, `primary`, garis bawah
    `secondaryContainer` 2 px).

Catatan:

- Layar ini tidak lagi memuat bilah tab bawah, label "PERPUSTAKAAN DIGITAL
  PRIBADI", atau tautan "Email atau ID Anggota". Kolom pertama kini berlabel
  "Email", sesuai konsep aplikasi.
- Checkbox "Ingat Saya" tetap tercentang pada desain. Aplikasi tidak
  menyediakan opsi lupa sesi (FR-A6), jadi checkbox hanya menjadi penanda
  visual atau dihilangkan bila tidak diperlukan.
- Nilai email dan kata sandi pada HTML adalah contoh pengisian; implementasi
  memulai dengan kolom kosong.
- Tautan "Lupa Kata Sandi?" membuka `/forgot-password` yang belum ada di
  Stitch dan memakai spesifikasi PRD bagian 7. Tautan "Daftar Sekarang"
  membuka `/register`.
- Tombol Google pada desain baru memakai latar `surfaceContainerLow`, bukan
  putih bergaris.

### Libria - Daftar Akun Baru (`/register`)

Urutan elemen:

1. Panel atas bergradien `primaryContainer` 10% ke `surfaceContainer` lalu
   `surfaceContainerLow`, bersudut 16 px, padding 24 px, dengan dua lingkaran
   blur dekoratif (`secondaryContainer` 30% dan `primaryFixed` 40%).
2. Lencana navy 56 px bersudut 16 px berisi huruf "L" 26 px miring.
3. Judul "Buat Akun Baru" (Merriweather 28/36 bold, `primary`, rata tengah).
4. Kalimat "Bergabung dengan ribuan pembaca Libria dan bangun kebiasaan
   literasi terbaikmu." (Plus Jakarta Sans 14/22, `onSurfaceVariant`).
5. Pil putih `surfaceContainerLowest` berisi ikon `auto_stories` terisi dan
   teks "3.420+ Buku Dibaca Pekan Ini" (11 px semibold, `secondary`), radius
   penuh.
6. Kartu putih bersudut 16 px, padding 24 px, berisi:
   - "Nama Lengkap" dengan petunjuk "Wajib diisi" di sisi kanan, ikon
     `person`, placeholder "Siti Nurhaliza".
   - "Alamat Email" dengan ikon `mail`, placeholder `nama@email.com`.
   - "Kata Sandi" dengan petunjuk "Minimal 8 karakter" (`secondary`), ikon
     `lock`, tombol lihat sandi.
   - "Konfirmasi Kata Sandi" dengan ikon `verified_user`, placeholder "Ulangi
     kata sandi", tombol lihat sandi.
   - Latar kolom `surfaceContainerLow` bersudut 12 px; saat fokus berubah
     menjadi `surfaceContainerLowest` dengan bayangan tipis.
7. Checkbox persetujuan 20 px dengan teks "Saya menyetujui Syarat & Ketentuan
   serta Kebijakan Privasi Libria."; kedua tautan berwarna `secondary`
   semibold.
8. Tombol utama "DAFTAR SEKARANG" dengan ikon `arrow_forward`, latar
   `primary`, radius 12 px.
9. Pemisah "ATAU DAFTAR DENGAN" di atas garis `surfaceContainerHigh`.
10. Tombol "Daftar dengan Google" berlatar `surfaceContainerLow` bersudut
    12 px dengan ikon Google 20 px.
11. Footer "Sudah punya akun Libria? Masuk di sini" (`secondary` bold).

Catatan:

- Kutipan "Membaca adalah jendela..." yang ada pada versi lama sudah dihapus;
  elemen pembungkusnya masih kosong di HTML.
- Petunjuk "Wajib diisi" dan "Minimal 8 karakter", serta pil statistik
  komunitas, adalah tambahan pada revisi ini.
- Placeholder nama adalah contoh; implementasi memakai kolom kosong.
- Rute `/register` dan alur pendaftaran email/Google mengikuti PRD bagian 4
  dan 5.1 (verifikasi email setelah akun dibuat).

### Libria - Splash Screen (`/splash`)

Urutan elemen:

1. Latar `surface` dengan dua lingkaran blur dekoratif (`secondaryFixed` 20%
   dan `primaryFixed` 25%) serta motif garis halaman arsip beropasitas 3,5%.
2. Di tengah: ikon aplikasi 96 px bersudut 24 px bergradien `primary` ke
   `primaryContainer`, dengan cincin cahaya. Di dalamnya ilustrasi buku
   terbuka (halaman `surface` dan `surfaceVariant`, garis tengah
   `primaryContainer`) dengan pita penanda `secondaryFixed`.
3. Judul "Libria" (Merriweather 28/36 bold, `primary`).
4. Garis pemisah 32 px `outlineVariant` di kiri dan kanan ikon
   `auto_stories` 14 px `secondary`.
5. Kalimat "Ruang tenang untuk membaca, mencatat refleksi, dan menjelajahi
   samudera literasi." (12/18, `onSurfaceVariant`, maksimal 270 px).
6. Kartu kutipan putih 90% dengan garis kiri 4 px `secondary`, ikon
   `format_quote` `secondary` 40%, kutipan "Membaca adalah jendela menuju
   ribuan kehidupan yang belum sempat dijalani." (Merriweather 16/24 italic),
   dan keterangan "Catatan Perjalanan Literasi" (11 px).
7. Bilah progres 6 px berlatar `surfaceContainerHigh`, isi bergradien
   `secondary` ke `secondaryFixed`, radius penuh.
8. Baris status "SELAMAT MEMBACA." (11 px uppercase, `outline`) dan "100%"
   (11 px bold, `onSurfaceVariant`).
9. Footer ikon `edit_note` dan teks "Libria v2.4 • Literary Elegance"
   (11 px, `outline`).

Catatan:

- Status bar (jam, sinyal, baterai) dan bilah home di bawah adalah chrome
  sistem, bukan bagian UI aplikasi.
- HTML menganimasikan progres dari 65% ke 100% dengan label
  "Menyiapkan Rak Pilihan...", "Menyinkronkan Kutipan...", lalu "Selamat
  Membaca.". Implementasi sebaiknya mengikat progres ke pemeriksaan status
  login/sesi, bukan timer hiasan.
- Teks versi "v2.4" adalah placeholder desain; aplikasi memakai versi paket
  atau menghilangkan baris versi bila tidak diperlukan.
- Splash Screen belum pernah ada di Stitch sebelumnya, jadi tidak ada versi
  lama yang perlu dihapus.


## Bilah navigasi bawah (redesain)

Desain memakai bilah navigasi selebar layar yang menempel di tepi bawah
(bukan mengambang), dengan latar `surface-container-lowest` 85% + blur 16 px
dan bayangan ke atas. Setiap item menampilkan ikon 22 px di atas label 11 px.
Item aktif berupa kotak navy `primaryContainer` radius 12 px berisi ikon dan
label putih; item tidak aktif memakai ikon dan label `onSurfaceVariant`.
Tombol tengah "Sesi Baca" berupa lingkaran 24 px `secondaryContainer` berisi
`play_arrow` 18 px dan label `secondary` semibold; tombol ini bukan halaman
tab.

| Item | Membuka |
|---|---|
| Beranda | `/home` |
| Koleksi | `/home/library` |
| Sesi Baca (tombol tengah) | `/session/setup` |
| Komunitas | `/home/community` |
| Profil | `/home/settings` |

Catatan: desain tidak memuat tab Statistik terpisah. Rute `/home/stats` tetap
ada sesuai PRD; ringkasan statistik tampil di Beranda dan di Profil. Susunan
akhir shell ditetapkan pada T-007.

## Layar referensi (unggahan tersembunyi)

Project Stitch juga memuat 8 gambar referensi pemilik (tersembunyi di kanvas).
Berkasnya ada di `docs/design/stitch/reference/`. Cakupan rute di bawah adalah
perkiraan dari nama gambar.

| Berkas | Layar sumber (ID) | Perkiraan cakupan |
|---|---|---|
| `autentikasi.png` | `11485063809516733330` | Login dan akun pengguna (`/login`, `/home/settings`) |
| `pelacakan-aktivitas.png` | `11485063809516732702` | Sesi dan aktivitas membaca (`/session/*`, `/home/stats`) |
| `katalog-isbn.png` | `11485063809516734486` | Katalog dan identifikasi buku (pencarian, `/book/:id`, scan ISBN) |
| `manajemen-koleksi.png` | `11485063809516736220` | Perpustakaan pengguna (`/home/library`) |
| `manajemen-admin.png` | `11485063809516735642` | Area admin (`/admin/*`) |
| `komunitas-interaksi.png` | `11485063809516735064` | Feed dan interaksi (`/home/community`, `/post/:id`) |
| `pelaporan-statistik.png` | `11485063809516733280` | Laporan dan statistik (`/report`, `/home/stats`) |
| `jurnal-refleksi.png` | `11485063809516733908` | Jurnal refleksi (`/journal`, `/journal/new`) |

## Catatan pengambilan

- Tangkapan layar lama (Beranda, Koleksi, Komunitas, Profil) diambil pada lebar
  780 px (2x dari kanvas 390 px). Tiga layar terbaru tersedia pada resolusi
  asli 390 px sehingga diekspor apa adanya.
- HTML layar tersimpan apa adanya untuk membaca struktur, teks, dan ukuran.
  Stitch menghasilkan HTML web; jangan disalin ke Flutter (AGENTS.md bagian 6).
- Layar yang sudah tercatat di sini tidak perlu dipanggil ulang lewat Stitch MCP.
