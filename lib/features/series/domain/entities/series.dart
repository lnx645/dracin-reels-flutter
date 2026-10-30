/// Entitas series (drama) dari API. Lapisan domain murni.
class Series {
  const Series({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.status,
    required this.totalEpisode,
    required this.freeEpisodeCount,
    required this.rating,
    required this.genres,
    this.tagline = '',
    this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final String status;
  final int totalEpisode;
  final int freeEpisodeCount;
  final double rating;
  final List<Genre> genres;

  /// Tanggal series dibuat (dari `created_at` API). Null bila backend
  /// tidak mengembalikannya — urutan "Baru Tayang" menaruh yang tanpa
  /// tanggal di akhir, bukan mengarang tanggal.
  final DateTime? createdAt;

  /// Tagline dari API (kontrak baru). Bila backend belum mengembalikan
  /// tagline, nilainya '' — UI menyembunyikan baris tagline, bukan
  /// menampilkan teks contoh.
  final String tagline;

  factory Series.fromJson(Map<String, dynamic> json) {
    final genresJson = json['genres'];
    final genres = <Genre>[];
    if (genresJson is List) {
      for (final item in genresJson) {
        if (item is Map<String, dynamic>) {
          genres.add(Genre.fromJson(item));
        }
      }
    }
    final rating = json['rating'];
    final createdRaw = json['created_at'];
    return Series(
      id: json['id'] is int ? json['id'] as int : 0,
      title: json['title'] is String ? json['title'] as String : '',
      description: json['description'] is String
          ? json['description'] as String
          : '',
      coverUrl: json['cover_url'] is String
          ? json['cover_url'] as String
          : '',
      status: json['status'] is String ? json['status'] as String : '',
      tagline: json['tagline'] is String ? json['tagline'] as String : '',
      totalEpisode: json['total_episode'] is int
          ? json['total_episode'] as int
          : 0,
      freeEpisodeCount: json['free_episode_count'] is int
          ? json['free_episode_count'] as int
          : 0,
      rating: rating is num ? rating.toDouble() : 0,
      genres: genres,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw)
          : null,
    );
  }
}

/// Satu episode milik series (data API).
class SeriesEpisode {
  const SeriesEpisode({
    required this.id,
    required this.seriesId,
    required this.number,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.hlsUrl = '',
    required this.subtitleUrl,
    required this.durationSeconds,
    required this.coinPrice,
    required this.status,
    required this.thumbnailUrl,
    required this.locked,
  });

  final int id;
  final int seriesId;
  final int number;
  final String title;
  final String description;
  final String videoUrl;

  /// `hls_url` episode dari API ('' bila backend belum menyediakannya).
  /// Bila ada, pemutar MEMAKAI ini dulu (ExoPlayer ABR HLS naik-turun
  /// otomatis mengikuti kecepatan internet — jawaban utama untuk
  /// internet jelek); MP4 progresif hanya fallback.
  final String hlsUrl;

  final String? subtitleUrl;
  final int durationSeconds;
  final int coinPrice;
  final String status;
  final String thumbnailUrl;
  final bool locked;

  bool get isFree => coinPrice <= 0 || !locked;

  factory SeriesEpisode.fromJson(Map<String, dynamic> json) {
    final subtitle = json['subtitle_url'];
    return SeriesEpisode(
      id: json['id'] is int ? json['id'] as int : 0,
      seriesId: json['series_id'] is int ? json['series_id'] as int : 0,
      number: json['number'] is int ? json['number'] as int : 0,
      title: json['title'] is String ? json['title'] as String : '',
      description: json['description'] is String
          ? json['description'] as String
          : '',
      videoUrl:
          json['video_url'] is String ? json['video_url'] as String : '',
      hlsUrl: json['hls_url'] is String ? json['hls_url'] as String : '',
      subtitleUrl: subtitle is String ? subtitle : null,
      durationSeconds: json['duration_seconds'] is int
          ? json['duration_seconds'] as int
          : 0,
      coinPrice:
          json['coin_price'] is int ? json['coin_price'] as int : 0,
      status: json['status'] is String ? json['status'] as String : '',
      thumbnailUrl: json['thumbnail_url'] is String
          ? json['thumbnail_url'] as String
          : '',
      locked: json['locked'] is bool ? json['locked'] as bool : false,
    );
  }

  SeriesEpisode copyWith({bool? locked}) {
    return SeriesEpisode(
      id: id,
      seriesId: seriesId,
      number: number,
      title: title,
      description: description,
      videoUrl: videoUrl,
      hlsUrl: hlsUrl,
      subtitleUrl: subtitleUrl,
      durationSeconds: durationSeconds,
      coinPrice: coinPrice,
      status: status,
      thumbnailUrl: thumbnailUrl,
      locked: locked ?? this.locked,
    );
  }
}

/// Genre drama.
class Genre {
  const Genre({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name'] is String ? json['name'] as String : '',
      slug: json['slug'] is String ? json['slug'] as String : '',
    );
  }
}

/// Detail series: data series + daftar episodenya.
class SeriesDetail {
  const SeriesDetail({required this.series, required this.episodes});

  final Series series;
  final List<SeriesEpisode> episodes;
}
