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

/// Unduhan berjalan di latar (tidak memblokir aplikasi): progres
/// tampil di banner + notifikasi, bukan dialog modal.
class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);

  /// 0..1; -1 bila total ukuran tidak diketahui.
  final double progress;
}

/// APK sudah terunduh dan siap dipasang. Bila pengguna sedang menonton
/// video, gerbang menampilkan banner "Update siap dipasang" (tidak
/// membuka installer langsung); bila tidak menonton, installer dibuka
/// langsung dari listener gerbang.
class UpdateDownloaded extends UpdateState {
  const UpdateDownloaded(this.filePath, this.info);

  final String filePath;
  final UpdateInfo info;
}

/// Izin memasang dari sumber ini belum aktif. URUTAN DIPERBAIKI:
/// izin diperiksa SEBELUM unduhan dimulai — pengguna diarahkan ke
/// Pengaturan dulu, unduhan baru jalan sesudah izin diberikan. Tidak
/// pernah lagi mengunduh dulu baru ketahuan izin belum ada.
class UpdatePermissionRequired extends UpdateState {
  const UpdatePermissionRequired(this.info);

  final UpdateInfo info;
}

/// Menunggu pengguna kembali dari Pengaturan izin. Diam (tanpa dialog)
/// sampai aplikasi kembali ke depan — saat itu gerbang memeriksa izin
/// lagi: sudah diberikan → unduh jalan; belum → dialog izin tampil lagi.
class UpdateAwaitingPermission extends UpdateState {
  const UpdateAwaitingPermission(this.info);

  final UpdateInfo info;
}

/// Unduhan gagal (jaringan / ukuran tidak cocok sesudah satu unduh
/// ulang internal). "Coba Lagi" MELANJUTKAN dari berkas setengah jadi
/// (HTTP Range), bukan dari nol; "Nanti" = lewati versi ini saja.
class UpdateDownloadError extends UpdateState {
  const UpdateDownloadError(this.message, this.info);

  final String message;
  final UpdateInfo info;
}

/// Tanda tangan APK baru BERBEDA dari aplikasi terinstal. Installer
/// sistem PASTI menolaknya dengan pesan samar — jadi installer tidak
/// dibuka sama sekali. Dialog menjelaskan: uninstall dulu sekali,
/// lalu instal dari salinan di folder Downloads (salinan itu bertahan
/// meski aplikasi di-uninstall, tidak seperti folder file aplikasi).
/// [downloadsPath] null bila salinan ke Downloads gagal — dialog
/// mengatakannya dengan jujur (minta tautan unduh manual).
class UpdateSignatureMismatch extends UpdateState {
  const UpdateSignatureMismatch(
    this.info,
    this.filePath,
    this.downloadsPath,
  );

  final UpdateInfo info;
  final String filePath;
  final String? downloadsPath;
}

class UpdateError extends UpdateState {
  const UpdateError(this.message);

  final String message;
}
