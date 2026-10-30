import '../../domain/entities/update_info.dart';
import '../../domain/repositories/update_repository.dart';
import '../datasources/github_release_datasource.dart';

/// Membandingkan rilis terbaru dengan versi terinstal.
///
/// Urutan perbandingan: (1) versionCode numerik bila catatan rilis
/// memuatnya (paling bisa diandalkan — GitHub API tidak menyediakan
/// versionCode, jadi workflow menuliskannya di catatan rilis);
/// (2) semver tag (vX.Y.Z) bila versionCode tidak tersedia.
class UpdateRepositoryImpl implements UpdateRepository {
  UpdateRepositoryImpl(this._dataSource);

  final GithubReleaseDataSource _dataSource;

  @override
  Future<UpdateInfo?> checkLatest({
    required String currentVersion,
    required int currentVersionCode,
  }) async {
    final UpdateInfo? latest = await _dataSource.fetchLatest();
    if (latest == null) {
      return null;
    }
    if (latest.versionCode != null) {
      return latest.versionCode! > currentVersionCode ? latest : null;
    }
    return _isNewerVersion(latest.versionName, currentVersion) ? latest : null;
  }

  bool _isNewerVersion(String latest, String current) {
    final List<int> latestParts = _parse(latest);
    final List<int> currentParts = _parse(current);
    final int length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;
    for (var i = 0; i < length; i++) {
      final int a = i < latestParts.length ? latestParts[i] : 0;
      final int b = i < currentParts.length ? currentParts[i] : 0;
      if (a != b) {
        return a > b;
      }
    }
    return false;
  }

  List<int> _parse(String version) {
    final String clean = version.split('-').first.split('+').first;
    return clean
        .split('.')
        .map((String part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
