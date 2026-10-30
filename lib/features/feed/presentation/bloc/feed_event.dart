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
