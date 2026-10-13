# PRD - Libria

Versi 1.0. Platform: Android (Flutter). Backend: Firebase. Bahasa antarmuka: Indonesia.

## 1. Ringkasan

Libria membantu pembaca membangun kebiasaan membaca. Pengguna mencatat buku yang dibaca, menjalankan sesi membaca dengan timer dan target, menulis jurnal refleksi, memberi ulasan, melihat statistik, mencetak laporan membaca, dan berinteraksi di komunitas. Admin mengelola katalog buku, moderasi komunitas, serta kegiatan dan tantangan.

Tujuan produk:
- Membuat sesi membaca mudah dimulai dan tidak terganggu (timer tetap berjalan saat layar mati).
- Memberi gambaran kemajuan membaca yang jelas (statistik dan laporan).
- Membangun komunitas pembaca yang aman lewat moderasi.

## 2. Role

| Role | Cara mendapatkan | Kemampuan utama |
|---|---|---|
| User | Otomatis saat pertama login Google | Perpustakaan pribadi, sesi membaca, jurnal, ulasan, statistik, laporan PDF, komunitas, kegiatan, tantangan |
| Admin | Diatur manual di Firebase Console (ubah field `role` menjadi `admin`) | Kelola katalog buku, lihat log ISBN, moderasi laporan, kelola kegiatan dan tantangan |

Satu aplikasi untuk dua role. Setelah login, router mengarahkan user ke area user dan admin ke area admin.

## 3. Keputusan produk

| Topik | Keputusan |
|---|---|
| Arsitektur | Satu aplikasi, routing berdasarkan role |
| Backend | Firebase (Auth, Firestore, Storage) |
| State management | Riverpod |
| Bahasa | Indonesia saja |
| Offline | Didukung (persistensi offline Firestore) |
| Dark mode | Didukung |
| Login | Hanya Google |
| Data buku | Diinput manual oleh admin |
| Scan ISBN tidak ditemukan | Menampilkan pesan error dan tercatat sebagai log |
| Ulasan buku | Ada |
| Peminjaman buku | Tidak ada |
| Scan ISBN saat sesi membaca | Tidak wajib |
| Timer | Tetap berjalan di latar belakang saat layar mati |
| Target tercapai | Alarm getar dan timer berhenti |
| Header timer | Hanya judul buku (tanpa bab) |
| Status Selesai | Otomatis saat halaman terakhir sama dengan total halaman, atau lewat ubah status manual |
| Jurnal refleksi | Teks biasa |
| Komunitas | Lengkap: balasan, like, buat postingan, laporan, notifikasi, kegiatan, tantangan |
| Laporan PDF | Hanya untuk dicetak ke kertas, tanpa role guru |
| Prioritas | Semua fitur prioritas (tenggat dekat) |

## 4. Arsitektur teknis

Lihat `AGENTS.md` untuk daftar paket, struktur folder, dan konvensi kode.

Rute utama (go_router):

| Rute | Layar | Akses |
|---|---|---|
| `/splash` | Splash | Semua |
| `/login` | Login Google | Belum login |
| `/home` | Shell user dengan navigasi bawah | User |
| `/home/library`, `/home/community`, `/home/stats`, `/home/settings` | Tab shell user | User |
| `/book/:id` | Detail buku | User |
| `/session/setup`, `/session/run`, `/session/finish` | Alur sesi membaca | User |
| `/journal`, `/journal/new` | Jurnal refleksi | User |
| `/report` | Laporan PDF | User |
| `/notifications` | Notifikasi | User |
| `/events`, `/events/:id`, `/challenges`, `/challenges/:id` | Kegiatan dan tantangan | User |
| `/post/:id` | Detail postingan dan balasan | User |
| `/admin` | Dashboard admin | Admin |
| `/admin/books`, `/admin/books/new`, `/admin/books/:id/edit` | Kelola buku | Admin |
| `/admin/isbn-logs` | Log ISBN | Admin |
| `/admin/reports` | Moderasi laporan | Admin |
| `/admin/events`, `/admin/challenges` | Kelola kegiatan dan tantangan | Admin |

Susunan tab navigasi bawah mengikuti desain di Stitch. Jika Stitch tidak menentukan: Beranda, Perpustakaan, Komunitas, Statistik, Pengaturan.

Redirect router:
- Belum login: selalu ke `/login`.
- Sudah login dan role admin: ke `/admin`. Role user: ke `/home`.
- User yang membuka rute `/admin/*` ditolak dan dikembalikan ke `/home`.

## 5. Kebutuhan fungsional

### 5.1 Autentikasi
- FR-A1: Login dengan Google lewat Firebase Auth.
- FR-A2: Saat login pertama, buat dokumen `users/{uid}` dengan `role = user`.
- FR-A3: Sesi login bertahan setelah aplikasi ditutup. Logout tersedia di Pengaturan dan Dashboard Admin dengan dialog konfirmasi.
- FR-A4: Jika login dibatalkan atau gagal, tampilkan pesan yang jelas dan tetap di layar login.

### 5.2 Katalog buku (admin)
- FR-B1: Admin menambah buku secara manual dengan field: judul, penulis, ISBN, penerbit, tahun terbit, jumlah halaman, kategori, sinopsis, sampul (opsional).
- FR-B2: Admin mengubah dan menghapus buku. Penghapusan meminta konfirmasi.
- FR-B3: ISBN harus unik. Validasi panjang 10 atau 13 digit dan tolak duplikat.
- FR-B4: Daftar buku admin bisa dicari berdasarkan judul, penulis, atau ISBN.
- FR-B5: Admin melihat Log ISBN (ISBN yang dipindai pengguna tetapi tidak ditemukan) dan bisa menekan "Tambah buku" untuk membuka formulir dengan ISBN terisi, serta menandai log sebagai sudah ditangani.

### 5.3 Perpustakaan pribadi (user)
- FR-L1: Pengguna mencari buku di katalog (judul, penulis, ISBN) dan melihat detail buku.
- FR-L2: Pengguna menambahkan buku ke rak dengan status: Ingin Dibaca, Sedang Dibaca, Selesai.
- FR-L3: Pengguna mengubah status secara manual kapan saja.
- FR-L4: Pengguna memperbarui halaman terakhir yang dibaca. Jika halaman terakhir sama dengan total halaman, status otomatis menjadi Selesai dan tanggal selesai tercatat.
- FR-L5: Scan ISBN memakai kamera. Jika ISBN ada di katalog, buka detail buku dan tawarkan tambah ke rak. Jika tidak ada, tampilkan pesan "Buku dengan ISBN ... tidak ditemukan" dan simpan log ISBN.
- FR-L6: Perpustakaan tetap bisa dibuka saat offline.

### 5.4 Sesi membaca
- FR-S1: Pengguna memilih buku dari perpustakaan atau katalog (scan ISBN hanya jalan pintas, tidak wajib), lalu menetapkan target durasi dalam menit.
- FR-S2: Jika buku belum ada di perpustakaan, otomatis ditambahkan dengan status Sedang Dibaca.
- FR-S3: Layar timer menampilkan judul buku saja pada header (tanpa bab), waktu berjalan, target, dan tombol Selesai. Tombol Jeda dan Lanjut mengikuti desain di Stitch.
- FR-S4: Timer dihitung dari cap waktu (waktu mulai dan akumulasi jeda), bukan dari hitungan detik di memori, sehingga akurat setelah layar mati atau aplikasi dimatikan sistem.
- FR-S5: Timer tetap berjalan saat layar mati atau aplikasi di latar belakang (foreground service dengan notifikasi berkelanjutan).
- FR-S6: Saat target tercapai: perangkat bergetar (pola alarm), notifikasi muncul, dan timer berhenti pada nilai target.
- FR-S7: Saat menekan Selesai (atau setelah target tercapai), pengguna mengisi halaman terakhir. Sesi disimpan: buku, waktu mulai, waktu selesai, durasi, halaman awal, halaman akhir, apakah target tercapai.
- FR-S8: Setelah sesi disimpan, perbarui halaman terakhir buku dan terapkan aturan status otomatis (FR-L4), lalu tawarkan menulis jurnal refleksi (boleh dilewati).
- FR-S9: Jika aplikasi dimatikan sistem saat sesi berjalan, sesi aktif dipulihkan saat aplikasi dibuka lagi.
- FR-S10: Riwayat sesi dapat dilihat per buku dan secara keseluruhan.

### 5.5 Jurnal refleksi
- FR-J1: Tambah, lihat, ubah, hapus entri jurnal berupa teks biasa, terkait satu buku (dan opsional satu sesi).
- FR-J2: Daftar jurnal dapat disaring per buku dan diurutkan terbaru lebih dulu.

### 5.6 Ulasan buku
- FR-R1: Pengguna memberi rating 1 sampai 5 dan teks ulasan pada sebuah buku. Satu pengguna satu ulasan per buku, dapat diubah dan dihapus.
- FR-R2: Detail buku menampilkan rata-rata rating, jumlah ulasan, dan daftar ulasan.

### 5.6b Statistik
- FR-T1: Tampilkan total menit membaca, total halaman, jumlah buku selesai, dan runtutan hari membaca berturut-turut (streak).
- FR-T2: Grafik batang menit membaca per hari untuk 7 hari dan 30 hari terakhir.

### 5.7 Laporan PDF
- FR-P1: Pengguna memilih rentang tanggal (default bulan berjalan).
- FR-P2: Laporan berisi nama pengguna, rentang, total menit, total halaman, daftar buku yang dibaca dan selesai, serta ringkasan sesi per hari.
- FR-P3: Laporan dibuat dengan paket `pdf` dan dicetak lewat dialog cetak sistem (`printing`). Tidak ada role guru dan tidak ada fitur kirim.

### 5.8 Komunitas
- FR-K1: Feed postingan terbaru dengan paginasi.
- FR-K2: Buat postingan teks, opsional menautkan satu buku.
- FR-K3: Balas postingan. Jumlah balasan tampil di feed.
- FR-K4: Like dan batal like. Satu pengguna satu like per postingan.
- FR-K5: Laporkan postingan atau balasan dengan alasan: Spam, Kata kasar, Konten tidak pantas, Lainnya.
- FR-K6: Penulis dapat menghapus postingan atau balasannya sendiri.
- FR-K7: Admin melihat daftar laporan terbuka, lalu memilih Hapus konten atau Abaikan. Status laporan berubah menjadi selesai.
- FR-K8: Notifikasi dalam aplikasi untuk: balasan pada postingan saya, like pada postingan saya, kegiatan atau tantangan baru. Daftar notifikasi menampilkan penanda belum dibaca dan lencana jumlah di ikon.

### 5.9 Kegiatan
- FR-E1: Admin membuat, mengubah, dan menghapus kegiatan: judul, deskripsi, tanggal dan jam, lokasi atau tautan.
- FR-E2: Pengguna melihat daftar kegiatan mendatang, membuka detail, dan menekan Ikut atau Batal Ikut. Jumlah peserta tampil.

### 5.10 Tantangan
- FR-C1: Admin membuat, mengubah, dan menghapus tantangan: judul, deskripsi, jenis (jumlah buku selesai atau jumlah menit membaca), target angka, tanggal mulai dan selesai.
- FR-C2: Pengguna melihat daftar tantangan aktif, bergabung, dan melihat progres sendiri.
- FR-C3: Progres peserta diperbarui otomatis saat sesi disimpan (menit) atau saat buku menjadi Selesai (jumlah buku) selama tantangan aktif.
- FR-C4: Tampilan papan peringkat sederhana (10 teratas berdasarkan progres) di detail tantangan.

### 5.11 Pengaturan
- FR-G1: Menampilkan profil (foto, nama, email) dari akun Google.
- FR-G2: Pilihan tampilan: Ikuti sistem, Terang, Gelap. Pilihan tersimpan.
- FR-G3: Versi aplikasi dan tombol Keluar.

## 6. Offline

- Persistensi Firestore aktif. Data yang pernah dimuat bisa dibaca saat offline.
- Tulis saat offline (sesi, jurnal, status buku, like) masuk antrean Firestore dan terkirim saat online.
- Daftar perpustakaan menyimpan salinan ringkas buku (judul, penulis, sampul, total halaman) agar tampil tanpa mengambil dokumen buku.
- Banner kecil "Anda sedang offline" tampil saat tidak ada koneksi.
- Fitur yang butuh koneksi dan menampilkan pesan jelas saat offline: login pertama, unggah sampul, scan ISBN pada buku yang belum pernah dimuat.

## 7. Spesifikasi layar yang belum ada di Stitch

Gunakan bagian ini hanya jika layar tidak ditemukan di Stitch. Warna, tipografi, dan komponen tetap dari token tema.

**Splash**
- Logo dan nama Libria di tengah, indikator loading di bawah.
- Memeriksa status login dan role, lalu mengarahkan ke `/login`, `/home`, atau `/admin`.

**Beranda (user)**
- Sapaan "Halo, {nama depan}".
- Kartu "Sedang Dibaca": sampul, judul, penulis, bar progres (halaman terakhir dari total), tombol "Lanjut Membaca" yang membuka pengaturan sesi dengan buku terpilih. Jika tidak ada buku yang sedang dibaca, tampilkan ajakan memilih buku.
- Ringkasan hari ini: menit membaca dan halaman.
- Aksi cepat: Mulai Sesi, Scan ISBN.
- Tantangan aktif (maksimal 2) dengan bar progres, dan kegiatan terdekat (maksimal 2).
- Ikon lonceng dengan lencana jumlah notifikasi belum dibaca di pojok atas.

**Pengaturan (user)**
- Bagian profil: foto, nama, email.
- Baris "Tampilan" dengan pilihan Ikuti sistem, Terang, Gelap.
- Baris "Jurnal Saya" dan "Laporan Membaca" sebagai pintasan.
- Baris "Tentang Aplikasi" (versi).
- Tombol "Keluar" dengan dialog konfirmasi.

**Notifikasi**
- Daftar notifikasi terbaru lebih dulu, tiap baris: ikon jenis, teks singkat, waktu relatif, titik penanda belum dibaca.
- Menekan baris membuka tujuan (postingan, kegiatan, tantangan) dan menandainya terbaca.
- Tombol "Tandai semua dibaca". Keadaan kosong: "Belum ada notifikasi".

**Dashboard Admin**
- Kartu angka: total buku, laporan terbuka, log ISBN belum ditangani, total pengguna.
- Menu: Kelola Buku, Log ISBN, Laporan Komunitas, Kegiatan, Tantangan, Keluar.

**Log ISBN (admin)**
- Daftar: ISBN, jumlah pemindaian, waktu terakhir, status.
- Tombol "Tambah buku" (membuka formulir dengan ISBN terisi) dan "Tandai ditangani".

**Layar admin lain (Kelola Kegiatan, Kelola Tantangan, Moderasi Laporan)**
- Daftar dengan tombol tambah, ketuk untuk ubah, geser atau tombol hapus dengan konfirmasi. Moderasi laporan menampilkan isi konten yang dilaporkan, alasan, dan dua tombol: Hapus Konten dan Abaikan.

## 8. Model data Firestore

Semua `createdAt` dan `updatedAt` memakai server timestamp.

```
users/{uid}
  displayName, email, photoUrl, role ("user" | "admin"), createdAt

users/{uid}/library/{bookId}
  status ("want" | "reading" | "finished"), currentPage, addedAt, finishedAt?,
  bookTitle, bookAuthor, bookCoverUrl?, bookTotalPages

users/{uid}/sessions/{sessionId}
  bookId, bookTitle, startedAt, endedAt, durationSeconds, targetSeconds,
  startPage, endPage, targetReached (bool)

users/{uid}/journals/{journalId}
  bookId, bookTitle, sessionId?, content, createdAt, updatedAt

users/{uid}/notifications/{notifId}
  type ("reply" | "like" | "event" | "challenge" | "report"), actorId?, actorName?,
  refType, refId, text, read (bool), createdAt

books/{bookId}
  title, author, isbn, publisher, year, totalPages, category, synopsis,
  coverUrl?, ratingAverage, ratingCount, createdBy, createdAt, updatedAt
  (juga titleLower, authorLower untuk pencarian awalan)

books/{bookId}/reviews/{uid}              (id dokumen = uid penulis)
  rating (1-5), text, userName, userPhotoUrl?, createdAt, updatedAt

posts/{postId}
  authorId, authorName, authorPhotoUrl?, content, bookId?, bookTitle?,
  likeCount, replyCount, createdAt

posts/{postId}/replies/{replyId}
  authorId, authorName, authorPhotoUrl?, content, createdAt

posts/{postId}/likes/{uid}
  createdAt

reports/{reportId}
  targetType ("post" | "reply"), postId, replyId?, targetAuthorId, targetPreview,
  reason, reporterId, status ("open" | "resolved" | "dismissed"), createdAt

events/{eventId}
  title, description, startAt, location, participantCount, createdBy, createdAt

events/{eventId}/participants/{uid}
  userName, joinedAt

challenges/{challengeId}
  title, description, type ("books" | "minutes"), targetValue, startDate, endDate,
  participantCount, createdBy, createdAt

challenges/{challengeId}/participants/{uid}
  userName, userPhotoUrl?, progress, joinedAt

isbn_logs/{isbn}                          (id dokumen = ISBN)
  isbn, scanCount, lastScannedAt, lastScannedBy, handled (bool)
```

Indeks komposit yang diperlukan dicatat di `firestore.indexes.json` (contoh: `reports` dengan `status` dan `createdAt`, `challenges` dengan `endDate`, `events` dengan `startAt`).

## 9. Aturan keamanan Firestore dan Storage (ringkas)

| Koleksi | Baca | Tulis |
|---|---|---|
| `users/{uid}` | Pemilik, admin | Pemilik boleh buat (role harus `user`) dan ubah selain field `role`. Role hanya diubah lewat Console |
| `users/{uid}/**` (library, sessions, journals) | Pemilik | Pemilik |
| `users/{uid}/notifications` | Pemilik | Pemilik baca, ubah, hapus. Pengguna lain boleh membuat dengan `actorId` sama dengan UID dirinya |
| `books` | Pengguna login | Admin |
| `books/*/reviews/{uid}` | Pengguna login | Hanya pemilik (id sama dengan UID). Admin boleh hapus |
| `posts`, `replies` | Pengguna login | Buat oleh penulis. Hapus oleh penulis atau admin. Pengguna lain hanya boleh mengubah `likeCount` dan `replyCount` |
| `posts/*/likes/{uid}` | Pengguna login | Hanya pemilik (id sama dengan UID) |
| `reports` | Admin | Pengguna login boleh membuat. Admin boleh ubah status |
| `events`, `challenges` | Pengguna login | Admin. Dokumen `participants/{uid}` oleh pemilik |
| `isbn_logs` | Admin | Pengguna login boleh membuat dan menaikkan `scanCount`. Admin boleh ubah `handled` |

Storage: `covers/{bookId}` boleh dibaca pengguna login dan ditulis admin (batas ukuran 2 MB, hanya gambar). Foto profil memakai URL akun Google, tidak diunggah.

Penentuan admin di aturan membaca `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'`.

## 10. Non-fungsional

- Android 8.0 (API 26) ke atas. Target SDK terbaru yang didukung Flutter stabil.
- Cold start di bawah 3 detik pada perangkat menengah.
- Seluruh teks Indonesia. Format tanggal `id_ID`.
- Izin yang dibutuhkan: kamera (scan ISBN), notifikasi (Android 13 ke atas), alarm tepat (Android 12 ke atas), foreground service, getar.
- Aksesibilitas dasar: target sentuh minimal 48 dp, kontras sesuai token tema, label semantik pada ikon.

## 11. Asumsi yang perlu dikonfirmasi

Asumsi berikut dibuat karena belum ditetapkan. Jika ada yang berbeda dari kenyataan, ubah sebelum eksekusi.

1. "Target" pada sesi membaca adalah target durasi (menit), bukan target halaman.
2. Kegiatan dan tantangan dibuat oleh admin, pengguna hanya mengikuti.
3. "Log error" ISBN berarti pesan error ke pengguna ditambah catatan di koleksi `isbn_logs` yang dilihat admin.
4. Role admin diatur manual lewat Firebase Console (tidak memakai custom claims agar tidak perlu Cloud Functions).
5. Notifikasi dalam aplikasi dibuat dari sisi klien. Push notification (FCM) saat aplikasi tertutup belum termasuk (butuh Cloud Functions), tersedia sebagai task opsional T-100.
6. Tombol Jeda dan Lanjut pada timer hanya dibuat jika ada di desain Stitch.
7. Satu akun hanya memiliki satu role. Admin tidak memakai area user.

## 12. Di luar lingkup

- Peminjaman buku.
- Login selain Google.
- Bahasa selain Indonesia.
- iOS dan web.
- Role guru atau orang tua, serta pengiriman laporan.
- Editor teks kaya pada jurnal.
- Impor data buku otomatis dari layanan eksternal.
- Push notification saat aplikasi tertutup (opsional, lihat T-100).
