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

/// Muat halaman series berikutnya (lazy Jelajahi). Diabaikan bila
/// sedang memuat / sudah habis.
class SeriesListMoreRequested extends SeriesListEvent {
  const SeriesListMoreRequested();
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
    this.isLoadingMore = false,
    this.page = 1,
    this.total = 0,
    this.errorMessage,
  });

  final List<Series> series;
  final List<Genre> genres;
  final int? selectedGenreId;
  final String query;
  final SeriesSort sort;
  final bool isLoading;
  final bool isLoadingMore;
  final int page;
  final int total;

  /// Masih ada halaman berikut (halaman * limit < total meta).
  bool get hasMore => total > 0 && page * _pageSize < total;

  static const int _pageSize = 20;

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
    bool? isLoadingMore,
    int? page,
    int? total,
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
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      total: total ?? this.total,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SeriesListBloc extends Bloc<SeriesListEvent, SeriesListState> {
  SeriesListBloc(this._repository) : super(const SeriesListState()) {
    on<SeriesListStarted>(_onStarted);
    on<SeriesListMoreRequested>(_onMore);
    on<SeriesListGenreChanged>(_onGenreChanged);
    on<SeriesListQueryChanged>(_onQueryChanged);
    on<SeriesListSortChanged>(_onSortChanged);
  }

  final SeriesRepository _repository;

  /// Urut sisi klien (API belum punya param urut). Tiebreak id
  /// supaya urutan deterministis, bukan acak.
  /// Peringkat memakai rating EFEKTIF: average_rating nyata dulu;
  /// bila null, kolom lama `rating` bila > 0; bila keduanya kosong,
  /// series dianggap belum berperingkat dan ditaruh PALING AKHIR
  /// (bukan 0 yang disamakan dengan berperingkat rendah).
  static double? _effectiveRating(Series series) {
    if (series.averageRating != null) {
      return series.averageRating;
    }
    if (series.rating > 0) {
      return series.rating;
    }
    return null;
  }

  List<Series> _sorted(List<Series> list, SeriesSort sort) {
    final sorted = List<Series>.from(list);
    switch (sort) {
      case SeriesSort.rating:
        sorted.sort((a, b) {
          final aRating = _effectiveRating(a);
          final bRating = _effectiveRating(b);
          if (aRating == null && bRating == null) {
            return a.id.compareTo(b.id);
          }
          if (aRating == null) {
            return 1;
          }
          if (bRating == null) {
            return -1;
          }
          final byRating = bRating.compareTo(aRating);
          return byRating != 0 ? byRating : a.id.compareTo(b.id);
        });
      case SeriesSort.newest:
        sorted.sort((a, b) {
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
    return sorted;
  }

  Future<void> _reload(Emitter<SeriesListState> emit) async {
    try {
      final result = await _repository.getSeriesPage(
        genreId: state.selectedGenreId,
        query: state.query.isEmpty ? null : state.query,
        page: 1,
        limit: SeriesListState._pageSize,
      );
      emit(
        state.copyWith(
          series: _sorted(result.series, state.sort),
          page: 1,
          total: result.total,
          isLoading: false,
          clearError: true,
        ),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  Future<void> _onMore(
    SeriesListMoreRequested event,
    Emitter<SeriesListState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getSeriesPage(
        genreId: state.selectedGenreId,
        query: state.query.isEmpty ? null : state.query,
        page: state.page + 1,
        limit: SeriesListState._pageSize,
      );
      final seen = state.series.map((s) => s.id).toSet();
      final merged = <Series>[
        ...state.series,
        ...result.series.where((s) => seen.add(s.id)),
      ];
      emit(
        state.copyWith(
          series: _sorted(merged, state.sort),
          page: state.page + 1,
          total: result.total,
          isLoadingMore: false,
        ),
      );
    } on ApiException {
      // Gagal halaman berikut = daftar lama tetap tampil.
      emit(state.copyWith(isLoadingMore: false));
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
