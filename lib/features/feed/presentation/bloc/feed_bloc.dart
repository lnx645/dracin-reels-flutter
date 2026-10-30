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
        _toggleLike = ToggleLike(repository),
        _toggleBookmark = ToggleBookmark(repository),
        super(const FeedState()) {
    on<FeedStarted>(_onStarted);
    on<FeedLoadMore>(_onLoadMore);
    on<FeedLikeToggled>(_onLikeToggled);
    on<FeedBookmarkToggled>(_onBookmarkToggled);
    on<FeedIndexChanged>(_onIndexChanged);
    on<FeedEpisodeJumped>(_onEpisodeJumped);
    on<FeedTabChanged>(_onTabChanged);
    on<FeedPreferencesChanged>(_onPreferencesChanged);
    on<FeedFollowingChanged>(_onFollowingChanged);
  }

  final EpisodeRepository _repository;
  final ToggleLike _toggleLike;
  final ToggleBookmark _toggleBookmark;

  static const int _pageSize = 20;

  /// Daftar episode saat ini tanpa memuat ulang (untuk toggle
  /// optimistis di UI).
  List<Episode> get currentEpisodes => _repository.cachedEpisodes;

  Future<void> _onStarted(FeedStarted event, Emitter<FeedState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final page = await _repository.getEpisodesPage(
        page: 1,
        limit: _pageSize,
      );
      emit(
        state.copyWith(
          episodes: page.episodes,
          currentIndex: 0,
          page: 1,
          totalSeries: page.totalSeries,
          isLoading: false,
        ),
      );
    } on ApiException catch (error) {
      // Error ASLI diteruskan ke UI (pesan + tombol Coba Lagi),
      // bukan ditutup-tutupi dengan data contoh.
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  Future<void> _onLoadMore(
    FeedLoadMore event,
    Emitter<FeedState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.getEpisodesPage(
        page: state.page + 1,
        limit: _pageSize,
      );
      final seen = state.episodes.map((e) => e.id).toSet();
      final merged = <Episode>[
        ...state.episodes,
        ...page.episodes.where((e) => seen.add(e.id)),
      ];
      emit(
        state.copyWith(
          episodes: merged,
          page: state.page + 1,
          totalSeries: page.totalSeries,
          isLoadingMore: false,
        ),
      );
    } on ApiException {
      // Gagal muat halaman berikut = halaman lama tetap tampil;
      // pengguna bisa scroll lagi untuk mencoba (tanpa layar error
      // yang menutup feed).
      emit(state.copyWith(isLoadingMore: false));
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

  void _onPreferencesChanged(
    FeedPreferencesChanged event,
    Emitter<FeedState> emit,
  ) {
    // Pertahankan episode yang sedang tampil di posisi barunya.
    final visible = state.visibleEpisodes;
    final String? currentId = visible.isEmpty
        ? null
        : visible[state.currentIndex.clamp(0, visible.length - 1)].id;
    final next = state.copyWith(preferenceScores: event.scores);
    var index = 0;
    if (currentId != null) {
      final found =
          next.visibleEpisodes.indexWhere((episode) => episode.id == currentId);
      index = found == -1 ? 0 : found;
    }
    emit(next.copyWith(currentIndex: index));
  }

  void _onFollowingChanged(
    FeedFollowingChanged event,
    Emitter<FeedState> emit,
  ) {
    emit(
      state.copyWith(
        followedSeriesIds: event.seriesIds,
        currentIndex: state.tab == FeedTab.following ? 0 : state.currentIndex,
      ),
    );
  }
}
