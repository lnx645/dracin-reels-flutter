import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/update_info.dart';

/// Membaca GitHub Release terbaru repo privat dracin-reels-flutter.
///
/// Token baca-saja diteruskan saat build lewat
/// `--dart-define=GITHUB_TOKEN=...` (berasal dari repo secret
/// UPDATER_GITHUB_TOKEN). Token TIDAK PERNAH di-commit ke repo:
/// nilai ini hanya ada di biner hasil build. Bila define kosong,
/// updater menonaktifkan diri (kembalikan null, tanpa panggilan jaringan).
class GithubReleaseDataSource {
  GithubReleaseDataSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _releasesLatestUrl =
      'https://api.github.com/repos/lnx645/dracin-reels-flutter/releases/latest';

  /// Token build-time; kosong berarti updater dinonaktifkan.
  static const String token = String.fromEnvironment(
    'GITHUB_TOKEN',
    defaultValue: '',
  );

  final http.Client _client;

  Future<UpdateInfo?> fetchLatest() async {
    if (token.isEmpty) {
      return null;
    }
    final response = await _client.get(
      Uri.parse(_releasesLatestUrl),
      headers: <String, String>{
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      return null;
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String tag = (json['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty) {
      return null;
    }
    final String versionName = tag.startsWith('v') ? tag.substring(1) : tag;
    final String body = (json['body'] as String? ?? '').trim();
    final List<dynamic> assets = json['assets'] as List<dynamic>? ?? <dynamic>[];
    Map<String, dynamic>? apkAsset;
    for (final dynamic asset in assets) {
      final Map<String, dynamic> item = asset as Map<String, dynamic>;
      final String name = (item['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkAsset = item;
        break;
      }
    }
    if (apkAsset == null) {
      return null;
    }
    // Unduhan aset repo privat lewat URL API + header octet-stream,
    // bukan browser_download_url (yang tidak membawa otorisasi).
    final String apkUrl = apkAsset['url'] as String? ?? '';
    if (apkUrl.isEmpty) {
      return null;
    }
    final RegExpMatch? codeMatch =
        RegExp(r'versionCode:\s*(\d+)').firstMatch(body);
    return UpdateInfo(
      versionName: versionName,
      versionCode: codeMatch == null ? null : int.tryParse(codeMatch.group(1)!),
      changelog: body.isEmpty ? 'Tidak ada catatan perubahan.' : body,
      apkUrl: apkUrl,
      apkSizeBytes: apkAsset['size'] as int?,
    );
  }
}
