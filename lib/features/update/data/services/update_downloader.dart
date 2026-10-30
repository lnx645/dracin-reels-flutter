import 'dart:io';

import 'package:http/http.dart' as http;

import '../datasources/github_release_datasource.dart';
import 'apk_installer.dart';

/// Mengunduh APK rilis ke folder updates/ di folder file eksternal
/// aplikasi (lokasi dari sisi Android lewat MethodChannel — tanpa
/// dependensi path_provider, agar tidak menambah konflik versi plugin).
///
/// Aturan unduhan canggih (perbaikan keluhan "kembali malah unduh
/// lagi"):
/// - Berkas BERVERSI (`dracin-reels-<versionCode>.apk` + `.part`
///   untuk setengah jadi): unduhan selesai DIINGAT — bila berkas final
///   sudah ada dan ukurannya cocok dengan aset rilis, unduhan DILEWATI
///   (langsung instal). Batal instal / kembali dari Pengaturan tidak
///   pernah mengulang unduhan.
/// - Terputus / batal → berkas `.part` DIPERTAHANKAN dan dilanjutkan
///   (HTTP Range `bytes=<sudah>-`); server yang mengabaikan Range
///   (200, bukan 206) → mulai ulang dari nol secara jujur; 416 →
///   `.part` dibuang lalu mulai ulang.
/// - Ukuran akhir DIVERIFIKASI dengan ukuran aset rilis sebelum
///   instal: tidak cocok → satu unduh ulang internal, masih tidak
///   cocok → [DownloadSizeMismatch] (jangan instal berkas rusak).
/// - Berkas versi lama dibersihkan sesudah unduhan berhasil.
///
/// Aset repo privat diunduh lewat URL API + token baca-saja yang sama
/// dengan pemeriksaan rilis. Versi lama tetap berjalan (tidak ada yang
/// ditimpa sebelum instal).
class UpdateDownloader {
  UpdateDownloader(this._installer, {http.Client? client})
      : _client = client ?? http.Client();

  final ApkInstaller _installer;
  final http.Client _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  String _baseName(int? versionCode) => versionCode != null
      ? 'dracin-reels-$versionCode'
      : 'dracin-reels';

  Future<Directory> _updatesDir() async {
    final String dirPath = await _installer.getUpdatesDir();
    final Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Berkas final yang sudah lengkap (bila ada) — dipakai cubit untuk
  /// melewati unduhan tanpa jaringan sama sekali.
  Future<File?> completedFile({
    required int? versionCode,
    required int? expectedSizeBytes,
  }) async {
    final Directory dir = await _updatesDir();
    final File file = File('${dir.path}/${_baseName(versionCode)}.apk');
    if (!await file.exists()) {
      return null;
    }
    if (expectedSizeBytes != null &&
        await file.length() != expectedSizeBytes) {
      // Berkas rusak / tidak lengkap: buang agar diunduh ulang bersih.
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
    return file;
  }

  Future<File> download({
    required String url,
    required void Function(double progress) onProgress,
    int? versionCode,
    int? expectedSizeBytes,
  }) async {
    _cancelled = false;
    final Directory dir = await _updatesDir();
    final String base = _baseName(versionCode);
    final File finalFile = File('${dir.path}/$base.apk');
    final File partFile = File('${dir.path}/$base.apk.part');

    // Sudah lengkap dari unduhan sebelumnya → lewati jaringan.
    final File? completed = await completedFile(
      versionCode: versionCode,
      expectedSizeBytes: expectedSizeBytes,
    );
    if (completed != null) {
      onProgress(1);
      return completed;
    }

    File result = await _downloadOnce(
      url: url,
      dir: dir,
      finalFile: finalFile,
      partFile: partFile,
      expectedSizeBytes: expectedSizeBytes,
      onProgress: onProgress,
    );
    // Verifikasi ukuran: tidak cocok → satu unduh ulang internal
    // (bersih, tanpa Range), masih tidak cocok → jangan instal rusak.
    if (expectedSizeBytes != null &&
        await result.length() != expectedSizeBytes) {
      try {
        await result.delete();
      } catch (_) {}
      _cancelled = false;
      result = await _downloadOnce(
        url: url,
        dir: dir,
        finalFile: finalFile,
        partFile: partFile,
        expectedSizeBytes: expectedSizeBytes,
        onProgress: onProgress,
      );
      if (await result.length() != expectedSizeBytes) {
        try {
          await result.delete();
        } catch (_) {}
        throw const DownloadSizeMismatch();
      }
    }
    await _cleanupOtherVersions(dir, '$base.apk');
    return result;
  }

  /// Satu percobaan unduh (dengan resume bila `.part` ada). Mengembalikan
  /// berkas final (`.part` diganti nama sesudah stream selesai).
  Future<File> _downloadOnce({
    required String url,
    required Directory dir,
    required File finalFile,
    required File partFile,
    required int? expectedSizeBytes,
    required void Function(double progress) onProgress,
  }) async {
    var existing = 0;
    if (await partFile.exists()) {
      existing = await partFile.length();
    }
    var resumeFrom = existing;
    final http.Request request = http.Request('GET', Uri.parse(url));
    request.headers['Accept'] = 'application/octet-stream';
    request.headers['Authorization'] =
        'Bearer ${GithubReleaseDataSource.token}';
    if (resumeFrom > 0) {
      request.headers['Range'] = 'bytes=$resumeFrom-';
    }
    final http.StreamedResponse response = await _client.send(request);
    if (response.statusCode == 416) {
      // Offset sudah di luar berkas: buang `.part`, mulai ulang bersih.
      try {
        await partFile.delete();
      } catch (_) {}
      resumeFrom = 0;
      return _downloadOnce(
        url: url,
        dir: dir,
        finalFile: finalFile,
        partFile: partFile,
        expectedSizeBytes: expectedSizeBytes,
        onProgress: onProgress,
      );
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException(
        'Unduhan gagal (kode ${response.statusCode}).',
      );
    }
    if (response.statusCode == 200 && resumeFrom > 0) {
      // Server mengabaikan Range: mulai ulang dari nol secara jujur
      // (mode tulis memotong `.part` lama, bukan menempel di belakangnya).
      resumeFrom = 0;
    }
    // Total untuk progres: sisa + yang sudah ada (206) atau penuh (200).
    final int? remaining = response.contentLength;
    final int? total = expectedSizeBytes ??
        (remaining == null ? null : remaining + resumeFrom);
    var received = resumeFrom;
    final IOSink sink = partFile.openWrite(
      mode: resumeFrom > 0 ? FileMode.append : FileMode.write,
    );
    var cancelled = false;
    try {
      await for (final List<int> chunk in response.stream) {
        if (_cancelled) {
          cancelled = true;
          break;
        }
        received += chunk.length;
        sink.add(chunk);
        if (total != null && total > 0) {
          onProgress(received / total);
        } else {
          onProgress(-1);
        }
      }
    } finally {
      await sink.close();
    }
    if (cancelled) {
      // Setengah jadi DIPERTAHANKAN untuk dilanjutkan (bukan dihapus).
      throw const DownloadCancelled();
    }
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    return partFile.rename(finalFile.path);
  }

  /// Hapus berkas versi lain (final + `.part`) agar folder tidak
  /// menumpuk. Berkas aktif tidak disentuh.
  Future<void> _cleanupOtherVersions(Directory dir, String keep) async {
    try {
      await for (final FileSystemEntity entity in dir.list()) {
        final String name = entity.path.split('/').last;
        if (!name.startsWith('dracin-reels-')) {
          continue;
        }
        if (name == keep) {
          continue;
        }
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Berkas hasil unduh ukurannya tidak cocok dengan aset rilis, bahkan
/// sesudah satu unduh ulang internal — jangan instal berkas rusak.
class DownloadSizeMismatch implements Exception {
  const DownloadSizeMismatch();

  @override
  String toString() => 'Ukuran berkas unduhan tidak cocok dengan rilis.';
}
