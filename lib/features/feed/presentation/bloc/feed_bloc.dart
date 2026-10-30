import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../domain/entities/episode.dart';
import '../../domain/repositories/episode_repository.dart';
import '../../domain/usecases/episode_usecases.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc(EpisodeRepository repository)
      : _repository = repository,
        _getEpisodes = GetEpisodes(repository),
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

  final EpisodeRepository _repository;
  final GetEpisodes _getEpisodes;
  final ToggleLike _toggleLike;
  final ToggleBookmark _toggleBookmark;

  /// Daftar episode saat ini tanpa memuat ulang (untuk toggle
  /// optimistis di UI).
  List<Episode> get currentEpisodes => _repository.cachedEpisodes;

  Future<void> _onStarted(FeedStarted event, Emitter<FeedState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final episodes = await _getEpisodes();
      emit(
        state.copyWith(
          episodes: episodes,
          currentIndex: 0,
          isLoading: false,
        ),
      );
    } on ApiException catch (error) {
      // Error ASLI diteruskan ke UI (pesan + tombol Coba Lagi),
      // bukan ditutup-tutupi dengan data contoh.
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  void _onLikeToggled(FeedLikeToggled event, Emitter<FeedState> emit) {
    final updated = _toggleLike(event.id);
    if (updated == null) {
      return;
    }
    emit(state.copyWith(episodes: _repository.cachedEpisodes));
  }

  void _onBookmarkToggled(
    FeedBookmarkToggled event,
    Emitter<FeedState> emit,
  ) {
    final updated = _toggleBookmark(event.id);
    if (updated == null) {
      return;
    }
    emit(state.copyWith(episodes: _repository.cachedEpisodes));
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
