import '../entities/admin_panel.dart';

/// Kontrak panel admin mobile. Endpoint backend SUDAH HIDUP
/// (145178c): /admin/stats, /admin/users, /admin/users/{id},
/// /admin/vip-subscriptions, /admin/transactions.
/// Gagal → ApiException dengan pesan asli server (401/403/400
/// ditampilkan jujur, bukan dialihkan diam-diam).
abstract class AdminPanelRepository {
  Future<AdminStats> getStats();

  Future<AdminPage<AdminUser>> getUsers({
    required int page,
    required int limit,
    String? query,
  });

  Future<AdminUser> getUser(int id);

  /// Hanya field yang diberikan yang dikirim. Mengubah akun sendiri
  /// ditolak server (400) — UI menampilkan pesan itu apa adanya.
  Future<AdminUser> updateUser(
    int id, {
    String? role,
    bool? isActive,
  });

  Future<AdminPage<AdminVipSubscription>> getVipSubscriptions({
    required int page,
    required int limit,
    String? status,
  });

  Future<AdminPage<AdminTransaction>> getTransactions({
    required int page,
    required int limit,
    String? type,
  });
}
