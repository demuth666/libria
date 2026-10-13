# Layar Stitch - Libria

Sumber desain UI Libria. Dibaca lewat Stitch MCP pada 13 Oktober 2026 dan
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
