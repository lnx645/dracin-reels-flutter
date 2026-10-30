import '../../domain/entities/episode.dart';
import 'feed_event.dart';

class FeedState {
  const FeedState({
    this.episodes = const <Episode>[],
    this.currentIndex = 0,
    this.tab = FeedTab.forYou,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Episode> episodes;
  final int currentIndex;
  final FeedTab tab;

  /// True saat memuat dari API (bukan saat daftar kosong karena
  /// memang tidak ada data — itu empty state, bukan loading).
  final bool isLoading;

  /// Pesan error ASLI dari request API terakhir; null bila tidak ada.
  final String? errorMessage;

  /// Daftar yang tampil: Untuk Anda = semua, Mengikuti = nomor ganjil.
  List<Episode> get visibleEpisodes {
    if (tab == FeedTab.following) {
      return episodes.where((episode) => episode.number.isOdd).toList();
    }
    return episodes;
  }

  FeedState copyWith({
    List<Episode>? episodes,
    int? currentIndex,
    FeedTab? tab,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FeedState(
      episodes: episodes ?? this.episodes,
      currentIndex: currentIndex ?? this.currentIndex,
      tab: tab ?? this.tab,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
