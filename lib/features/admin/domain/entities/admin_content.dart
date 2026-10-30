/// Formulir series untuk admin (tambah/edit). Lapisan domain murni.
class AdminSeriesForm {
  const AdminSeriesForm({
    this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.genreIds,
    required this.freeEpisodeCount,
    required this.status,
  });

  final int? id;
  final String title;
  final String description;
  final String coverUrl;
  final List<int> genreIds;
  final int freeEpisodeCount;
  final String status;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'cover_url': coverUrl,
      'genre_ids': genreIds,
      'free_episode_count': freeEpisodeCount,
      'status': status,
    };
  }
}

/// Formulir episode untuk admin. Video punya DUA sumber (sesuai kontrak
/// backend): upload file ATAU `videoUrl` eksternal http(s). Bila keduanya
/// diisi, upload yang menang (backend menimpa video_url).
class AdminEpisodeForm {
  const AdminEpisodeForm({
    this.id,
    required this.seriesId,
    required this.number,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.coinPrice,
    required this.status,
  });

  final int? id;
  final int seriesId;
  final int number;
  final String title;
  final String description;
  final String videoUrl;
  final int coinPrice;
  final String status;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'series_id': seriesId,
      'number': number,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'coin_price': coinPrice,
      'status': status,
    };
  }
}
