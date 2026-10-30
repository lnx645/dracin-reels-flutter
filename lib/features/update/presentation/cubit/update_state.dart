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
