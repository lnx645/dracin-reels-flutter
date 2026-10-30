import 'package:flutter_bloc/flutter_bloc.dart';

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
  const ExploreState({this.query = '', this.episodes = const <Episode>[]});

  final String query;
  final List<Episode> episodes;

  ExploreState copyWith({String? query, List<Episode>? episodes}) {
    return ExploreState(
      query: query ?? this.query,
      episodes: episodes ?? this.episodes,
    );
  }
}

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  ExploreBloc(this._repository) : super(const ExploreState()) {
    on<ExploreStarted>(_onStarted);
    on<ExploreQueryChanged>(_onQueryChanged);
  }

  final EpisodeRepository _repository;

  void _onStarted(ExploreStarted event, Emitter<ExploreState> emit) {
    emit(state.copyWith(episodes: _repository.getEpisodes()));
  }

  void _onQueryChanged(ExploreQueryChanged event, Emitter<ExploreState> emit) {
    final query = event.query.trim().toLowerCase();
    final all = _repository.getEpisodes();
    final filtered = query.isEmpty
        ? all
        : all.where((episode) {
            return episode.title.toLowerCase().contains(query) ||
                episode.description.toLowerCase().contains(query);
          }).toList();
    emit(state.copyWith(query: event.query, episodes: filtered));
  }
}
