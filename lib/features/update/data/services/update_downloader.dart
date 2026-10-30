import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../datasources/github_release_datasource.dart';

/// Mengunduh APK rilis ke folder file eksternal aplikasi
/// (tidak butuh izin penyimpanan) dengan laporan progres 0..1.
///
/// Aset repo privat diunduh lewat URL API + token baca-saja yang sama
/// dengan pemeriksaan rilis. Gagal unduh → exception dengan pesan jelas;
/// versi lama tetap berjalan (tidak ada yang ditimpa sebelum instal).
class UpdateDownloader {
  UpdateDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  Future<File> download({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    _cancelled = false;
    Directory? dir = await getExternalStorageDirectory();
    dir ??= await getApplicationDocumentsDirectory();
    final Directory updatesDir = Directory('${dir.path}/updates');
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }
    final File file = File('${updatesDir.path}/dracin-reels.apk');
    final http.Request request = http.Request('GET', Uri.parse(url));
    request.headers['Accept'] = 'application/octet-stream';
    request.headers['Authorization'] =
        'Bearer ${GithubReleaseDataSource.token}';
    final http.StreamedResponse response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Unduhan gagal (kode ${response.statusCode}).',
      );
    }
    final int? total = response.contentLength;
    var received = 0;
    final IOSink sink = file.openWrite();
    try {
      await for (final List<int> chunk in response.stream) {
        if (_cancelled) {
          await sink.close();
          if (await file.exists()) {
            await file.delete();
          }
          throw const DownloadCancelled();
        }
        received += chunk.length;
        sink.add(chunk);
        if (total != null && total > 0) {
          onProgress(received / total);
        }
      }
    } finally {
      await sink.close();
    }
    return file;
  }
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}
