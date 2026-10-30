import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/episode_repository.dart';
import '../../domain/usecases/episode_usecases.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc(EpisodeRepository repository)
      : _getEpisodes = GetEpisodes(repository),
        _toggleLike = ToggleLike(repository),
        _toggleBookmark = ToggleBookmark(repository),
        super(const FeedState()) {
    on<FeedStarted>(_onStarted);
    on<FeedLikeToggled>(_onLikeToggled);
    on<FeedBookmarkToggled>(_onBookmarkToggled);
    on<FeedIndexChanged>(_onIndexChanged);
    on<FeedEpisodeJumped>(_onEpisodeJumped);
    on<FeedTabChanged>(_onTabChanged);
  }

  final GetEpisodes _getEpisodes;
  final ToggleLike _toggleLike;
  final ToggleBookmark _toggleBookmark;

  void _onStarted(FeedStarted event, Emitter<FeedState> emit) {
    emit(state.copyWith(episodes: _getEpisodes()));
  }

  void _onLikeToggled(FeedLikeToggled event, Emitter<FeedState> emit) {
    _toggleLike(event.id);
    emit(state.copyWith(episodes: _getEpisodes()));
  }

  void _onBookmarkToggled(
    FeedBookmarkToggled event,
    Emitter<FeedState> emit,
  ) {
    _toggleBookmark(event.id);
    emit(state.copyWith(episodes: _getEpisodes()));
  }

  void _onIndexChanged(FeedIndexChanged event, Emitter<FeedState> emit) {
    final max = state.visibleEpisodes.length - 1;
    if (max < 0) {
      return;
    }
    emit(state.copyWith(currentIndex: event.index.clamp(0, max)));
  }

  void _onEpisodeJumped(FeedEpisodeJumped event, Emitter<FeedState> emit) {
    final visible = state.visibleEpisodes;
    final index = visible.indexWhere((episode) => episode.id == event.episodeId);
    emit(state.copyWith(currentIndex: index == -1 ? 0 : index));
  }

  void _onTabChanged(FeedTabChanged event, Emitter<FeedState> emit) {
    emit(state.copyWith(tab: event.tab, currentIndex: 0));
  }
}
