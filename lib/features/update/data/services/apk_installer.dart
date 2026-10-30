import 'package:flutter/services.dart';

/// Hasil percobaan membuka installer sistem.
enum InstallResult {
  /// Installer sistem terbuka; pengguna tinggal ketuk "Instal".
  opened,

  /// Aplikasi belum diizinkan memasang dari sumber ini (Android 8+).
  permissionRequired,

  /// Gagal membuka installer (pesan di [message]).
  failed,
}

/// Jembatan ke installer sistem Android.
///
/// Instal sunyi penuh TIDAK MUNGKIN untuk APK sideload: Android selalu
/// meminta satu ketukan "Instal" di installer sistem. Itu bagian desain,
/// bukan kekurangan.
///
/// URUTAN YANG BENAR (perbaikan keluhan "unduh lalu kembali malah
/// unduh lagi"): izin diperiksa SEBELUM unduhan dimulai
/// ([canRequestPackageInstalls]); unduhan hanya jalan sesudah izin
/// dipastikan. Unduhan yang sudah selesai DIINGAT (prefs + berkas
/// berversi + ukuran) sehingga kembali dari Pengaturan / batal instal
/// tidak pernah mengulang unduhan.
class ApkInstaller {
  static const MethodChannel _channel =
      MethodChannel('dev.uwa.dracinreels/updater');

  Future<({InstallResult result, String message})> installApk(
    String filePath,
  ) async {
    try {
      final String? outcome =
          await _channel.invokeMethod<String>('installApk', filePath);
      if (outcome == 'permission_required') {
        return (
          result: InstallResult.permissionRequired,
          message: 'Izin memasang aplikasi dari sumber ini belum aktif.',
        );
      }
      return (result: InstallResult.opened, message: '');
    } on PlatformException catch (e) {
      return (
        result: InstallResult.failed,
        message: e.message ?? 'Tidak dapat membuka installer.',
      );
    }
  }

  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // Abaikan: pengguna masih bisa mengaktifkan izin lewat Pengaturan.
    }
  }

  /// Halaman detail aplikasi di Pengaturan (untuk dialog
  /// ketidakcocokan tanda tangan: pengguna uninstall dari sini).
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on PlatformException {
      // Abaikan: dialog tetap memberi langkah manual.
    }
  }

  /// Apakah aplikasi sudah diizinkan memasang dari sumber ini.
  /// Gagal baca (channel error) = fail-open ke true: pemeriksaan di
  /// sisi instal tetap menjadi jaring pengaman (installApk akan
  /// mengembalikan permission_required, dan unduhan yang sudah selesai
  /// tetap diingat sehingga tidak terulang).
  Future<bool> canRequestPackageInstalls() async {
    try {
      final bool? allowed = await _channel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return allowed ?? true;
    } on PlatformException {
      return true;
    }
  }

  /// Sidik jari SHA-256 (hex kecil, tanpa ':') sertifikat penanda
  /// aplikasi TERINSTAL. Null bila tidak bisa dibaca (fail-open:
  /// pra-cek dilewati, installer normal yang memutuskan).
  Future<String?> getInstalledSignatureSha256() async {
    try {
      return await _channel.invokeMethod<String>(
        'getInstalledSignatureSha256',
      );
    } on PlatformException {
      return null;
    }
  }

  /// Sidik jari SHA-256 sertifikat penanda sebuah berkas APK.
  /// Null bila tidak bisa dibaca.
  Future<String?> getApkSignatureSha256(String filePath) async {
    try {
      return await _channel.invokeMethod<String>(
        'getApkSignatureSha256',
        filePath,
      );
    } on PlatformException {
      return null;
    }
  }

  /// Salin APK ke folder Downloads publik (bertahan meski aplikasi
  /// di-uninstall — tidak seperti folder file aplikasi). Mengembalikan
  /// jalur/nama yang bisa ditampilkan, atau null bila gagal.
  Future<String?> saveToDownloads(String filePath) async {
    try {
      return await _channel.invokeMethod<String>(
        'saveToDownloads',
        filePath,
      );
    } on PlatformException {
      return null;
    }
  }

  /// Minta izin notifikasi runtime (Android 13+). Penolakan TIDAK
  /// PERNAH memblokir unduhan — progres tetap tampil di banner dalam
  /// aplikasi. Di bawah Android 13 selalu true.
  Future<bool> ensureNotificationPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'ensureNotificationPermission',
      );
      return granted ?? true;
    } on PlatformException {
      return true;
    }
  }

  /// Tampilkan/perbarui notifikasi progres unduhan (0..100; negatif =
  /// tak tentu). Best-effort: gagal tampil tidak mengganggu unduhan.
  Future<void> showDownloadNotification(int progress) async {
    try {
      await _channel.invokeMethod<void>(
        'showDownloadNotification',
        progress,
      );
    } on PlatformException {
      // Abaikan: banner dalam aplikasi tetap menampilkan progres.
    }
  }

  Future<void> hideDownloadNotification() async {
    try {
      await _channel.invokeMethod<void>('hideDownloadNotification');
    } on PlatformException {
      // Abaikan.
    }
  }

  /// Folder updates/ di folder file eksternal aplikasi (dipakai
  /// FileProvider saat instal). Dibuat di sisi Android agar Dart tidak
  /// butuh dependensi path_provider.
  Future<String> getUpdatesDir() async {
    final String? path =
        await _channel.invokeMethod<String>('getUpdatesDir');
    if (path == null || path.isEmpty) {
      throw const _UpdatesDirUnavailable();
    }
    return path;
  }
}

class _UpdatesDirUnavailable implements Exception {
  const _UpdatesDirUnavailable();

  @override
  String toString() => 'Folder unduhan tidak tersedia.';
}
