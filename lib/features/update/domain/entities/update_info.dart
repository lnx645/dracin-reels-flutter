/// Info pembaruan dari satu GitHub Release.
///
/// [versionCode] hanya terisi bila catatan rilis memuat baris
/// `versionCode: N` (workflow menulisnya sejak v0.2.1). Bila tidak ada,
/// perbandingan memakai [versionName] (tag semver) sebagai gantinya.
class UpdateInfo {
  const UpdateInfo({
    required this.versionName,
    required this.changelog,
    required this.apkUrl,
    this.versionCode,
    this.apkSizeBytes,
  });

  final String versionName;
  final int? versionCode;
  final String changelog;
  final String apkUrl;
  final int? apkSizeBytes;
}
