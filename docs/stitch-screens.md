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
| Libria - Daftar Akun Baru | `a8c612e9f4d8429688ee0b57f055b77b` | belum ada rute di PRD | `daftar-akun.html`, `daftar-akun.png` |

Kedua layar diambil pada 14 Oktober 2026, kanvas 390 x 884 px (ekspor 780 x
1768 px), mode terang.

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
- Form memuat email dan kata sandi, sedangkan PRD FR-A1 dan T-014 hanya
  menetapkan login Google.
- Bilah tab di bagian bawah tidak relevan untuk pengguna yang belum login.
- Saat implementasi tetap pakai token `lib/core/theme/` (AGENTS.md bagian 6);
  biru `#1B44C8` hanya dipakai bila pemilik memutuskan menambah token baru.

### Libria - Daftar Akun Baru

Urutan elemen:

1. Lambang kotak navy berisi huruf "L" mint, miring 1 derajat.
2. Judul "Buat Akun Baru" dan kalimat "Bergabung dengan komunitas pembaca
   Libria dan mulai perjalanan literasimu."
3. Kartu form putih bersudut 24 px berisi "Nama Lengkap", "Email", "Kata
   Sandi" (placeholder "Minimal 8 karakter"), "Konfirmasi Kata Sandi" (kedua
   kolom sandi punya tombol lihat sandi), checkbox persetujuan dengan tautan
   "Syarat & Ketentuan" dan "Kebijakan Privasi", dan tombol "DAFTAR SEKARANG"
   dengan ikon panah.
4. Pemisah "Atau daftar dengan" dan tombol "Daftar dengan Google".
5. Kutipan literasi miring rata tengah.
6. Tautan "Sudah punya akun? Masuk".

Catatan penting:

- Halaman ini memakai nama kelas token Material 3 (`bg-primary`,
  `text-on-surface`, `bg-surface-container-lowest`, `font-body-md`, dan
  sejenisnya) yang tidak didefinisikan di konfigurasi Tailwind layar itu
  (konfigurasi hanya memuat warna `libria.*`). Akibatnya warna dan tipografi
  tidak ter-render; tangkapan layar tampak wireframe abu-abu dan tombol tanpa
  isian.
- Warna yang dimaksud mengikuti token Literary Elegance: lambang `primary`
  `#002045` dengan lapis `primaryContainer` `#1A365D` dan huruf
  `secondaryFixed` `#89F5E7`; tombol utama `primary`; aksen tautan `secondary`
  `#006A61`; kartu `surfaceContainerLowest` `#FFFFFF`; kolom input
  `surfaceContainerLow` `#F2F3FF`.
- Rute `/register` belum ada di PRD bagian 4 dan T-014 belum mencakup layar
  ini, jadi perlu keputusan pemilik sebelum dipakai.

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
