import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';

abstract class SeriesListEvent {
  const SeriesListEvent();
}

class SeriesListStarted extends SeriesListEvent {
  const SeriesListStarted();
}

class SeriesListGenreChanged extends SeriesListEvent {
  const SeriesListGenreChanged(this.slug);

  final String? slug;
}

class SeriesListQueryChanged extends SeriesListEvent {
  const SeriesListQueryChanged(this.query);

  final String query;
}

class SeriesListState {
  const SeriesListState({
    this.series = const <Series>[],
    this.genres = const <Genre>[],
    this.selectedGenre,
    this.query = '',
    this.isLoading = false,
  });

  final List<Series> series;
  final List<Genre> genres;
  final String? selectedGenre;
  final String query;
  final bool isLoading;

  SeriesListState copyWith({
    List<Series>? series,
    List<Genre>? genres,
    String? selectedGenre,
    bool clearGenre = false,
    String? query,
    bool? isLoading,
  }) {
    return SeriesListState(
      series: series ?? this.series,
      genres: genres ?? this.genres,
      selectedGenre: clearGenre ? null : selectedGenre ?? this.selectedGenre,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SeriesListBloc extends Bloc<SeriesListEvent, SeriesListState> {
  SeriesListBloc(this._repository) : super(const SeriesListState()) {
    on<SeriesListStarted>(_onStarted);
    on<SeriesListGenreChanged>(_onGenreChanged);
    on<SeriesListQueryChanged>(_onQueryChanged);
  }

  final SeriesRepository _repository;

  Future<void> _reload(Emitter<SeriesListState> emit) async {
    final list = await _repository.getSeries(
      genreSlug: state.selectedGenre,
      query: state.query.isEmpty ? null : state.query,
    );
    emit(state.copyWith(series: list, isLoading: false));
  }

  Future<void> _onStarted(
    SeriesListStarted event,
    Emitter<SeriesListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final genres = await _repository.getGenres();
    emit(state.copyWith(genres: genres));
    await _reload(emit);
  }

  Future<void> _onGenreChanged(
    SeriesListGenreChanged event,
    Emitter<SeriesListState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedGenre: event.slug,
        clearGenre: event.slug == null,
        isLoading: true,
      ),
    );
    await _reload(emit);
  }

  Future<void> _onQueryChanged(
    SeriesListQueryChanged event,
    Emitter<SeriesListState> emit,
  ) async {
    emit(state.copyWith(query: event.query, isLoading: true));
    await _reload(emit);
  }
}

abstract class SeriesDetailEvent {
  const SeriesDetailEvent();
}

class SeriesDetailStarted extends SeriesDetailEvent {
  const SeriesDetailStarted(this.seriesId);

  final int seriesId;
}

class SeriesDetailState {
  const SeriesDetailState({
    this.detail,
    this.isLoading = false,
    this.errorMessage,
  });

  final SeriesDetail? detail;
  final bool isLoading;
  final String? errorMessage;

  SeriesDetailState copyWith({
    SeriesDetail? detail,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SeriesDetailState(
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SeriesDetailBloc extends Bloc<SeriesDetailEvent, SeriesDetailState> {
  SeriesDetailBloc(this._repository)
      : super(const SeriesDetailState()) {
    on<SeriesDetailStarted>(_onStarted);
  }

  final SeriesRepository _repository;

  Future<void> _onStarted(
    SeriesDetailStarted event,
    Emitter<SeriesDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final detail = await _repository.getSeriesDetail(event.seriesId);
    emit(state.copyWith(detail: detail, isLoading: false));
  }
}
