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
  Future<List<Series>> getSeries({int? genreId, String? query}) async {
    final params = <String, String>{};
    if (genreId != null) {
      params['genre_id'] = '$genreId';
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
    // Fallback lokal: bila backend belum mendukung filter genre_id dan
    // mengembalikan semua series, saring dari array genres series —
    // TAPI hanya bila respons memang membawa data genre (minimal satu
    // series punya genres). Bila tidak ada data genre sama sekali
    // (backend belum menyerilaisasi genres), jangan mengosongkan daftar:
    // percayakan hasil API apa adanya daripada menampilkan list kosong
    // yang menyesatkan.
    if (genreId != null && list.any((s) => s.genres.isNotEmpty)) {
      list = list
          .where(
            (series) => series.genres.any((genre) => genre.id == genreId),
          )
          .toList();
    }
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
