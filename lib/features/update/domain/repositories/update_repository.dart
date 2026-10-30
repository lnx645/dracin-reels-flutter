import '../entities/update_info.dart';

/// Kontrak pemeriksaan pembaruan. Mengembalikan null bila tidak ada
/// pembaruan yang lebih baru, bila updater dinonaktifkan (tanpa token),
/// atau bila pemeriksaan gagal (kegagalan cek tidak pernah mengganggu
/// pengguna — diam saja sampai cek berikutnya).
abstract class UpdateRepository {
  Future<UpdateInfo?> checkLatest({
    required String currentVersion,
    required int currentVersionCode,
  });
}
