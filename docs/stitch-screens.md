# Layar Stitch - Libria

Sumber desain UI Libria. Dibaca lewat Stitch MCP pada 13-14 Oktober 2026 dan
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

## Layar autentikasi

| Layar Stitch | ID layar | Rute aplikasi (PRD bagian 4) | Ekspor |
|---|---|---|---|
| Libria - Masuk Akun | `9e49eeff703444c9a38baa5eb57e3272` | `/login` | `masuk-akun.html`, `masuk-akun.png` |
| Libria - Daftar Akun Baru | `43d4c2e5b2c54ceaa954ded44334b3fe` | belum ada rute di PRD | `daftar-akun.html`, `daftar-akun.png` |

Kedua layar diambil pada 14 Oktober 2026, kanvas 390 x 884 px (ekspor 780 x
1768 px), mode terang. Layar Daftar Akun Baru direvisi pada hari yang sama
(lihat catatan di bagiannya). Dua versi lama layar yang sama,
`a8c612e9f4d8429688ee0b57f055b77b` dan `c286d3232053439ba7cdf7ca61cb073a`,
masih tersimpan di proyek Stitch tetapi tidak dipakai lagi; hapus manual lewat
UI Stitch bila perlu.

### Libria - Masuk Akun (`/login`)

Urutan elemen:

1. Lambang buku navy 64 px bersudut 16 px dengan huruf "L" putih dan pita
   penanda teal, di bawahnya garis teal pudar.
2. Judul "Libria" (Merriweather 30 px bold, navy).
3. Label "PERPUSTAKAAN DIGITAL PRIBADI" (12 px, uppercase, letter-spacing
   lebar, teal).
4. Kalimat "Selamat datang kembali. Masuk untuk melanjutkan petualangan
   membacamu." (12 px, muted, rata tengah).
5. Garis ornamen pemisah.
6. Form: "Email atau ID Anggota" (ikon surat, placeholder `nama@email.com`),
   "Kata Sandi" (ikon kunci, tombol lihat sandi), baris "Ingat Saya"
   (checkbox tercentang) dan tautan "Lupa Password?".
7. Tombol utama "MASUK" biru royal `#1B44C8` berteks putih dengan ikon panah,
   radius 12 px.
8. Pemisah "Atau masuk dengan:" dan tombol putih bergaris "Masuk dengan
   Google" (ikon Google 16 px).
9. Tautan "Belum punya akun? Daftar".
10. Bilah tab Beranda, Buku, Pengaturan, Profil (Profil ditandai aktif).

Catatan penyimpangan:

- Layar memakai palet sendiri `libria.*` (navy `#0C1E33`, deep `#102A43`,
  teal `#0F766E`, gold `#C29B38`, muted `#627D98`, border `#E2E8F0`) yang mirip
  tetapi tidak identik dengan palet Literary Elegance. Tombol utama memakai
  biru `#1B44C8` yang tidak ada di token mana pun.
- Keputusan pemilik 14 Oktober 2026 (dibarengi revisi PRD ke versi 1.1): login
  dan pendaftaran memakai email dan kata sandi atau Google, jadi seluruh form
  pada layar ini dipakai. Tautan "Lupa Password?" membuka layar lupa kata
  sandi yang belum ada di Stitch (spesifikasi PRD bagian 7).
- Bilah tab di bagian bawah tidak relevan untuk pengguna yang belum login.
- Saat implementasi tetap pakai token `lib/core/theme/` (AGENTS.md bagian 6);
  biru `#1B44C8` hanya dipakai bila pemilik memutuskan menambah token baru.

### Libria - Daftar Akun Baru

Urutan elemen:

1. Lencana navy 56 px bersudut 16 px berisi huruf "L" mint, miring 1 derajat.
2. Judul "Buat Akun Baru" (Merriweather 28 px bold) dan kalimat "Bergabung
   dengan komunitas pembaca Libria dan mulai perjalanan literasimu."
3. Kartu putih bersudut 24 px berisi "Nama Lengkap", "Email", "Kata Sandi"
   (placeholder "Minimal 8 karakter"), "Konfirmasi Kata Sandi" (kedua kolom
   sandi punya tombol lihat sandi), checkbox persetujuan dengan tautan "Syarat
   & Ketentuan" dan "Kebijakan Privasi", dan tombol "DAFTAR SEKARANG" dengan
   ikon panah.
4. Pemisah "Atau daftar dengan" dan tombol "Daftar dengan Google".
5. Kutipan "Membaca adalah jendela menuju ribuan kehidupan yang belum sempat
   dijalani." (Merriweather 13 px italic, rata tengah).
6. Tautan "Sudah punya akun? Masuk".

Catatan:

- Versi pertama layar ini ter-render sebagai wireframe abu-abu: HTML-nya
  memakai kelas token Material 3 (`bg-primary`, `text-on-surface`,
  `bg-surface-container-lowest`, `font-body-md`, dan sejenisnya) yang tidak
  didefinisikan di konfigurasi Tailwind layar itu. Layar diperbaiki pada
  14 Oktober 2026 lewat `edit_screens` di Stitch MCP: konfigurasi token diisi
  penuh (warna, fontFamily, fontSize, boxShadow) tanpa mengubah tata letak,
  urutan bagian, dan teks.
- Warna versi baru mengikuti Literary Elegance: lencana `primary` `#002045`
  dengan lapis `primaryContainer` `#1A365D` dan huruf `secondaryFixed`
  `#89F5E7`; kartu `surfaceContainerLowest` `#FFFFFF`; kolom input
  `surfaceContainerLow` `#F2F3FF` dengan garis `outlineVariant` dan ikon
  `outline` `#74777F`; fokus dan tautan `secondary` `#006A61`; tombol utama
  `primary` berteks `onPrimary`; tombol Google `surfaceContainerLowest`
  bergaris `outlineVariant`.
- Rute `/register` ditetapkan di PRD versi 1.1 bagian 4 dan dikerjakan pada
  T-016. Pendaftaran memakai email dan kata sandi (dengan verifikasi email)
  atau Google sesuai PRD bagian 5.1.


## Bilah navigasi bawah (redesain)

Desain memakai bilah navigasi mengambang dengan 5 item. Item aktif tampil
sebagai pil navy berisi ikon dan label putih; item tidak aktif memakai ikon
slate. Tombol tengah "Sesi Baca" berupa lingkaran teal dan bukan halaman tab.

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

- Tangkapan layar diambil pada lebar 780 px (2x dari kanvas 390 px).
- HTML layar tersimpan apa adanya untuk membaca struktur, teks, dan ukuran.
  Stitch menghasilkan HTML web; jangan disalin ke Flutter (AGENTS.md bagian 6).
- Layar yang sudah tercatat di sini tidak perlu dipanggil ulang lewat Stitch MCP.
