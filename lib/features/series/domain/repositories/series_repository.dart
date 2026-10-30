import '../entities/series.dart';

/// Kontrak repository series: HANYA API. Gagal = ApiException
/// diteruskan (UI menampilkan error asli + Coba Lagi); kosong = daftar
/// kosong (UI menampilkan empty state jujur). Tanpa fallback sampel.
abstract class SeriesRepository {
  Future<List<Series>> getSeries({int? genreId, String? query});
  Future<List<Genre>> getGenres();
  Future<SeriesDetail> getSeriesDetail(int seriesId);
}
