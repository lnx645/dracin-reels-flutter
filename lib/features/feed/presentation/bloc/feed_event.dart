enum FeedTab { forYou, following }

abstract class FeedEvent {
  const FeedEvent();
}

class FeedStarted extends FeedEvent {
  const FeedStarted();
}

class FeedLikeToggled extends FeedEvent {
  const FeedLikeToggled(this.id);

  final String id;
}

class FeedBookmarkToggled extends FeedEvent {
  const FeedBookmarkToggled(this.id);

  final String id;
}

class FeedIndexChanged extends FeedEvent {
  const FeedIndexChanged(this.index);

  final int index;
}

class FeedEpisodeJumped extends FeedEvent {
  const FeedEpisodeJumped(this.episodeId);

  final String episodeId;
}

class FeedTabChanged extends FeedEvent {
  const FeedTabChanged(this.tab);

  final FeedTab tab;
}

/// Skor preferensi baru (dihitung FeedPage dari riwayat/like/bookmark
/// + genre). Bloc mempertahankan episode yang sedang tampil: indeks
/// disesuaikan ke posisi episode itu di urutan baru.
class FeedPreferencesChanged extends FeedEvent {
  const FeedPreferencesChanged(this.scores);

  final Map<int, int> scores;
}

/// Id series bookmark dari API (untuk tab Mengikuti). Bila tab aktif
/// adalah Mengikuti, indeks di-reset (daftar berubah total).
class FeedFollowingChanged extends FeedEvent {
  const FeedFollowingChanged(this.seriesIds);

  final Set<int> seriesIds;
}
