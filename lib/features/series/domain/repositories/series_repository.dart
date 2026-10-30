import '../entities/series.dart';

/// Kontrak repository series: HANYA API. Gagal = ApiException
/// diteruskan (UI menampilkan error asli + Coba Lagi); kosong = daftar
/// kosong (UI menampilkan empty state jujur). Tanpa fallback sampel.
abstract class SeriesRepository {
  Future<List<Series>> getSeries({int? genreId, String? query});

  /// Satu halaman series + total nyata (untuk lazy loading Jelajahi
  /// dan Beranda). Filter genre/query tetap diterapkan sisi server
  /// bila didukung, lalu sisi klien seperti [getSeries].
  Future<SeriesPage> getSeriesPage({
    int? genreId,
    String? query,
    required int page,
    required int limit,
  });

  Future<List<Genre>> getGenres();
  Future<SeriesDetail> getSeriesDetail(int seriesId);

  /// Ringkasan rating series (rata-rata + jumlah + bintang pengguna).
  /// Endpoint backend: GET /series/{id}/ratings.
  Future<SeriesRatingSummary> getRating(int seriesId);

  /// Beri/ubah rating 1-5 bintang (butuh login).
  /// Endpoint backend: POST /series/{id}/ratings {stars}.
  Future<SeriesRatingSummary> rateSeries(int seriesId, int stars);
}
