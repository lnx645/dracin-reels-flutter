import '../entities/series.dart';

/// Kontrak repository series: API bila terjangkau, sampel lokal bila tidak.
abstract class SeriesRepository {
  Future<List<Series>> getSeries({String? genreSlug, String? query});
  Future<List<Genre>> getGenres();
  Future<SeriesDetail> getSeriesDetail(int seriesId);
}
