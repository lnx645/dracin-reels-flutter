/// Entitas episode. Lapisan domain murni: tanpa dependensi Flutter UI.
/// Gradasi disimpan sebagai nilai ARGB int agar domain tidak mengenal [Color].
class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.number,
    required this.description,
    required this.hashtags,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.gradient,
    this.seriesId = 0,
    this.apiEpisodeId = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.videoUrl = '',
    this.locked = false,
    this.coinPrice = 0,
    this.seriesCreatedAtMs = 0,
  });

  /// Id unik gabungan: `s{seriesId}e{apiEpisodeId}` (dari API).
  final String id;
  final String title;
  final int number;
  final String description;
  final List<String> hashtags;
  final int likes;
  final int comments;
  final int shares;

  /// Dua warna ARGB untuk gradasi placeholder area video.
  final List<int> gradient;

  /// Id series API pemilik episode ini (0 = tidak diketahui).
  final int seriesId;

  /// Id episode di API (0 = tidak diketahui; dipakai komentar/suka/
  /// unlock/progress — bukan nomor urut dalam series).
  final int apiEpisodeId;

  final bool isLiked;
  final bool isBookmarked;

  /// `video_url` episode dari detail API ('' bila tidak ada — kartu
  /// tidak memutar apa-apa, tanpa ikon play palsu).
  final String videoUrl;

  /// Terkunci menurut API (bukan dari feed): tidak pernah autoplay.
  final bool locked;

  /// Harga koin episode (untuk overlay kunci, sama seperti Player).
  final int coinPrice;

  /// Milidetik epoch `created_at` series (0 = tidak diketahui) —
  /// urutan default feed = terbaru dulu.
  final int seriesCreatedAtMs;

  Episode copyWith({bool? isLiked, bool? isBookmarked}) {
    return Episode(
      id: id,
      title: title,
      number: number,
      description: description,
      hashtags: hashtags,
      likes: isLiked != null && isLiked != this.isLiked
          ? likes + (isLiked ? 1 : -1)
          : likes,
      comments: comments,
      shares: shares,
      gradient: gradient,
      seriesId: seriesId,
      apiEpisodeId: apiEpisodeId,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      videoUrl: videoUrl,
      locked: locked,
      coinPrice: coinPrice,
      seriesCreatedAtMs: seriesCreatedAtMs,
    );
  }
}
