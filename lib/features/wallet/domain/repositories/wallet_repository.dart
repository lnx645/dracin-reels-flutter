import 'history.dart';
import 'wallet.dart';

/// Kontrak repository dompet: API bila login, lokal bila belum masuk.
/// Semua metode yang butuh login dan dipanggil tanpa token memakai mode
/// lokal (bukan error palsu, bukan sukses palsu — state ditandai).
abstract class WalletRepository {
  Future<CoinWallet> getBalance();
  Future<int> checkin();
  Future<void> unlockEpisode(int episodeId);
  Future<VipInfo> getVip();
  Future<void> claimVip(String plan);
  Future<List<CoinPackage>> getPackages();
  Future<List<RewardTask>> getTasks();

  /// Riwayat tonton: SATU sumber untuk "Lanjutkan Nonton" dan halaman
  /// Riwayat. Disimpan lokal; bila login, setiap pencatatan juga dikirim
  /// ke endpoint watch-progress API (best-effort).
  Future<void> recordWatch(HistoryEntry entry);
  Future<List<HistoryEntry>> getHistory();
  Future<void> putProgress(int episodeId, int positionSeconds);
  Future<List<EpisodeComment>> getComments(int episodeId);
  Future<void> postComment(int episodeId, String content);
  Future<void> toggleLike(int episodeId, bool liked);
  Future<void> toggleBookmark(int seriesId, bool bookmarked);
}
