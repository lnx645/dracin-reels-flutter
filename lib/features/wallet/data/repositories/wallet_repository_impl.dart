import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../domain/entities/history.dart';
import '../domain/entities/wallet.dart';
import '../domain/repositories/wallet_repository.dart';

/// Repository dompet dua mode:
/// - Ada token → API beneran (saldo, check-in, unlock, VIP, progress).
/// - Tanpa token → dompet lokal (saldo awal 100, check-in 1x/hari,
///   unlock lokal). Mode ditandai di [CoinWallet.isApiMode] agar UI jujur.
class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._api, {required this.tokenProvider});

  final ApiClient _api;

  /// Mengembalikan token sesi saat ini, atau null bila belum masuk.
  final String? Function() tokenProvider;

  static const _keyBalance = 'local_wallet_balance';
  static const _keyUnlocked = 'local_unlocked_episodes';
  static const _keyCheckinDate = 'local_checkin_date';
  static const _keyHistory = 'watch_history_json';

  bool get _hasToken {
    final token = tokenProvider();
    return token != null && token.isNotEmpty;
  }

  String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<CoinWallet> getBalance() async {
    if (_hasToken) {
      try {
        final data = await _api.getJson('/wallet');
        if (data is Map<String, dynamic> &&
            data['balance'] is int) {
          return CoinWallet(
            balance: data['balance'] as int,
            isApiMode: true,
          );
        }
      } on ApiException {
        // Jatuh ke lokal bila API gagal dijangkau.
      }
    }
    final prefs = await _prefs;
    return CoinWallet(
      balance: prefs.getInt(_keyBalance) ?? 100,
      isApiMode: false,
    );
  }

  @override
  Future<int> checkin() async {
    if (_hasToken) {
      final data = await _api.postJson('/checkin', <String, dynamic>{});
      // Bentuk respons dipertahankan longgar: saldo baru / hadiah.
      if (data is Map<String, dynamic>) {
        final balance = data['balance'] ?? data['new_balance'];
        if (balance is int) {
          return balance;
        }
        final reward = data['coin_reward'] ?? data['reward'];
        if (reward is int) {
          final wallet = await getBalance();
          return wallet.balance;
        }
      }
      final wallet = await getBalance();
      return wallet.balance;
    }
    final prefs = await _prefs;
    if (prefs.getString(_keyCheckinDate) == _today()) {
      throw const ApiException('Check-in hari ini sudah diklaim.');
    }
    final balance = (prefs.getInt(_keyBalance) ?? 100) + 10;
    await prefs.setInt(_keyBalance, balance);
    await prefs.setString(_keyCheckinDate, _today());
    return balance;
  }

  @override
  Future<void> unlockEpisode(int episodeId) async {
    if (_hasToken) {
      await _api.postJson('/unlock', <String, dynamic>{
        'episode_id': episodeId,
      });
      return;
    }
    final prefs = await _prefs;
    final unlocked = prefs.getStringList(_keyUnlocked) ?? <String>[];
    final key = '$episodeId';
    if (!unlocked.contains(key)) {
      unlocked.add(key);
      await prefs.setStringList(_keyUnlocked, unlocked);
    }
  }

  /// Harga koin episode dikurangi dari dompet lokal (mode tanpa login).
  /// Dipanggil UI setelah cek harga; API memakai potongan server.
  Future<void> deductLocal(int amount) async {
    final prefs = await _prefs;
    final balance = (prefs.getInt(_keyBalance) ?? 100) - amount;
    await prefs.setInt(_keyBalance, balance < 0 ? 0 : balance);
  }

  Future<Set<int>> getLocalUnlocked() async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_keyUnlocked) ?? <String>[];
    return list.map(int.tryParse).whereType<int>().toSet();
  }

  @override
  Future<VipInfo> getVip() async {
    if (_hasToken) {
      try {
        final data = await _api.getJson('/vip');
        return VipInfo.fromJson(data);
      } on ApiException {
        return const VipInfo(isActive: false);
      }
    }
    return const VipInfo(isActive: false);
  }

  @override
  Future<void> claimVip(String plan) async {
    if (!_hasToken) {
      throw const ApiException(
        'Masuk dulu untuk mengklaim VIP (mode sampel).',
      );
    }
    await _api.postJson('/vip/claim', <String, dynamic>{'plan': plan});
  }

  @override
  Future<List<CoinPackage>> getPackages() async {
    try {
      final data = await _api.getJson('/coin-packages');
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(CoinPackage.fromJson)
            .toList();
      }
    } on ApiException {
      // Katalog sampel di bawah.
    }
    return const <CoinPackage>[
      CoinPackage(
        id: 1,
        name: 'Paket 100 Koin',
        coinAmount: 100,
        priceIdr: 15000,
        bonusCoins: 0,
      ),
      CoinPackage(
        id: 2,
        name: 'Paket 550 Koin',
        coinAmount: 550,
        priceIdr: 75000,
        bonusCoins: 50,
      ),
      CoinPackage(
        id: 3,
        name: 'Paket 1200 Koin',
        coinAmount: 1200,
        priceIdr: 150000,
        bonusCoins: 200,
      ),
      CoinPackage(
        id: 4,
        name: 'Paket 3000 Koin',
        coinAmount: 3000,
        priceIdr: 350000,
        bonusCoins: 700,
      ),
    ];
  }

  @override
  Future<List<RewardTask>> getTasks() async {
    try {
      final data = await _api.getJson('/rewards/tasks');
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(RewardTask.fromJson)
            .toList();
      }
    } on ApiException {
      // Katalog sampel di bawah.
    }
    return const <RewardTask>[
      RewardTask(
        id: 1,
        name: 'Check-in Harian',
        type: 'checkin',
        coinReward: 10,
        dailyLimit: 1,
      ),
      RewardTask(
        id: 2,
        name: 'Tonton Iklan',
        type: 'watch_ad',
        coinReward: 5,
        dailyLimit: 5,
      ),
      RewardTask(
        id: 3,
        name: 'Selesaikan Satu Series',
        type: 'finish_series',
        coinReward: 50,
        dailyLimit: 1,
      ),
    ];
  }

  @override
  Future<void> recordWatch(HistoryEntry entry) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyHistory);
    final entries = <HistoryEntry>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              entries.add(HistoryEntry.fromJson(item));
            }
          }
        }
      } on Exception {
        // Riwayat korup: mulai ulang dari entri baru.
        entries.clear();
      }
    }
    entries.removeWhere((item) => item.episodeId == entry.episodeId);
    entries.insert(0, entry);
    final trimmed = entries.length > 100 ? entries.sublist(0, 100) : entries;
    await prefs.setString(
      _keyHistory,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
    await putProgress(entry.episodeId, entry.positionSeconds);
  }

  @override
  Future<List<HistoryEntry>> getHistory() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyHistory);
    if (raw == null || raw.isEmpty) {
      return <HistoryEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <HistoryEntry>[];
      }
      final entries = decoded
          .whereType<Map<String, dynamic>>()
          .map(HistoryEntry.fromJson)
          .toList();
      entries.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return entries;
    } on Exception {
      return <HistoryEntry>[];
    }
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
      // Progress adalah best-effort: gagal kirim tidak mengganggu nonton.
    }
  }

  @override
  Future<List<EpisodeComment>> getComments(int episodeId) async {
    try {
      final data = await _api.getJson('/episodes/$episodeId/comments');
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(EpisodeComment.fromJson)
            .toList();
      }
    } on ApiException {
      // Komentar kosong bila API tidak terjangkau.
    }
    return <EpisodeComment>[];
  }

  @override
  Future<void> postComment(int episodeId, String content) async {
    if (!_hasToken) {
      throw const ApiException('Masuk dulu untuk menulis komentar.');
    }
    await _api.postJson('/episodes/$episodeId/comments', <String, dynamic>{
      'content': content,
    });
  }

  @override
  Future<void> toggleLike(int episodeId, bool liked) async {
    if (!_hasToken) {
      return;
    }
    try {
      if (liked) {
        await _api.postJson('/likes/$episodeId', <String, dynamic>{});
      } else {
        await _api.delete('/likes/$episodeId');
      }
    } on ApiException {
      // Suka lokal tetap jalan; sinkronisasi API best-effort.
    }
  }

  @override
  Future<void> toggleBookmark(int seriesId, bool bookmarked) async {
    if (!_hasToken) {
      return;
    }
    try {
      if (bookmarked) {
        await _api.postJson('/bookmarks/$seriesId', <String, dynamic>{});
      } else {
        await _api.delete('/bookmarks/$seriesId');
      }
    } on ApiException {
      // Bookmark lokal tetap jalan; sinkronisasi API best-effort.
    }
  }
}
