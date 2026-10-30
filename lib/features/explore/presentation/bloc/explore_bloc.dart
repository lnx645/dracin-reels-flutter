import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../feed/domain/entities/episode.dart';
import '../../../feed/domain/repositories/episode_repository.dart';

abstract class ExploreEvent {
  const ExploreEvent();
}

class ExploreStarted extends ExploreEvent {
  const ExploreStarted();
}

class ExploreQueryChanged extends ExploreEvent {
  const ExploreQueryChanged(this.query);

  final String query;
}

class ExploreState {
  const ExploreState({
    this.query = '',
    this.episodes = const <Episode>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final String query;
  final List<Episode> episodes;
  final bool isLoading;

  /// Pesan error ASLI dari request API terakhir.
  final String? errorMessage;

  ExploreState copyWith({
    String? query,
    List<Episode>? episodes,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExploreState(
      query: query ?? this.query,
      episodes: episodes ?? this.episodes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  ExploreBloc(this._repository) : super(const ExploreState()) {
    on<ExploreStarted>(_onStarted);
    on<ExploreQueryChanged>(_onQueryChanged);
  }

  final EpisodeRepository _repository;

  Future<void> _onStarted(
    ExploreStarted event,
    Emitter<ExploreState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final episodes = await _repository.getEpisodes();
      emit(state.copyWith(episodes: episodes, isLoading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  void _onQueryChanged(ExploreQueryChanged event, Emitter<ExploreState> emit) {
    final query = event.query.trim().toLowerCase();
    final all = _repository.cachedEpisodes;
    final filtered = query.isEmpty
        ? all
        : all.where((episode) {
            return episode.title.toLowerCase().contains(query) ||
                episode.description.toLowerCase().contains(query);
          }).toList();
    emit(state.copyWith(query: event.query, episodes: filtered));
  }
}
