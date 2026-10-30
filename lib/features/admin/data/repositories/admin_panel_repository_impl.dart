import '../../../../core/api/api_client.dart';
import '../../domain/entities/admin_panel.dart';
import '../../domain/repositories/admin_panel_repository.dart';

/// Implementasi panel admin dari endpoint /admin/* backend.
/// getPage dipakai untuk daftar (meta.total dipertahankan); getJson
/// untuk objek tunggal. Query dibentuk eksplisit — tidak ada param
/// yang ditebak (status VIP: active/expired; tipe transaksi hanya
/// checkin yang dikirim filter, selebihnya tanpa filter).
class AdminPanelRepositoryImpl implements AdminPanelRepository {
  AdminPanelRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<AdminStats> getStats() async {
    final data = await _api.getJson('/admin/stats');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Format statistik admin tidak dikenali.');
    }
    return AdminStats.fromJson(data);
  }

  @override
  Future<AdminPage<AdminUser>> getUsers({
    required int page,
    required int limit,
    String? query,
  }) async {
    var path = '/admin/users?page=$page&limit=$limit';
    if (query != null && query.isNotEmpty) {
      path += '&q=${Uri.encodeQueryComponent(query)}';
    }
    final result = await _api.getPage(path);
    return AdminPage<AdminUser>(
      items: result.data
          .whereType<Map<String, dynamic>>()
          .map(AdminUser.fromJson)
          .toList(),
      total: result.total,
    );
  }

  @override
  Future<AdminUser> getUser(int id) async {
    final data = await _api.getJson('/admin/users/$id');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Format pengguna tidak dikenali.');
    }
    return AdminUser.fromJson(data);
  }

  @override
  Future<AdminUser> updateUser(
    int id, {
    String? role,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (role != null) {
      body['role'] = role;
    }
    if (isActive != null) {
      body['is_active'] = isActive;
    }
    final data = await _api.putJson('/admin/users/$id', body);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Format pengguna tidak dikenali.');
    }
    return AdminUser.fromJson(data);
  }

  @override
  Future<AdminPage<AdminVipSubscription>> getVipSubscriptions({
    required int page,
    required int limit,
    String? status,
  }) async {
    var path = '/admin/vip-subscriptions?page=$page&limit=$limit';
    if (status != null && status.isNotEmpty) {
      path += '&status=${Uri.encodeQueryComponent(status)}';
    }
    final result = await _api.getPage(path);
    return AdminPage<AdminVipSubscription>(
      items: result.data
          .whereType<Map<String, dynamic>>()
          .map(AdminVipSubscription.fromJson)
          .toList(),
      total: result.total,
    );
  }

  @override
  Future<AdminPage<AdminTransaction>> getTransactions({
    required int page,
    required int limit,
    String? type,
  }) async {
    var path = '/admin/transactions?page=$page&limit=$limit';
    if (type != null && type.isNotEmpty) {
      path += '&type=${Uri.encodeQueryComponent(type)}';
    }
    final result = await _api.getPage(path);
    return AdminPage<AdminTransaction>(
      items: result.data
          .whereType<Map<String, dynamic>>()
          .map(AdminTransaction.fromJson)
          .toList(),
      total: result.total,
    );
  }
}
