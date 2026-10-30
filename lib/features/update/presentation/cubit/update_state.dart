import '../../domain/entities/update_info.dart';

abstract class UpdateState {
  const UpdateState();
}

class UpdateInitial extends UpdateState {
  const UpdateInitial();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

/// Cek paksa (tombol "Periksa Update") memastikan tidak ada versi
/// lebih baru. State ini hanya dipakai cek manual — cek otomatis yang
/// tidak menemukan update tetap diam (UpdateInitial).
class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

/// Pembaruan tersedia dan menunggu keputusan pengguna.
class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.info);

  final UpdateInfo info;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);

  /// 0..1; -1 bila total ukuran tidak diketahui.
  final double progress;
}

/// APK sudah terunduh dan installer sedang dibuka.
class UpdateDownloaded extends UpdateState {
  const UpdateDownloaded(this.filePath);

  final String filePath;
}

class UpdateError extends UpdateState {
  const UpdateError(this.message);

  final String message;
}
