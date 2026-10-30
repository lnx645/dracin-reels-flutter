import '../entities/history.dart';
import '../entities/wallet.dart';
import '../../../series/domain/entities/series.dart';

/// Kontrak repository dompet: HANYA API.
///
/// - Metode yang butuh login dan dipanggil tanpa token melempar
///   ApiException 'Masuk dulu...' (UI menampilkan ajakan masuk, bukan
///   angka/saldo contoh).
/// - Metode katalog publik (paket, tugas) memakai endpoint publik API.
/// - Kegagalan API DITERUSKAN (bukan fallback diam-diam ke data lokal).
abstract class WalletRepository {
  /// True bila ada token sesi (dipakai bloc untuk membedakan state
  /// "belum masuk" dari state "gagal memuat").
  bool get hasSession;

  Future<CoinWallet> getBalance();
  Future<int> checkin();
  Future<void> unlockEpisode(int episodeId);
  Future<VipInfo> getVip();
  Future<void> claimVip(String plan);
  Future<List<CoinPackage>> getPackages();
  Future<List<RewardTask>> getTasks();

  /// Riwayat tonton: SATU sumber untuk "Lanjutkan Nonton" dan halaman
  /// Riwayat — dari endpoint /continue-watching API bila login,
  /// daftar kosong bila belum masuk. Pencatatan hanya mengirim progress
  /// ke API (tidak ada lagi simpanan lokal).
  Future<void> recordWatch(HistoryEntry entry);
  Future<List<HistoryEntry>> getHistory();
  Future<void> putProgress(int episodeId, int positionSeconds);
  Future<List<EpisodeComment>> getComments(int episodeId);
  Future<CommentPage> getCommentsPage(
    int episodeId, {
    required int page,
    required int limit,
  });
  Future<void> postComment(int episodeId, String content);
  Future<void> toggleCommentLike(int commentId, bool liked);
  Future<void> toggleLike(int episodeId, bool liked);
  Future<void> toggleBookmark(int seriesId, bool bookmarked);

  /// Daftar series yang di-bookmark dari API (butuh login).
  Future<List<Series>> getBookmarks();
  Future<void> removeBookmark(int seriesId);
}
