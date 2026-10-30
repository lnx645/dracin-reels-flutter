/// Entitas dompet & hadiah. Lapisan domain murni.
class CoinWallet {
  const CoinWallet({required this.balance, required this.isApiMode});

  /// Saldo koin. `isApiMode` true = saldo dari API (login), false = lokal.
  final int balance;
  final bool isApiMode;
}

/// Paket koin yang dijual (katalog saja; pembelian beneran menyusul).
class CoinPackage {
  const CoinPackage({
    required this.id,
    required this.name,
    required this.coinAmount,
    required this.priceIdr,
    required this.bonusCoins,
  });

  final int id;
  final String name;
  final int coinAmount;
  final int priceIdr;
  final int bonusCoins;

  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    return CoinPackage(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name'] is String ? json['name'] as String : '',
      coinAmount:
          json['coin_amount'] is int ? json['coin_amount'] as int : 0,
      priceIdr: json['price_idr'] is int ? json['price_idr'] as int : 0,
      bonusCoins:
          json['bonus_coins'] is int ? json['bonus_coins'] as int : 0,
    );
  }
}

/// Tugas hadiah (check-in, tonton iklan, selesaikan series).
class RewardTask {
  const RewardTask({
    required this.id,
    required this.name,
    required this.type,
    required this.coinReward,
    required this.dailyLimit,
  });

  final int id;
  final String name;
  final String type;
  final int coinReward;
  final int dailyLimit;

  factory RewardTask.fromJson(Map<String, dynamic> json) {
    return RewardTask(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name'] is String ? json['name'] as String : '',
      type: json['type'] is String ? json['type'] as String : '',
      coinReward:
          json['coin_reward'] is int ? json['coin_reward'] as int : 0,
      dailyLimit:
          json['daily_limit'] is int ? json['daily_limit'] as int : 0,
    );
  }
}

/// Status VIP pengguna. `isActive` false = tidak ada VIP aktif.
class VipInfo {
  const VipInfo({
    required this.isActive,
    this.plan,
    this.endsAt,
  });

  final bool isActive;
  final String? plan;
  final String? endsAt;

  factory VipInfo.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const VipInfo(isActive: false);
    }
    final plan = json['plan'];
    final endsAt = json['ends_at'] ?? json['end_date'] ?? json['expires_at'];
    final status = json['status'];
    final isActive = status is String
        ? status == 'active'
        : plan != null || endsAt != null;
    return VipInfo(
      isActive: isActive,
      plan: plan is String ? plan : null,
      endsAt: endsAt is String ? endsAt : null,
    );
  }
}

/// Satu item "Lanjutkan Nonton" (API; bentuknya dipertahankan longgar
/// karena API mengembalikan episode + progress).
class ContinueItem {
  const ContinueItem({
    required this.episodeId,
    required this.title,
    required this.number,
    required this.positionSeconds,
    required this.finished,
  });

  final int episodeId;
  final String title;
  final int number;
  final int positionSeconds;
  final bool finished;

  factory ContinueItem.fromJson(Map<String, dynamic> json) {
    final episode = json['episode'];
    final title = json['title'];
    final episodeTitle = episode is Map<String, dynamic>
        ? episode['title']
        : null;
    final episodeNumber = episode is Map<String, dynamic>
        ? episode['number']
        : null;
    final episodeId = episode is Map<String, dynamic>
        ? episode['id']
        : json['episode_id'];
    final position = json['position_seconds'];
    return ContinueItem(
      episodeId: episodeId is int ? episodeId : 0,
      title: episodeTitle is String
          ? episodeTitle
          : (title is String ? title : 'Episode'),
      number: episodeNumber is int
          ? episodeNumber
          : (json['number'] is int ? json['number'] as int : 0),
      positionSeconds: position is int ? position : 0,
      finished: json['finished'] is bool ? json['finished'] as bool : false,
    );
  }
}

/// Satu komentar episode.
class EpisodeComment {
  const EpisodeComment({
    required this.userName,
    required this.content,
  });

  final String userName;
  final String content;

  factory EpisodeComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userName = user is Map<String, dynamic> ? user['name'] : null;
    final content = json['content'] ?? json['body'] ?? json['text'];
    return EpisodeComment(
      userName: userName is String ? userName : 'Penonton',
      content: content is String ? content : '',
    );
  }
}
