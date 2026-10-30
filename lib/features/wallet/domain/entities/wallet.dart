/// Entitas dompet & hadiah. Lapisan domain murni.
class CoinWallet {
  const CoinWallet({required this.balance, required this.loggedIn});

  /// Saldo koin dari API. null = belum masuk (tidak ada saldo lokal
  /// contoh — angka 100 lama sudah dihapus).
  final int? balance;

  /// True bila ada sesi login (saldo/VIP/riwayat dari API).
  final bool loggedIn;
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
    this.seriesId = 0,
  });

  final int episodeId;
  final String title;
  final int number;
  final int positionSeconds;
  final bool finished;

  /// Id series API pemilik episode (0 = tidak diketahui).
  final int seriesId;

  factory ContinueItem.fromJson(Map<String, dynamic> json) {
    final episode = json['episode'];
    final series = json['series'];
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
    final seriesId = series is Map<String, dynamic>
        ? series['id']
        : json['series_id'];
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
      seriesId: seriesId is int ? seriesId : 0,
    );
  }
}

/// Satu komentar episode.
///
/// Bentuk API baru (backend sosial): `id`, `user_name`, `body`,
/// `like_count`, `liked_by_me`, `created_at`. Bentuk lama
/// (`user.name`, `content`/`text`) tetap dibaca agar tidak pecah bila
/// server belum diperbarui.
class EpisodeComment {
  const EpisodeComment({
    required this.id,
    required this.userName,
    required this.content,
    this.likeCount = 0,
    this.likedByMe = false,
    this.createdAt,
  });

  final int id;
  final String userName;
  final String content;
  final int likeCount;
  final bool likedByMe;
  final DateTime? createdAt;

  EpisodeComment copyWith({int? likeCount, bool? likedByMe}) {
    return EpisodeComment(
      id: id,
      userName: userName,
      content: content,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt,
    );
  }

  factory EpisodeComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userName = json['user_name'] is String
        ? json['user_name'] as String
        : (user is Map<String, dynamic> ? user['name'] : null);
    final content = json['body'] ?? json['content'] ?? json['text'];
    final createdRaw = json['created_at'];
    return EpisodeComment(
      id: json['id'] is int ? json['id'] as int : 0,
      userName: userName is String ? userName : 'Penonton',
      content: content is String ? content : '',
      likeCount: json['like_count'] is int ? json['like_count'] as int : 0,
      likedByMe:
          json['liked_by_me'] is bool ? json['liked_by_me'] as bool : false,
      createdAt: createdRaw is String ? DateTime.tryParse(createdRaw) : null,
    );
  }
}

/// Satu halaman komentar + total nyata (untuk lazy loading).
class CommentPage {
  const CommentPage({required this.comments, required this.total});

  final List<EpisodeComment> comments;
  final int total;
}
