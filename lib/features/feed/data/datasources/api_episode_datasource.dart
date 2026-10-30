import '../../../../core/api/api_client.dart';
import '../../domain/entities/episode.dart';

/// Sumber episode dari API backend (publik, bisa anonim).
///
/// Alur: daftar series → detail tiap series (berisi episode).
/// TIDAK ADA data sampel di sini: bila API gagal, exception diteruskan
/// (UI menampilkan error asli + tombol Coba Lagi, bukan kartu palsu).
/// Bila API mengembalikan kosong, hasilnya daftar kosong (UI menampilkan
/// empty state jujur).
///
/// Catatan jujur soal hitungan: API tidak menyediakan jumlah suka/
/// komentar/bagikan per episode, jadi ketiganya 0 (bukan angka karangan).
/// Tagar diturunkan dari genre series di API. Gradasi hanya dekorasi
/// visual placeholder (bukan data) dan dipilih deterministik dari nomor.
class ApiEpisodeDataSource {
  ApiEpisodeDataSource(this._api);

  final ApiClient _api;

  static const List<List<int>> _gradients = <List<int>>[
    <int>[0xFF3B1D5A, 0xFF0B0E14],
    <int>[0xFF7A2E1F, 0xFF0B0E14],
    <int>[0xFF1F4A5A, 0xFF0B0E14],
    <int>[0xFF2E5A2E, 0xFF0B0E14],
    <int>[0xFF5A1F3B, 0xFF0B0E14],
  ];

  Future<List<Episode>> fetchEpisodes() async {
    final dynamic data = await _api.getJson('/series');
    if (data is! List) {
      throw const ApiException('Format daftar series tidak dikenali.');
    }
    final List<Episode> episodes = <Episode>[];
    for (final dynamic item in data.whereType<Map<String, dynamic>>()) {
      final int seriesId = item['id'] is int ? item['id'] as int : 0;
      if (seriesId == 0) {
        continue;
      }
      final List<String> hashtags = _hashtagsOf(item);
      final int seriesCreatedAtMs = _createdAtMsOf(item);
      final List<Map<String, dynamic>> rawEpisodes =
          await _fetchSeriesEpisodes(seriesId);
      for (final Map<String, dynamic> raw in rawEpisodes) {
        final int apiId = raw['id'] is int ? raw['id'] as int : 0;
        final int number = raw['number'] is int ? raw['number'] as int : 0;
        episodes.add(
          Episode(
            id: 's$seriesId' 'e$apiId',
            title: raw['title'] is String ? raw['title'] as String : 'Episode',
            number: number,
            description: raw['description'] is String
                ? raw['description'] as String
                : '',
            hashtags: hashtags,
            likes: 0,
            comments: 0,
            shares: 0,
            gradient: _gradients[number % _gradients.length],
            seriesId: seriesId,
            apiEpisodeId: apiId,
            videoUrl: raw['video_url'] is String
                ? raw['video_url'] as String
                : '',
            locked: raw['locked'] is bool ? raw['locked'] as bool : false,
            coinPrice: raw['coin_price'] is int
                ? raw['coin_price'] as int
                : 0,
            seriesCreatedAtMs: seriesCreatedAtMs,
          ),
        );
      }
    }
    episodes.sort((a, b) {
      final bySeries = a.seriesId.compareTo(b.seriesId);
      if (bySeries != 0) {
        return bySeries;
      }
      return a.number.compareTo(b.number);
    });
    return episodes;
  }

  int _createdAtMsOf(Map<String, dynamic> seriesJson) {
    final dynamic raw = seriesJson['created_at'];
    if (raw is! String) {
      return 0;
    }
    return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
  }

  List<String> _hashtagsOf(Map<String, dynamic> seriesJson) {
    final dynamic genres = seriesJson['genres'];
    if (genres is! List) {
      return const <String>[];
    }
    return genres
        .whereType<Map<String, dynamic>>()
        .map((genre) => genre['name'])
        .whereType<String>()
        .map((name) => '#${name.replaceAll(' ', '')}')
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchSeriesEpisodes(
    int seriesId,
  ) async {
    final dynamic detail = await _api.getJson('/series/$seriesId');
    if (detail is Map<String, dynamic>) {
      final dynamic episodes = detail['episodes'];
      if (episodes is List) {
        return episodes.whereType<Map<String, dynamic>>().toList();
      }
    }
    final dynamic list = await _api.getJson('/series/$seriesId/episodes');
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    throw const ApiException('Format episode series tidak dikenali.');
  }
}
