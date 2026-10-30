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
    this.averageRating,
    this.ratingCount = 0,
    this.userRating,
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

  /// Rating rata-rata NYATA dari endpoint rating (backend 5bc71fe):
  /// `average_rating` pada GET /series dan /series/{id}, serta
  /// GET /series/{id}/ratings. NULL = belum ada yang menilai — BUKAN
  /// 0, dan UI tidak boleh menampilkan 0 bintang sebagai data.
  /// Kolom lama `rating` TIDAK diubah backend dan tidak lagi dipakai
  /// sebagai sumber tampilan rating (hanya fallback urutan bila
  /// averageRating null dan nilainya > 0).
  final double? averageRating;

  /// Jumlah penilai dari `rating_count` (0 = belum ada yang menilai).
  final int ratingCount;

  /// Bintang milik pengguna login dari `user_rating` (hanya bila login
  /// + pernah menilai; null bila anonim/belum menilai). Bintang user
  /// HANYA ditampilkan bila login — nilai ini sendiri sudah menjamin
  /// itu karena backend hanya mengembalikannya untuk token login.
  final int? userRating;

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
    final averageRaw = json['average_rating'];
    final userRatingRaw = json['user_rating'];
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
      averageRating:
          averageRaw is num ? averageRaw.toDouble() : null,
      ratingCount: json['rating_count'] is int
          ? json['rating_count'] as int
          : 0,
      userRating: userRatingRaw is int ? userRatingRaw : null,
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

/// Satu halaman series + total nyata (untuk lazy loading).
class SeriesPage {
  const SeriesPage({required this.series, required this.total});

  final List<Series> series;
  final int total;
}

/// Ringkasan rating series dari API (dihitung server, bukan karangan).
/// [average] null = belum ada yang menilai (bukan nilai 0).
/// [userStars] null = pemanggil belum menilai / belum masuk.
class SeriesRatingSummary {
  const SeriesRatingSummary({
    required this.average,
    required this.count,
    this.userStars,
  });

  final double? average;
  final int count;
  final int? userStars;

  factory SeriesRatingSummary.fromJson(Map<String, dynamic> json) {
    final average = json['average_rating'];
    final userStars = json['user_stars'];
    return SeriesRatingSummary(
      average: average is num ? average.toDouble() : null,
      count: json['rating_count'] is int ? json['rating_count'] as int : 0,
      userStars: userStars is int ? userStars : null,
    );
  }
}
