import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';

abstract class SeriesListEvent {
  const SeriesListEvent();
}

class SeriesListStarted extends SeriesListEvent {
  const SeriesListStarted();
}

class SeriesListGenreChanged extends SeriesListEvent {
  const SeriesListGenreChanged(this.genreId);

  /// Id genre dari GET /genres; null = Semua.
  final int? genreId;
}

class SeriesListQueryChanged extends SeriesListEvent {
  const SeriesListQueryChanged(this.query);

  final String query;
}

/// Urutan daftar series di Jelajahi. API belum menyediakan param urut,
/// jadi urutan diterapkan sisi klien pada data yang sudah diambil
/// (dilaporkan jujur, bukan param API).
enum SeriesSort {
  /// Urutan bawaan API.
  none,

  /// Peringkat tertinggi dulu (rating 0 = belum ada peringkat, di akhir
  /// secara alami karena 0 paling kecil).
  rating,

  /// Terbaru dulu (createdAt desc; tanpa tanggal → akhir).
  newest,
}

class SeriesListSortChanged extends SeriesListEvent {
  const SeriesListSortChanged(this.sort);

  final SeriesSort sort;
}

class SeriesListState {
  const SeriesListState({
    this.series = const <Series>[],
    this.genres = const <Genre>[],
    this.selectedGenreId,
    this.query = '',
    this.sort = SeriesSort.none,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Series> series;
  final List<Genre> genres;
  final int? selectedGenreId;
  final String query;
  final SeriesSort sort;
  final bool isLoading;

  /// Pesan error ASLI dari request API terakhir.
  final String? errorMessage;

  SeriesListState copyWith({
    List<Series>? series,
    List<Genre>? genres,
    int? selectedGenreId,
    bool clearGenre = false,
    String? query,
    SeriesSort? sort,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SeriesListState(
      series: series ?? this.series,
      genres: genres ?? this.genres,
      selectedGenreId:
          clearGenre ? null : selectedGenreId ?? this.selectedGenreId,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SeriesListBloc extends Bloc<SeriesListEvent, SeriesListState> {
  SeriesListBloc(this._repository) : super(const SeriesListState()) {
    on<SeriesListStarted>(_onStarted);
    on<SeriesListGenreChanged>(_onGenreChanged);
    on<SeriesListQueryChanged>(_onQueryChanged);
    on<SeriesListSortChanged>(_onSortChanged);
  }

  final SeriesRepository _repository;

  Future<void> _reload(Emitter<SeriesListState> emit) async {
    try {
      final list = await _repository.getSeries(
        genreId: state.selectedGenreId,
        query: state.query.isEmpty ? null : state.query,
      );
      // Urut sisi klien (API belum punya param urut). Tiebreak id
      // supaya urutan deterministis, bukan acak.
      switch (state.sort) {
        case SeriesSort.rating:
          list.sort((a, b) {
            final byRating = b.rating.compareTo(a.rating);
            return byRating != 0 ? byRating : a.id.compareTo(b.id);
          });
        case SeriesSort.newest:
          list.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;
            if (aDate == null && bDate == null) {
              return a.id.compareTo(b.id);
            }
            if (aDate == null) {
              return 1;
            }
            if (bDate == null) {
              return -1;
            }
            final byDate = bDate.compareTo(aDate);
            return byDate != 0 ? byDate : a.id.compareTo(b.id);
          });
        case SeriesSort.none:
          break;
      }
      emit(state.copyWith(series: list, isLoading: false, clearError: true));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  Future<void> _onStarted(
    SeriesListStarted event,
    Emitter<SeriesListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final genres = await _repository.getGenres();
      emit(state.copyWith(genres: genres));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
      return;
    }
    await _reload(emit);
  }

  Future<void> _onGenreChanged(
    SeriesListGenreChanged event,
    Emitter<SeriesListState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedGenreId: event.genreId,
        clearGenre: event.genreId == null,
        isLoading: true,
        clearError: true,
      ),
    );
    await _reload(emit);
  }

  Future<void> _onQueryChanged(
    SeriesListQueryChanged event,
    Emitter<SeriesListState> emit,
  ) async {
    emit(state.copyWith(query: event.query, isLoading: true, clearError: true));
    await _reload(emit);
  }

  Future<void> _onSortChanged(
    SeriesListSortChanged event,
    Emitter<SeriesListState> emit,
  ) async {
    // Reload lalu urut sisi klien di _reload — konsisten dengan
    // genre/kata kunci (data selalu segar dari API).
    emit(state.copyWith(sort: event.sort, isLoading: true, clearError: true));
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
    bool clearError = false,
  }) {
    return SeriesDetailState(
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
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
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final detail = await _repository.getSeriesDetail(event.seriesId);
      emit(state.copyWith(detail: detail, isLoading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }
}
