import '../../../../core/api/api_client.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';

/// Repository series: HANYA API. Tidak ada sampel/fallback lokal:
/// bila API gagal, ApiException diteruskan (UI menampilkan error asli
/// + tombol Coba Lagi); bila API mengembalikan kosong, hasilnya kosong
/// (UI menampilkan empty state jujur).
class SeriesRepositoryImpl implements SeriesRepository {
  SeriesRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Series>> getSeries({String? genreSlug, String? query}) async {
    final params = <String, String>{};
    if (genreSlug != null && genreSlug.isNotEmpty) {
      params['genre'] = genreSlug;
    }
    final queryString = params.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
    final path =
        queryString.isEmpty ? '/series' : '/series?$queryString';
    final data = await _api.getJson(path);
    if (data is! List) {
      throw const ApiException('Format daftar series tidak dikenali.');
    }
    var list = data
        .whereType<Map<String, dynamic>>()
        .map(Series.fromJson)
        .toList();
    if (query != null && query.trim().isNotEmpty) {
      final needle = query.trim().toLowerCase();
      list = list
          .where(
            (series) =>
                series.title.toLowerCase().contains(needle) ||
                series.description.toLowerCase().contains(needle),
          )
          .toList();
    }
    return list;
  }

  @override
  Future<List<Genre>> getGenres() async {
    final data = await _api.getJson('/genres');
    if (data is! List) {
      throw const ApiException('Format daftar genre tidak dikenali.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(Genre.fromJson)
        .toList();
  }

  @override
  Future<SeriesDetail> getSeriesDetail(int seriesId) async {
    final data = await _api.getJson('/series/$seriesId');
    if (data is Map<String, dynamic>) {
      final seriesJson = data['series'];
      final episodesJson = data['episodes'];
      if (seriesJson is Map<String, dynamic> && episodesJson is List) {
        return SeriesDetail(
          series: Series.fromJson(seriesJson),
          episodes: episodesJson
              .whereType<Map<String, dynamic>>()
              .map(SeriesEpisode.fromJson)
              .toList(),
        );
      }
    }
    final episodesData = await _api.getJson('/series/$seriesId/episodes');
    if (episodesData is List) {
      final seriesList = await getSeries();
      final series = seriesList.firstWhere(
        (item) => item.id == seriesId,
        orElse: () =>
            throw const ApiException('Series tidak ditemukan.'),
      );
      return SeriesDetail(
        series: series,
        episodes: episodesData
            .whereType<Map<String, dynamic>>()
            .map(SeriesEpisode.fromJson)
            .toList(),
      );
    }
    throw const ApiException('Format detail series tidak dikenali.');
  }
}
