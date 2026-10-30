import '../../domain/entities/episode.dart';
import 'feed_event.dart';

class FeedState {
  const FeedState({
    this.episodes = const <Episode>[],
    this.currentIndex = 0,
    this.tab = FeedTab.forYou,
    this.isLoading = false,
    this.errorMessage,
    this.followedSeriesIds = const <int>{},
    this.preferenceScores = const <int, int>{},
  });

  final List<Episode> episodes;
  final int currentIndex;
  final FeedTab tab;

  /// True saat memuat dari API (bukan saat daftar kosong karena
  /// memang tidak ada data — itu empty state, bukan loading).
  final bool isLoading;

  /// Pesan error ASLI dari request API terakhir; null bila tidak ada.
  final String? errorMessage;

  /// Id series yang di-bookmark pengguna (dari API /bookmarks).
  /// Mengikuti HANYA dari sini — aturan lama "nomor ganjil" adalah
  /// data palsu dan sudah dihapus.
  final Set<int> followedSeriesIds;

  /// Skor preferensi per series (dari riwayat/like/bookmark + genre):
  /// 0/absen = tanpa sinyal. Dipakai mengurutkan Untuk Anda; bila
  /// semua skor 0 (belum masuk / belum ada data) → urutan default
  /// terbaru, TANPA klaim "dipersonalisasi" di UI.
  final Map<int, int> preferenceScores;

  /// Daftar yang tampil: Mengikuti = episode dari series yang
  /// di-bookmark; Untuk Anda = semua, diurutkan skor preferensi
  /// tertinggi dulu, lalu series terbaru dulu, lalu nomor episode.
  List<Episode> get visibleEpisodes {
    final List<Episode> list = tab == FeedTab.following
        ? episodes
            .where((episode) => followedSeriesIds.contains(episode.seriesId))
            .toList()
        : episodes.toList();
    list.sort((a, b) {
      final scoreA = preferenceScores[a.seriesId] ?? 0;
      final scoreB = preferenceScores[b.seriesId] ?? 0;
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      if (a.seriesCreatedAtMs != b.seriesCreatedAtMs) {
        return b.seriesCreatedAtMs.compareTo(a.seriesCreatedAtMs);
      }
      final bySeries = a.seriesId.compareTo(b.seriesId);
      if (bySeries != 0) {
        return bySeries;
      }
      return a.number.compareTo(b.number);
    });
    return list;
  }

  FeedState copyWith({
    List<Episode>? episodes,
    int? currentIndex,
    FeedTab? tab,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<int>? followedSeriesIds,
    Map<int, int>? preferenceScores,
  }) {
    return FeedState(
      episodes: episodes ?? this.episodes,
      currentIndex: currentIndex ?? this.currentIndex,
      tab: tab ?? this.tab,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      followedSeriesIds: followedSeriesIds ?? this.followedSeriesIds,
      preferenceScores: preferenceScores ?? this.preferenceScores,
    );
  }
}
