# Dracin Reels (Flutter)

Aplikasi reels video pendek ala TikTok, ditulis ulang dengan Flutter
(menggantikan versi Rust/egui yang diparkir — repo Rust tidak dihapus).

## Status jujur v0.2.4

- **Video MEMUTAR di halaman Player** (file video langsung atau HLS
  dari `video_url` episode — path upload `media/...` di-resolve lewat
  basis media proxy, link eksternal http(s) dipakai apa adanya).
  Episode terkunci tetap tidak memutar. Tautan halaman web (bukan file
  video) tidak dapat diputar — gagal ditampilkan sebagai error asli +
  Coba Lagi, bukan pura-pura memutar.
- **Fallback thumbnail (dikunci):** thumbnail episode bila ada;
  bila null/kosong → cover series (juga di poster area Player sebelum
  video mulai); bila keduanya tidak ada → placeholder gradasi rapi
  bertitel. Semua URL relatif di-resolve lewat basis media proxy.
- **Genre + tagline:** form admin series punya field Tagline +
  pemilih genre multi-pilih (dari GET /genres, kirim `genre_ids`
  saat simpan); detail series menampilkan tagline di bawah judul
  (disembunyikan bila kosong) + chip genre (tidak ada chip palsu
  bila array kosong); Jelajahi punya filter chip genre (Semua +
  tiap genre) yang bekerja bersama kolom kata kunci, via
  `?genre_id=<id>` ke API dengan fallback filter lokal yang aman
  (hanya bila respons membawa data genre). Field `tagline` sudah
  dikembalikan backend; array `genres` per series masih menunggu
  backend (form + filter tetap jalan tanpa crash).
- **Fitur Melolo (fase 2) SUDAH jalan — lokal dulu, API bila masuk:**
  detail series + daftar episode (Gratis/Terkunci + harga koin),
  dompet koin (saldo di header, check-in harian 1x/hari),
  buka episode terkunci pakai koin, lanjutkan nonton, riwayat tonton,
  watchlist/suka/komentar, filter genre + cari + rekomendasi,
  seksi Beranda (Trending, Rekomendasi, per genre) + halaman
  "Tonton Semua", layar VIP (katalog sampel).
- **Mode Admin SUDAH jalan (login JWT beneran):** masuk dengan akun
  admin → Panel Admin (daftar/tambah/edit/hapus series & episode,
  upload cover/video/subtitle/thumbnail ATAU tempel link video
  eksternal http(s)). Viewer mendapat 403 dari API. Bila API tidak
  terjangkau, pesan jelas ditampilkan — TIDAK PERNAH sukses palsu.
- **Yang BELUM ada (jujur):** pembayaran koin beneran (Play Billing),
  langganan VIP auto-renew beneran, iklan reward beneran (AdMob),
  streaming/CDN video beneran, unduhan offline, sinkronisasi akun
  antar perangkat. Media upload tahap ini = direktori media VPS
  (staging/preview admin); tayang publik massal HARUS pindah ke
  object storage + CDN.
- **Notifikasi DITUNDA** (perintah pemilik): tanpa FCM, tanpa izin
  notifikasi, tanpa daftar beneran.
- Data sampel dari naskah orisinal "CINTA SANG PENGUASA QIN"
  (Qin Chen dan Lin Yue). Tanpa still/poster drama bajakan, tanpa
  nama kreator asli. UI mirip bahasa layout Melolo/TikTok saja —
  bukan jiplakan piksel, logo, nama, atau konten Melolo.

## Backend (API saja, repo terpisah)

`http://103.147.33.11:8095/dracin-api` — Go + PostgreSQL, JWT
(admin/viewer). Aplikasi ini klien API tersebut: bila sudah masuk,
saldo/check-in/unlock/VIP/progress/riwayat memakai endpoint beneran
(`POST /auth/login`, `GET /wallet`, `POST /checkin`, `POST /unlock`,
`POST /vip/claim`, `PUT /watch-progress`, `GET /admin/series`,
upload multipart `/admin/...`). Bila belum masuk atau API tidak
terjangkau, aplikasi memakai dompet & riwayat lokal (saldo awal 100
koin, check-in lokal +10/hari) dengan label jelas — dan feed sampel
tetap jalan.

## Arsitektur: Clean Architecture Flutter berbasis fitur

Satu fitur = `domain/` (entities, repository interface, use case) +
`data/` (models, datasource, repository impl) + `presentation/` (bloc,
pages, widgets). Lapisan domain tanpa dependensi Flutter UI.
State management: `flutter_bloc`.

```
lib/
├── main.dart
├── app.dart                  # DracinApp + MainShell (bottom nav 5 item)
├── core/
│   ├── api/api_client.dart   # amplop JSON backend + token + upload
│   ├── session/session_cubit.dart  # login JWT + peran admin/viewer
│   ├── theme/app_theme.dart  # tema gelap, Plus Jakarta Sans
│   └── utils/format_count.dart
└── features/
    ├── feed/                 # FeedBloc + cover/rel/caption
    ├── home/                 # seksi Beranda + "Tonton Semua" + kartu
    ├── series/               # detail series + daftar episode
    ├── explore/              # cari + grid 2 kolom + strip series
    ├── bookmark/             # BookmarkBloc (daftar tersimpan)
    ├── profile/              # profil + lanjutkan + tombol fitur
    ├── history/              # Riwayat Tonton (sudah/belum ditonton)
    ├── wallet/               # dompet, check-in, unlock, VIP, komentar
    ├── admin/                # login + panel + formulir + upload
    ├── create/               # placeholder "menyusul" (+ admin)
    └── notifications/        # placeholder "menyusul" (ditunda)
```

Bottom nav (satu daftar di `app.dart`, mudah diubah): Beranda, Jelajahi,
+, Notifikasi, Profil. Susunan final masih bisa diubah pemilik.

## Tipografi & polish visual

Plus Jakarta Sans dibundel (`assets/fonts/`, lisensi OFL, via Google Fonts):
judul Bold 20-22, isi Regular 14-15, label kecil Semibold 12,
kontras putih/abu terang, line height 1,3-1,4, ellipsis di batas kata.
Sistem jarak 8/12/16; kartu & cover sudut 16 dengan gradasi halus +
badge posisi tetap; daftar episode bernomor dengan badge kanan sejajar;
indikator tab/nav aktif jelas; state tombol normal/pressed/disabled
berbeda; empty state memakai ikon + teks + tombol aksi.
`SafeArea` dipakai di bilah atas dan navigasi bawah — tidak ada konten
di bawah status bar/navigation bar Android.

## Build

Build HANYA lewat GitHub Actions (JANGAN build Gradle/Android di VPS):

- `flutter pub get`, `flutter analyze`, `flutter build apk --release`
- APK universal (fat): armeabi-v7a + arm64-v8a + x86_64
  (tanpa `--split-per-abi`, agar HP 32-bit bisa instal)
- Hasil: artifact + GitHub Release berisi `dracin-reels.apk`
  (tag dari versi `pubspec.yaml`, ditandatangani kunci debug,
  bukan kunci Play Store).

## Updater semi-otomatis (dari GitHub Release)

Alur: saat aplikasi dibuka, `UpdateGate` memeriksa GitHub Releases API
di latar belakang (sekali sehari, tidak menghambat buka aplikasi).
Bila ada rilis lebih baru → dialog "Update tersedia vX.Y.Z" +
changelog + tombol "Update Sekarang" / "Nanti" (tidak ada update
paksa). "Update Sekarang" mengunduh APK dengan progress bar, lalu
membuka installer sistem lewat `FileProvider` + `MethodChannel`
(`MainActivity`).

Batasan jujur: instal sunyi penuh TIDAK MUNGKIN untuk APK sideload —
Android selalu menampilkan installer sistem dan meminta satu ketukan
"Instal". Gagal unduh → pesan jelas, versi lama tetap berjalan.

Token: repo ini privat, jadi pemeriksaan + unduhan memakai token
baca-saja yang diteruskan saat build sebagai
`--dart-define=GITHUB_TOKEN=...` dari repo secret
`UPDATER_GITHUB_TOKEN` (bukan token utama, tidak pernah di-commit).
Bila define kosong, updater menonaktifkan diri dengan diam.
Perbandingan versi: versionCode numerik dari baris `versionCode: N`
di catatan rilis (ditulis workflow sejak v0.2.1); bila tidak ada,
dipakai semver tag. Tag rilis dibaca workflow dari `pubspec.yaml`,
bukan hardcode.

Cara uji: instal APK versi lama (mis. v0.2.0), buka aplikasi —
dialog update harus muncul karena Release terbaru lebih baru.
Ketuk "Update Sekarang", tunggu unduhan, ketuk "Instal" di
installer sistem. Pengujian end-to-end di HP hanya bisa dilakukan
di perangkat (bukan dari sandbox).

## Tanpa mock sama sekali (dikunci)

Sejak v0.2.2, aplikasi TIDAK mengandung data mock/sampel/placeholder:
feed, Jelajahi, detail series, dompet, riwayat, profil, dan bookmark
hanya menampilkan data API backend yang sebenarnya. File sampel yang
dihapus: `sample_episode_datasource.dart`, `episode_model.dart`
(model sampel), `profile_bloc.dart` (statistik dari toggle lokal),
dan semua fallback sampel di repository series/dompet. Saldo contoh
100, katalog paket/tugas contoh, dan riwayat lokal sudah dihapus.

Aturan tampilannya:
- API gagal (jaringan/timeout/non-200) → pesan error ASLI dari
  request itu + tombol "Coba Lagi" (feed, Jelajahi, detail series,
  Beranda, bookmark, riwayat, dompet, komentar).
- API mengembalikan kosong → empty state jujur ("Belum ada data").
- Belum masuk → endpoint publik API untuk konten yang bisa dibaca
  anonim (daftar series/episode/paket/tugas); data akun (saldo, VIP,
  riwayat, bookmark) menampilkan ajakan masuk, bukan angka contoh.
- Pengiriman progress tonton tetap best-effort di latar belakang
  (bukan data yang ditampilkan).

## Izin INTERNET (akar masalah login)

`AndroidManifest.xml` WAJIB memuat
`<uses-permission android:name="android.permission.INTERNET" />`
(izin normal, otomatis dikabulkan). Tanpa izin ini Android memblokir
SEMUA akses jaringan aplikasi — inilah kenapa login lama selalu
"Tidak dapat terhubung" meski server hidup dan cleartext sudah benar.
Workflow memverifikasi dari APK hasil build (langkah "Verify APK
permissions" memakai `aapt2 dump badging` dan GAGAL bila INTERNET
tidak ada) — bukan hanya dari sumber.

## Tipografi & visual (Plus Jakarta Sans)

Skala di `lib/core/theme/app_theme.dart`: judul layar displayLarge
Bold 26, judul AppBar/kartu titleLarge Bold 22 / titleMedium Bold 20 /
titleSmall Semibold 17, isi bodyLarge 15 / bodyMedium 14 Regular
dengan line-height 1.4, label kecil labelMedium Semibold 12 dengan
tracking 0.2. Spacing konsisten 8/12/16, kartu radius 16 + bayangan
halus (hitam 25%, blur 12), teks memakai gaya tema (bukan fontSize
lepas) dengan maxLines + ellipsis sehingga tidak ada teks terpotong
atau menumpuk. Prioritas polish: layar Dompet & Hadiah/check-in
(kartu saldo besar + label jelas + bayangan + banner error dengan
Coba Lagi), lalu Beranda/Feed, Player, detail series, dompet, profil.
