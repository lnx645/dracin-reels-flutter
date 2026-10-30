import '../../../core/api/api_client.dart';
import '../../series/domain/entities/series.dart';
import '../../series/domain/repositories/series_repository.dart';

/// Repository series: API dulu, sampel lokal bila API tidak terjangkau.
/// Sampel memakai naskah orisinal Qin yang sama dengan feed (harga kunci
/// 0/0/50/80/100, 2 episode gratis — sama dengan seed API).
class SeriesRepositoryImpl implements SeriesRepository {
  SeriesRepositoryImpl(this._api);

  final ApiClient _api;

  static const List<Genre> _sampleGenres = <Genre>[
    Genre(id: 1, name: 'Romansa', slug: 'romansa'),
    Genre(id: 2, name: 'Balas Dendam', slug: 'balas-dendam'),
    Genre(id: 3, name: 'Fantasi', slug: 'fantasi'),
    Genre(id: 4, name: 'Misteri', slug: 'misteri'),
  ];

  static Series get _sampleSeries => const Series(
        id: 1,
        title: 'CINTA SANG PENGUASA QIN',
        description:
            'Kisah orisinal: seorang tabib muda yang menyamar menjadi '
            'pelayan istana demi mencari obat bagi adiknya, justru terjebak '
            'dalam perebutan takhta dan hati sang penguasa Qin.',
        coverUrl: '',
        status: 'published',
        totalEpisode: 5,
        freeEpisodeCount: 2,
        rating: 4.8,
        genres: _sampleGenres,
      );

  static List<SeriesEpisode> get _sampleEpisodes => const <SeriesEpisode>[
        SeriesEpisode(
          id: 1,
          seriesId: 1,
          number: 1,
          title: 'Hari Pertama Magang',
          description:
              'Hari pertama magang Lin Yue di lobi Qin Group berubah saat '
              'lift berhenti di lantai yang salah.',
          videoUrl: '',
          subtitleUrl: null,
          durationSeconds: 95,
          coinPrice: 0,
          status: 'published',
          thumbnailUrl: '',
          locked: false,
        ),
        SeriesEpisode(
          id: 2,
          seriesId: 1,
          number: 2,
          title: 'Foto di Balik Bingkai',
          description:
              'Di balik foto itu tertulis: Kontrak diputus, Qin Group, '
              '2015. Lin Yue mulai merangkai potongan masa lalu.',
          videoUrl: '',
          subtitleUrl: null,
          durationSeconds: 110,
          coinPrice: 0,
          status: 'published',
          thumbnailUrl: '',
          locked: false,
        ),
        SeriesEpisode(
          id: 3,
          seriesId: 1,
          number: 3,
          title: 'Pintu yang Terbuka',
          description:
              'Qin Chen berdiri di pintu. Satu pertanyaan menggantung, '
              'dan tidak ada jalan kembali.',
          videoUrl: '',
          subtitleUrl: null,
          durationSeconds: 105,
          coinPrice: 50,
          status: 'published',
          thumbnailUrl: '',
          locked: true,
        ),
        SeriesEpisode(
          id: 4,
          seriesId: 1,
          number: 4,
          title: 'Rahasia Lin Wei',
          description:
              'Ayah Lin Yue dijebak orang dalam Qin Group. Kebenaran mulai '
              'terkuak, satu per satu.',
          videoUrl: '',
          subtitleUrl: null,
          durationSeconds: 120,
          coinPrice: 80,
          status: 'published',
          thumbnailUrl: '',
          locked: true,
        ),
        SeriesEpisode(
          id: 5,
          seriesId: 1,
          number: 5,
          title: 'Pilihan Qin Chen',
          description:
              'Pewaris Qin Group harus memilih antara keluarga dan '
              'kebenaran. Pilihan itu mengubah segalanya.',
          videoUrl: '',
          subtitleUrl: null,
          durationSeconds: 135,
          coinPrice: 100,
          status: 'published',
          thumbnailUrl: '',
          locked: true,
        ),
      ];

  List<Series> _filterSample({String? genreSlug, String? query}) {
    var list = <Series>[_sampleSeries];
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
    if (genreSlug != null && genreSlug.isNotEmpty) {
      list = list
          .where(
            (series) =>
                series.genres.any((genre) => genre.slug == genreSlug),
          )
          .toList();
    }
    return list;
  }

  @override
  Future<List<Series>> getSeries({String? genreSlug, String? query}) async {
    try {
      final params = <String, String>{};
      if (genreSlug != null && genreSlug.isNotEmpty) {
        params['genre'] = genreSlug;
      }
      final queryString = params.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('&');
      final path = queryString.isEmpty
          ? '/series'
          : '/series?$queryString';
      final data = await _api.getJson(path);
      if (data is! List) {
        return _filterSample(genreSlug: genreSlug, query: query);
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
    } on ApiException {
      return _filterSample(genreSlug: genreSlug, query: query);
    }
  }

  @override
  Future<List<Genre>> getGenres() async {
    try {
      final data = await _api.getJson('/genres');
      if (data is! List) {
        return _sampleGenres;
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(Genre.fromJson)
          .toList();
    } on ApiException {
      return _sampleGenres;
    }
  }

  @override
  Future<SeriesDetail> getSeriesDetail(int seriesId) async {
    try {
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
          orElse: () => _sampleSeries,
        );
        return SeriesDetail(
          series: series,
          episodes: episodesData
              .whereType<Map<String, dynamic>>()
              .map(SeriesEpisode.fromJson)
              .toList(),
        );
      }
      return SeriesDetail(
        series: _sampleSeries,
        episodes: _sampleEpisodes,
      );
    } on ApiException {
      return SeriesDetail(series: _sampleSeries, episodes: _sampleEpisodes);
    }
  }
}
