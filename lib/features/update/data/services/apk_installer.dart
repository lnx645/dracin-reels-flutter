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
