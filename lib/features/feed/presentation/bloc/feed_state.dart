import '../../domain/entities/episode.dart';
import 'feed_event.dart';

class FeedState {
  const FeedState({
    this.episodes = const <Episode>[],
    this.currentIndex = 0,
    this.tab = FeedTab.forYou,
  });

  final List<Episode> episodes;
  final int currentIndex;
  final FeedTab tab;

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
  }) {
    return FeedState(
      episodes: episodes ?? this.episodes,
      currentIndex: currentIndex ?? this.currentIndex,
      tab: tab ?? this.tab,
    );
  }
}
