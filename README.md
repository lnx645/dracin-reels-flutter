# Dracin Reels (Flutter)

Aplikasi reels video pendek ala TikTok, ditulis ulang dengan Flutter
(menggantikan versi Rust/egui yang diparkir — repo Rust tidak dihapus).

## Status jujur: UI SAJA

- **Video BELUM memutar.** Area video adalah placeholder gradasi + judul +
  ikon putar/jeda (state UI saja).
- **Tanpa backend, tanpa streaming, tanpa hosting video.**
- Semua episode, angka suka/komentar, dan profil adalah **data sampel UI**
  dari naskah orisinal "CINTA SANG PENGUASA QIN" (Qin Chen dan Lin Yue).
  Tanpa still/poster drama bajakan, tanpa nama kreator asli.
- **Notifikasi DITUNDA** (perintah pemilik): tanpa FCM, tanpa izin notifikasi.

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
│   ├── theme/app_theme.dart  # tema gelap, Plus Jakarta Sans
│   └── utils/format_count.dart
└── features/
    ├── feed/                 # domain/data/presentation + FeedBloc
    ├── explore/              # ExploreBloc (cari + grid 2 kolom)
    ├── bookmark/             # BookmarkBloc (daftar tersimpan)
    ├── profile/              # ProfileBloc (statistik + lanjutkan nonton)
    ├── create/               # placeholder "menyusul"
    └── notifications/        # placeholder "menyusul" (ditunda)
```

Bottom nav (satu daftar di `app.dart`, mudah diubah): Beranda, Jelajahi,
+, Notifikasi, Profil. Susunan final masih bisa diubah pemilik.

## Tipografi

Plus Jakarta Sans dibundel (`assets/fonts/`, lisensi OFL, via Google Fonts):
judul Bold 20-22, isi Regular 14-15, label kecil Semibold 12,
kontras putih/abu terang, line height 1,3-1,4, ellipsis di batas kata.
`SafeArea` dipakai di bilah atas dan navigasi bawah — tidak ada konten
di bawah status bar/navigation bar Android.

## Build

Build HANYA lewat GitHub Actions (JANGAN build Gradle/Android di VPS):

- `flutter pub get`, `flutter analyze`, `flutter build apk --release`
- APK universal (fat): armeabi-v7a + arm64-v8a + x86_64
  (tanpa `--split-per-abi`, agar HP 32-bit bisa instal)
- Hasil: artifact + GitHub Release `v0.1.0` berisi `dracin-reels.apk`
  (ditandatangani kunci debug, bukan kunci Play Store).
