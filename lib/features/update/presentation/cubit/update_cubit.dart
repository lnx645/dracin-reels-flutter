import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/apk_installer.dart';
import '../../data/services/update_downloader.dart';
import '../../domain/entities/update_info.dart';
import '../../domain/repositories/update_repository.dart';
import 'update_state.dart';

/// Orkestrasi updater: cek berkala, unduh, pasang.
///
/// Kegagalan CEK tidak pernah menampilkan apa pun (diam sampai cek
/// berikutnya) — hanya kegagalan UNDUH yang menampilkan pesan, karena
/// unduhan dipicu langsung oleh pengguna lewat tombol "Update Sekarang".
class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit(
    this._repository,
    this._downloader,
    this._installer,
  ) : super(const UpdateInitial());

  static const String _lastCheckKey = 'updater_last_check_ms';

  /// Jeda minimum antar pemeriksaan: sekali sehari.
  static const Duration checkInterval = Duration(hours: 24);

  final UpdateRepository _repository;
  final UpdateDownloader _downloader;
  final ApkInstaller _installer;

  UpdateInfo? _pending;

  /// Cek bila sudah waktunya (sekali sehari). Dipanggil dari UpdateGate
  /// setelah frame pertama, di latar belakang, tanpa menghambat buka app.
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
    await prefs.setInt(_lastCheckKey, now);
    emit(const UpdateChecking());
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final UpdateInfo? latest = await _repository.checkLatest(
        currentVersion: info.version,
        currentVersionCode: int.tryParse(info.buildNumber) ?? 0,
      );
      if (latest == null) {
        emit(const UpdateInitial());
        return;
      }
      _pending = latest;
      emit(UpdateAvailable(latest));
    } catch (_) {
      // Cek gagal (jaringan/API): diam, coba lagi besok.
      emit(const UpdateInitial());
    }
  }

  /// Pengguna memilih "Nanti": tutup tawaran sampai cek berikutnya.
  void dismiss() {
    _pending = null;
    emit(const UpdateInitial());
  }

  Future<void> download() async {
    final UpdateInfo? info = _pending;
    if (info == null) {
      return;
    }
    emit(const UpdateDownloading(-1));
    try {
      final file = await _downloader.download(
        url: info.apkUrl,
        onProgress: (double progress) {
          if (!isClosed) {
            emit(UpdateDownloading(progress));
          }
        },
      );
      _pending = null;
      emit(UpdateDownloaded(file.path));
    } on DownloadCancelled {
      emit(const UpdateInitial());
    } on Exception catch (e) {
      emit(UpdateError('Unduhan gagal: ${e.toString()}'));
    }
  }

  void cancelDownload() {
    _downloader.cancel();
  }

  /// Buka installer sistem untuk berkas yang sudah terunduh.
  /// Mengembalikan pesan untuk ditampilkan bila ada yang perlu
  /// dilakukan pengguna (mis. mengaktifkan izin pasang).
  Future<String?> install(String filePath) async {
    final ({InstallResult result, String message}) outcome =
        await _installer.installApk(filePath);
    emit(const UpdateInitial());
    switch (outcome.result) {
      case InstallResult.opened:
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
