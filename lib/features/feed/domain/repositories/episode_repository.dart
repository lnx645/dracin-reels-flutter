import '../entities/episode.dart';

/// Kontrak pengambilan dan perubahan episode. Implementasi hidup di data/.
/// [getEpisodes] asinkron (API) dan melempar ApiException bila gagal —
/// pemanggil WAJIB menampilkan error itu + tombol Coba Lagi, bukan
/// menggantinya dengan data contoh.
abstract class EpisodeRepository {
  Future<List<Episode>> getEpisodes();

  /// Satu halaman episode (lazy loading feed): episode dari series
  /// pada halaman itu + total series nyata dari meta API.
  Future<EpisodePage> getEpisodesPage({
    required int page,
    required int limit,
  });

  /// Daftar terakhir yang berhasil dimuat (kosong bila belum pernah
  /// berhasil). Dipakai UI untuk toggle optimistis tanpa memuat ulang.
  List<Episode> get cachedEpisodes;

  /// Balik status suka lokal (optimistis, dibatalkan UI bila sinkronisasi
  /// API gagal). Mengembalikan episode baru, atau null bila id tak ada.
  Episode? toggleLike(String id);

  Episode? toggleBookmark(String id);
}

/// Satu halaman episode feed + total series nyata (untuk hasMore).
class EpisodePage {
  const EpisodePage({required this.episodes, required this.totalSeries});

  final List<Episode> episodes;
  final int totalSeries;
}
