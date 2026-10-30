import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/apk_installer.dart';
import '../../data/services/update_downloader.dart';
import '../../domain/entities/update_info.dart';
import '../../domain/repositories/update_repository.dart';
import 'update_state.dart';

/// Orkestrasi updater canggih (sideload tetap, tanpa konflik lagi).
///
/// Urutan yang diperbaiki (keluhan "unduh lalu kembali malah unduh
/// lagi"): izin instal diperiksa SEBELUM unduhan; unduhan yang sudah
/// selesai DIINGAT (prefs + berkas berversi + ukuran) sehingga kembali
/// dari Pengaturan / batal instal tidak pernah mengulang unduhan.
/// Unduhan berjalan di latar (banner + notifikasi, bukan dialog modal
/// yang memblokir), bisa dilanjutkan bila terputus (HTTP Range), dan
/// ukurannya diverifikasi sebelum instal.
///
/// "Nanti" = lewati VERSI INI saja (dicatat di prefs): versi berikutnya
/// tetap memberi tahu. Cek paksa ("Periksa Update") mengabaikan
/// lewatan itu — pengguna yang meminta cek memang ingin tahu sekarang.
///
/// Kegagalan CEK tidak pernah menampilkan apa pun pada cek otomatis
/// (diam sampai cek berikutnya) — hanya kegagalan UNDUH / cek paksa
/// yang menampilkan pesan, karena itu dipicu langsung oleh pengguna.
class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit(
    this._repository,
    this._downloader,
    this._installer,
  ) : super(const UpdateInitial());

  static const String _lastCheckKey = 'updater_last_check_ms';
  static const String _skippedKey = 'updater_skipped_version';
  static const String _downloadedVersionKey =
      'updater_downloaded_version_code';
  static const String _downloadedPathKey = 'updater_downloaded_path';
  static const String _downloadedSizeKey = 'updater_downloaded_size';

  /// Jeda minimum antar pemeriksaan otomatis: sekali sehari.
  static const Duration checkInterval = Duration(hours: 24);

  final UpdateRepository _repository;
  final UpdateDownloader _downloader;
  final ApkInstaller _installer;

  UpdateInfo? _pending;
  double _lastNotifiedProgress = -1;

  /// Cek bila sudah waktunya (sekali sehari). Dipanggil dari UpdateGate
  /// setelah frame pertama, di latar belakang, tanpa menghambat buka app.
  /// Versi yang sudah dilewati ("Nanti") tidak memunculkan dialog lagi.
  Future<void> checkIfDue() async {
    if (state is UpdateChecking || state is UpdateDownloading) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int last = prefs.getInt(_lastCheckKey) ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < checkInterval.inMilliseconds) {
      return;
    }
    await _runCheck(prefs, now, forced: false);
  }

  /// Cek PAKSA dari tombol "Periksa Update" di Profil: abaikan jeda
  /// 24 jam DAN abaikan lewatan versi — pengguna yang meminta cek ini
  /// memang ingin tahu sekarang.
  Future<void> checkNow() async {
    if (state is UpdateChecking ||
        state is UpdateDownloading ||
        state is UpdateAvailable) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _runCheck(prefs, now, forced: true);
  }

  Future<void> _runCheck(
    SharedPreferences prefs,
    int now, {
    required bool forced,
  }) async {
    emit(const UpdateChecking());
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final UpdateInfo? latest = await _repository.checkLatest(
        currentVersion: info.version,
        currentVersionCode: int.tryParse(info.buildNumber) ?? 0,
      );
      // Waktu cek dicatat HANYA bila request berhasil. Sebelumnya
      // dicatat SEBELUM fetch — cek yang gagal jaringan ikut membakar
      // jatah 24 jam berikutnya (dialog makin lama tidak muncul).
      await prefs.setInt(_lastCheckKey, now);
      if (latest == null) {
        emit(forced ? const UpdateUpToDate() : const UpdateInitial());
        return;
      }
      if (!forced && await _isSkipped(prefs, latest)) {
        // Versi ini sudah dilewati ("Nanti"): diam. Versi berikutnya
        // (lebih baru dari yang dilewati) tetap memunculkan dialog.
        emit(const UpdateInitial());
        return;
      }
      _pending = latest;
      emit(UpdateAvailable(latest));
    } catch (_) {
      // Cek otomatis gagal: diam, coba lagi besok. Cek paksa gagal:
      // beri tahu pengguna (ia yang meminta cek ini).
      if (forced) {
        emit(
          const UpdateError(
            'Gagal memeriksa update. Periksa koneksi internet.',
          ),
        );
      } else {
        emit(const UpdateInitial());
      }
    }
  }

  /// Kunci lewatan: versionCode bila ada, nama versi bila tidak.
  String _skipKeyFor(UpdateInfo info) => info.versionCode != null
      ? 'vc:${info.versionCode}'
      : 'vn:${info.versionName}';

  Future<bool> _isSkipped(
    SharedPreferences prefs,
    UpdateInfo latest,
  ) async {
    final String? skipped = prefs.getString(_skippedKey);
    if (skipped == null) {
      return false;
    }
    if (skipped == _skipKeyFor(latest)) {
      return true;
    }
    // Lewatan lama masih berlaku hanya untuk versi itu; versi yang
    // lebih baru (code naik) tidak ikut dilewati.
    if (latest.versionCode != null && skipped.startsWith('vc:')) {
      final int? skippedCode = int.tryParse(skipped.substring(3));
      if (skippedCode != null && latest.versionCode! <= skippedCode) {
        return true;
      }
    }
    return false;
  }

  Future<void> _recordSkipped(UpdateInfo info) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedKey, _skipKeyFor(info));
    } catch (_) {}
  }

  /// Pengguna memilih "Nanti": tutup tawaran DAN catat versi ini
  /// dilewati (cek otomatis berikutnya diam untuk versi ini, tapi
  /// versi berikutnya tetap memberi tahu; cek paksa tetap jalan).
  void dismiss() {
    final UpdateInfo? info = _pending;
    _pending = null;
    if (info != null) {
      _recordSkipped(info);
    }
    emit(const UpdateInitial());
  }

  /// Unduhan yang sudah selesai + masih cocok (prefs + berkas +
  /// ukuran). Dipakai untuk melewati unduhan tanpa jaringan sama
  /// sekali — kuncinya "kembali dari Pengaturan / batal instal tidak
  /// mengulang unduhan".
  Future<String?> _rememberedDownload(UpdateInfo info) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? code = prefs.getInt(_downloadedVersionKey);
      final String? path = prefs.getString(_downloadedPathKey);
      final int? size = prefs.getInt(_downloadedSizeKey);
      if (info.versionCode != null && code != info.versionCode) {
        return null;
      }
      if (path == null || path.isEmpty) {
        return null;
      }
      final String? verified = await _downloader.completedFile(
        versionCode: info.versionCode,
        expectedSizeBytes: info.apkSizeBytes,
      ).then((file) => file?.path);
      // Prefs harus menunjuk berkas yang benar-benar terverifikasi.
      if (verified == null || verified != path) {
        return null;
      }
      if (size != null &&
          info.apkSizeBytes != null &&
          size != info.apkSizeBytes) {
        return null;
      }
      return verified;
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordDownload(UpdateInfo info, String path) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (info.versionCode != null) {
        await prefs.setInt(_downloadedVersionKey, info.versionCode!);
      }
      await prefs.setString(_downloadedPathKey, path);
      if (info.apkSizeBytes != null) {
        await prefs.setInt(_downloadedSizeKey, info.apkSizeBytes!);
      }
    } catch (_) {}
  }

  Future<void> _notifyProgress(double progress) async {
    if (progress < 0) {
      if (_lastNotifiedProgress != -1) {
        _lastNotifiedProgress = -1;
        await _installer.showDownloadNotification(-1);
      }
      return;
    }
    // Throttle: notifikasi diperbarui tiap >= 2% (tidak membanjiri).
    if (_lastNotifiedProgress >= 0 &&
        (progress - _lastNotifiedProgress) < 0.02 &&
        progress < 1) {
      return;
    }
    _lastNotifiedProgress = progress;
    await _installer.showDownloadNotification((progress * 100).round());
  }

  /// Mulai unduhan (dari dialog "Update Sekarang" / "Coba Lagi" /
  /// kembali dari Pengaturan). Urutan: ingatan → izin → unduh latar.
  Future<void> download() async {
    final UpdateInfo? info = _pending;
    if (info == null) {
      return;
    }
    // 1. Sudah pernah terunduh lengkap → langsung siap pasang.
    final String? remembered = await _rememberedDownload(info);
    if (remembered != null) {
      emit(UpdateDownloaded(remembered, info));
      return;
    }
    // 2. Izin DULU — tidak pernah mengunduh sebelum izin dipastikan.
    if (!await _installer.canRequestPackageInstalls()) {
      emit(UpdatePermissionRequired(info));
      return;
    }
    // 3. Unduh di latar: banner + notifikasi (bukan dialog modal).
    // Izin notifikasi ditolak pun tidak memblokir unduhan.
    await _installer.ensureNotificationPermission();
    _lastNotifiedProgress = -1;
    emit(const UpdateDownloading(-1));
    try {
      final file = await _downloader.download(
        url: info.apkUrl,
        versionCode: info.versionCode,
        expectedSizeBytes: info.apkSizeBytes,
        onProgress: (double progress) {
          if (!isClosed) {
            emit(UpdateDownloading(progress));
            _notifyProgress(progress);
          }
        },
      );
      await _recordDownload(info, file.path);
      await _installer.hideDownloadNotification();
      _pending = null;
      emit(UpdateDownloaded(file.path, info));
    } on DownloadCancelled {
      // Setengah jadi DIPERTAHANKAN untuk dilanjutkan (bukan dihapus).
      await _installer.hideDownloadNotification();
      emit(const UpdateInitial());
    } on DownloadSizeMismatch {
      await _installer.hideDownloadNotification();
      emit(
        UpdateDownloadError(
          'Berkas unduhan rusak (ukuran tidak cocok dengan rilis). '
          'Coba lagi — unduhan akan diulang bersih.',
          info,
        ),
      );
    } on Exception catch (e) {
      await _installer.hideDownloadNotification();
      emit(UpdateDownloadError('Unduhan gagal: ${e.toString()}', info));
    }
  }

  /// "Coba Lagi" dari dialog galat unduhan: melanjutkan dari berkas
  /// setengah jadi (HTTP Range), bukan dari nol.
  Future<void> retryDownload(UpdateInfo info) async {
    _pending = info;
    await download();
  }

  void cancelDownload() {
    _downloader.cancel();
  }

  /// Pengguna mengetuk "Buka Pengaturan" di dialog izin: tutup dialog
  /// (state diam), buka Pengaturan, dan tunggu kembali — saat aplikasi
  /// kembali ke depan, gerbang memanggil [checkPermissionAndContinue].
  Future<void> openPermissionSettings() async {
    final UpdateInfo? info = _pending;
    if (info == null) {
      return;
    }
    emit(UpdateAwaitingPermission(info));
    await _installer.openInstallSettings();
  }

  /// Buka halaman detail aplikasi di Pengaturan (tombol Uninstall ada
  /// di sana) — dipakai dialog ketidakcocokan tanda tangan.
  Future<void> openAppSettings() async {
    await _installer.openAppSettings();
  }

  /// Dipanggil gerbang saat aplikasi kembali dari Pengaturan izin:
  /// sudah diberikan → unduh jalan (sekali); belum → dialog izin lagi.
  Future<void> checkPermissionAndContinue() async {
    final UpdateInfo? info = _pending;
    if (info == null || state is UpdateDownloading) {
      return;
    }
    if (await _installer.canRequestPackageInstalls()) {
      await download();
    } else {
      emit(UpdatePermissionRequired(info));
    }
  }

  /// Buka installer untuk berkas yang sudah terunduh.
  ///
  /// Pra-cek tanda tangan: bila tanda tangan APK baru BERBEDA dari
  /// aplikasi terinstal, installer TIDAK dibuka (pasti ditolak samar)
  /// — gantinya dialog ketidakcocokan dengan panduan uninstall sekali
  /// + salinan di folder Downloads. Pra-cek tidak bisa membaca tanda
  /// tangan = fail-open ke installer normal.
  /// Mengembalikan pesan untuk snackbar bila ada yang perlu dilakukan
  /// pengguna; null bila installer terbuka / dialog sudah ditangani.
  Future<String?> install(String filePath, UpdateInfo info) async {
    // Jaring pengaman izin di sisi instal (bila izin dicabut sesudah
    // unduh): kembali ke alur izin — unduhan tetap diingat.
    if (!await _installer.canRequestPackageInstalls()) {
      _pending = info;
      emit(UpdatePermissionRequired(info));
      return null;
    }
    final String? installed =
        await _installer.getInstalledSignatureSha256();
    final String? apk =
        await _installer.getApkSignatureSha256(filePath);
    if (installed != null &&
        apk != null &&
        installed.toLowerCase() != apk.toLowerCase()) {
      String? downloadsPath;
      try {
        downloadsPath = await _installer.saveToDownloads(filePath);
      } catch (_) {
        downloadsPath = null;
      }
      emit(UpdateSignatureMismatch(info, filePath, downloadsPath));
      return null;
    }
    final ({InstallResult result, String message}) outcome =
        await _installer.installApk(filePath);
    emit(const UpdateInitial());
    switch (outcome.result) {
      case InstallResult.opened:
        // Installer dibatalkan pengguna tidak menagih lagi di sesi
        // yang sama: tidak ada yang meng-emit ulang Downloaded, dan
        // unduhan tetap diingat — ketuk update lagi langsung instal.
        return null;
      case InstallResult.permissionRequired:
        await _installer.openInstallSettings();
        return 'Aktifkan "Izinkan dari sumber ini" untuk Dracin Reels, '
            'lalu kembali dan ketuk "Pasang" lagi.';
      case InstallResult.failed:
        return outcome.message;
    }
  }
}
