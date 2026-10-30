import '../../../../core/api/api_client.dart';
import '../../../series/domain/entities/series.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';

/// Repository dompet API-only.
///
/// - Tanpa token → metode yang butuh login melempar ApiException
///   'Masuk dulu...' (UI menampilkan ajakan masuk, bukan data contoh).
/// - API gagal → exception diteruskan, TIDAK ada fallback lokal.
/// - Katalog publik (paket koin, tugas) memakai endpoint publik API.
/// - Riwayat dari /continue-watching API (login) — tidak ada simpanan
///   lokal lagi. Pengiriman progress tetap best-effort di latar
///   belakang (bukan data yang ditampilkan, jadi gagal kirim tidak
///   menampilkan apa pun yang palsu).
class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._api, {required this.tokenProvider});

  final ApiClient _api;

  /// Mengembalikan token sesi saat ini, atau null bila belum masuk.
  final String? Function() tokenProvider;

  bool get _hasToken {
    final token = tokenProvider();
    return token != null && token.isNotEmpty;
  }

  @override
  bool get hasSession => _hasToken;

  void _requireSession(String action) {
    if (!_hasToken) {
      throw ApiException('Masuk dulu untuk $action.');
    }
  }

  @override
  Future<CoinWallet> getBalance() async {
    _requireSession('melihat saldo');
    final data = await _api.getJson('/wallet');
    if (data is Map<String, dynamic> && data['balance'] is int) {
      return CoinWallet(
        balance: data['balance'] as int,
        loggedIn: true,
      );
    }
    throw const ApiException('Format saldo tidak dikenali.');
  }

  @override
  Future<int> checkin() async {
    _requireSession('check-in');
    final data = await _api.postJson('/checkin', <String, dynamic>{});
    if (data is Map<String, dynamic>) {
      final balance = data['balance'] ?? data['new_balance'];
      if (balance is int) {
        return balance;
      }
      final reward = data['coin_reward'] ?? data['reward'];
      if (reward is int) {
        final wallet = await getBalance();
        return wallet.balance ?? 0;
      }
    }
    final wallet = await getBalance();
    return wallet.balance ?? 0;
  }

  @override
  Future<void> unlockEpisode(int episodeId) async {
    _requireSession('membuka episode');
    await _api.postJson('/unlock', <String, dynamic>{
      'episode_id': episodeId,
    });
  }

  @override
  Future<VipInfo> getVip() async {
    if (!_hasToken) {
      // Tanpa akun tidak ada VIP — ini fakta, bukan data contoh.
      return const VipInfo(isActive: false);
    }
    final data = await _api.getJson('/vip');
    return VipInfo.fromJson(data);
  }

  @override
  Future<void> claimVip(String plan) async {
    _requireSession('mengklaim VIP');
    await _api.postJson('/vip/claim', <String, dynamic>{'plan': plan});
  }

  @override
  Future<List<CoinPackage>> getPackages() async {
    final data = await _api.getJson('/coin-packages');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(CoinPackage.fromJson)
          .toList();
    }
    throw const ApiException('Format paket koin tidak dikenali.');
  }

  @override
  Future<List<RewardTask>> getTasks() async {
    final data = await _api.getJson('/rewards/tasks');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(RewardTask.fromJson)
          .toList();
    }
    throw const ApiException('Format tugas tidak dikenali.');
  }

  @override
  Future<void> recordWatch(HistoryEntry entry) async {
    await putProgress(entry.episodeId, entry.positionSeconds);
  }

  @override
  Future<List<HistoryEntry>> getHistory() async {
    if (!_hasToken) {
      return <HistoryEntry>[];
    }
    final data = await _api.getJson('/continue-watching');
    if (data is! List) {
      throw const ApiException('Format riwayat tidak dikenali.');
    }
    final entries = data
        .whereType<Map<String, dynamic>>()
        .map(_historyEntryFromProgress)
        .toList();
    entries.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return entries;
  }

  HistoryEntry _historyEntryFromProgress(Map<String, dynamic> json) {
    final dynamic episode = json['episode'];
    final dynamic series = json['series'];
    final int episodeId = json['episode_id'] is int
        ? json['episode_id'] as int
        : (episode is Map<String, dynamic> && episode['id'] is int
            ? episode['id'] as int
            : 0);
    final int seriesId = series is Map<String, dynamic> &&
            series['id'] is int
        ? series['id'] as int
        : 0;
    final String seriesTitle = series is Map<String, dynamic> &&
            series['title'] is String
        ? series['title'] as String
        : 'Series';
    final String title = episode is Map<String, dynamic> &&
            episode['title'] is String
        ? episode['title'] as String
        : 'Episode';
    final int number = episode is Map<String, dynamic> &&
            episode['number'] is int
        ? episode['number'] as int
        : 0;
    final int position = json['position_seconds'] is int
        ? json['position_seconds'] as int
        : 0;
    final DateTime? watchedAt = json['last_watched_at'] is String
        ? DateTime.tryParse(json['last_watched_at'] as String)
        : null;
    return HistoryEntry(
      episodeId: episodeId,
      seriesId: seriesId,
      seriesTitle: seriesTitle,
      title: title,
      number: number,
      positionSeconds: position,
      finished: json['finished'] is bool ? json['finished'] as bool : false,
      updatedAtMs: watchedAt?.millisecondsSinceEpoch ?? 0,
    );
  }

  @override
  Future<void> putProgress(int episodeId, int positionSeconds) async {
    if (!_hasToken) {
      return;
    }
    try {
      await _api.putJson('/watch-progress', <String, dynamic>{
        'episode_id': episodeId,
        'position_seconds': positionSeconds,
        'finished': false,
      });
    } on ApiException {
      // Pengiriman progress latar belakang: gagal kirim tidak
      // menampilkan data palsu dan tidak mengganggu nonton.
    }
  }

  @override
  Future<List<EpisodeComment>> getComments(int episodeId) async {
    final data = await _api.getJson('/episodes/$episodeId/comments');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(EpisodeComment.fromJson)
          .toList();
    }
    throw const ApiException('Format komentar tidak dikenali.');
  }

  @override
  Future<void> postComment(int episodeId, String content) async {
    _requireSession('menulis komentar');
    await _api.postJson('/episodes/$episodeId/comments', <String, dynamic>{
      'content': content,
    });
  }

  @override
  Future<void> toggleLike(int episodeId, bool liked) async {
    _requireSession('menyukai episode');
    if (liked) {
      await _api.postJson('/likes/$episodeId', <String, dynamic>{});
    } else {
      await _api.delete('/likes/$episodeId');
    }
  }

  @override
  Future<void> toggleBookmark(int seriesId, bool bookmarked) async {
    _requireSession('menyimpan bookmark');
    if (bookmarked) {
      await _api.postJson('/bookmarks/$seriesId', <String, dynamic>{});
    } else {
      await _api.delete('/bookmarks/$seriesId');
    }
  }

  @override
  Future<List<Series>> getBookmarks() async {
    _requireSession('melihat bookmark');
    final data = await _api.getJson('/bookmarks');
    if (data is! List) {
      throw const ApiException('Format bookmark tidak dikenali.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(Series.fromJson)
        .toList();
  }

  @override
  Future<void> removeBookmark(int seriesId) async {
    _requireSession('menghapus bookmark');
    await _api.delete('/bookmarks/$seriesId');
  }
}
