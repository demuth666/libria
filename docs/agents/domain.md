# Domain Docs

Cara skill engineering mengonsumsi dokumentasi domain repo ini saat menelusuri codebase.

## Sebelum menelusuri, baca ini

- **`GLOSSARY.md`** di root repo, atau
- **`GLOSSARY-MAP.md`** di root repo jika ada: berkas itu menunjuk satu `GLOSSARY.md` per konteks. Baca setiap yang relevan dengan topik.
- **`docs/adr/`**: baca ADR yang menyentuh area yang akan dikerjakan. Di repo multi-konteks, cek juga `src/<context>/docs/adr/` untuk keputusan spesifik konteks.

Jika berkas-berkas ini tidak ada, **lanjut tanpa suara**. Jangan tandai ketiadaannya; jangan sarankan membuatnya lebih dulu. Skill `/domain-modeling` (dijangkau lewat `/grill-with-docs` dan `/improve-codebase-architecture`) membuatnya secara lazy saat istilah atau keputusan benar-benar diselesaikan.

## Struktur berkas

Repo ini single-context:

```
/
├── GLOSSARY.md
├── docs/adr/
│   ├── 0001-contoh-keputusan.md
│   └── 0002-contoh-keputusan-lain.md
└── lib/
```

## Gunakan kosakata glossary

Saat output menyebut konsep domain (di judul issue, proposal refactor, hipotesis, nama test), gunakan istilah seperti yang didefinisikan di `GLOSSARY.md`. Jangan beralih ke sinonim yang secara eksplisit dihindari glossary.

Jika konsep yang dibutuhkan belum ada di glossary, itu sinyal: entah Anda sedang menciptakan bahasa yang tidak dipakai proyek (pertimbangkan ulang) atau ada celah nyata (catat untuk `/domain-modeling`).

## Tandai konflik ADR

Jika output bertentangan dengan ADR yang ada, tandai secara eksplisit alih-alih menimpanya diam-diam:

> _Bertentangan dengan ADR-0007 (event-sourced orders), tetapi layak dibuka kembali karena…_
