/// Entitas panel admin mobile (dasbor + pengguna + member VIP +
/// transaksi koin). Semua dari endpoint admin backend yang SUDAH
/// HIDUP (backend 145178c, diverifikasi ulang via curl): JWT + role
/// admin; tanpa token → 401, viewer → 403 (ditampilkan jujur di UI,
/// bukan disembunyikan sisi klien).
class AdminStats {
  const AdminStats({
    required this.seriesCount,
    required this.episodeCount,
    required this.userCount,
    required this.activeVipCount,
    required this.transactionCount,
    required this.transactionsToday,
    required this.latestSeries,
    required this.latestEpisodes,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      seriesCount: json['series_count'] is int
          ? json['series_count'] as int
          : 0,
      episodeCount: json['episode_count'] is int
          ? json['episode_count'] as int
          : 0,
      userCount: json['user_count'] is int ? json['user_count'] as int : 0,
      activeVipCount: json['active_vip_count'] is int
          ? json['active_vip_count'] as int
          : 0,
      transactionCount: json['transaction_count'] is int
          ? json['transaction_count'] as int
          : 0,
      transactionsToday: json['transactions_today'] is int
          ? json['transactions_today'] as int
          : 0,
      latestSeries: (json['latest_series'] is List
              ? (json['latest_series'] as List)
                  .whereType<Map<String, dynamic>>()
              : <Map<String, dynamic>>[])
          .map(AdminLatestSeries.fromJson)
          .toList(),
      latestEpisodes: (json['latest_episodes'] is List
              ? (json['latest_episodes'] as List)
                  .whereType<Map<String, dynamic>>()
              : <Map<String, dynamic>>[])
          .map(AdminLatestEpisode.fromJson)
          .toList(),
    );
  }

  final int seriesCount;
  final int episodeCount;
  final int userCount;
  final int activeVipCount;
  final int transactionCount;
  final int transactionsToday;
  final List<AdminLatestSeries> latestSeries;
  final List<AdminLatestEpisode> latestEpisodes;
}

class AdminLatestSeries {
  const AdminLatestSeries({
    required this.id,
    required this.title,
    required this.status,
  });

  factory AdminLatestSeries.fromJson(Map<String, dynamic> json) {
    return AdminLatestSeries(
      id: json['id'] is int ? json['id'] as int : 0,
      title: json['title'] is String ? json['title'] as String : '',
      status: json['status'] is String ? json['status'] as String : '',
    );
  }

  final int id;
  final String title;
  final String status;
}

class AdminLatestEpisode {
  const AdminLatestEpisode({
    required this.id,
    required this.seriesId,
    required this.seriesTitle,
    required this.number,
    required this.title,
    required this.status,
  });

  factory AdminLatestEpisode.fromJson(Map<String, dynamic> json) {
    return AdminLatestEpisode(
      id: json['id'] is int ? json['id'] as int : 0,
      seriesId: json['series_id'] is int ? json['series_id'] as int : 0,
      seriesTitle: json['series_title'] is String
          ? json['series_title'] as String
          : '',
      number: json['number'] is int ? json['number'] as int : 0,
      title: json['title'] is String ? json['title'] as String : '',
      status: json['status'] is String ? json['status'] as String : '',
    );
  }

  final int id;
  final int seriesId;
  final String seriesTitle;
  final int number;
  final String title;
  final String status;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.coinBalance,
    required this.vipActive,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name'] is String ? json['name'] as String : '',
      email: json['email'] is String ? json['email'] as String : '',
      role: json['role'] is String ? json['role'] as String : '',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
      coinBalance: json['coin_balance'] is int
          ? json['coin_balance'] as int
          : 0,
      vipActive:
          json['vip_active'] is bool ? json['vip_active'] as bool : false,
      createdAt:
          json['created_at'] is String ? json['created_at'] as String : '',
    );
  }

  final int id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final int coinBalance;
  final bool vipActive;
  final String createdAt;

  AdminUser copyWith({String? role, bool? isActive}) {
    return AdminUser(
      id: id,
      name: name,
      email: email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      coinBalance: coinBalance,
      vipActive: vipActive,
      createdAt: createdAt,
    );
  }
}

class AdminVipSubscription {
  const AdminVipSubscription({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.plan,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  factory AdminVipSubscription.fromJson(Map<String, dynamic> json) {
    return AdminVipSubscription(
      id: json['id'] is int ? json['id'] as int : 0,
      userId: json['user_id'] is int ? json['user_id'] as int : 0,
      userEmail:
          json['user_email'] is String ? json['user_email'] as String : '',
      plan: json['plan'] is String ? json['plan'] as String : '',
      startsAt:
          json['starts_at'] is String ? json['starts_at'] as String : '',
      endsAt: json['ends_at'] is String ? json['ends_at'] as String : '',
      status: json['status'] is String ? json['status'] as String : '',
    );
  }

  final int id;
  final int userId;
  final String userEmail;
  final String plan;
  final String startsAt;
  final String endsAt;
  final String status;
}

class AdminTransaction {
  const AdminTransaction({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.referenceId,
    required this.createdAt,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    return AdminTransaction(
      id: json['id'] is int ? json['id'] as int : 0,
      userId: json['user_id'] is int ? json['user_id'] as int : 0,
      userEmail:
          json['user_email'] is String ? json['user_email'] as String : '',
      type: json['type'] is String ? json['type'] as String : '',
      amount: json['amount'] is int ? json['amount'] as int : 0,
      balanceAfter: json['balance_after'] is int
          ? json['balance_after'] as int
          : 0,
      referenceId: json['reference_id'] is String
          ? json['reference_id'] as String
          : '',
      createdAt:
          json['created_at'] is String ? json['created_at'] as String : '',
    );
  }

  final int id;
  final int userId;
  final String userEmail;
  final String type;
  final int amount;
  final int balanceAfter;
  final String referenceId;
  final String createdAt;
}

/// Satu halaman daftar admin + total nyata dari meta.
class AdminPage<T> {
  const AdminPage({required this.items, required this.total});

  final List<T> items;
  final int total;
}
