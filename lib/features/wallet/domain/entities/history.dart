/// Satu entri riwayat tonton. Sumber tunggal untuk "Lanjutkan Nonton"
/// di Profil dan halaman Riwayat Tonton.
class HistoryEntry {
  const HistoryEntry({
    required this.episodeId,
    required this.seriesId,
    required this.seriesTitle,
    required this.title,
    required this.number,
    required this.positionSeconds,
    required this.finished,
    required this.updatedAtMs,
  });

  final int episodeId;
  final int seriesId;
  final String seriesTitle;
  final String title;
  final int number;
  final int positionSeconds;
  final bool finished;

  /// Milidetik epoch terakhir ditonton (urutan terbaru di atas).
  final int updatedAtMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'episodeId': episodeId,
      'seriesId': seriesId,
      'seriesTitle': seriesTitle,
      'title': title,
      'number': number,
      'positionSeconds': positionSeconds,
      'finished': finished,
      'updatedAtMs': updatedAtMs,
    };
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      episodeId: json['episodeId'] is int ? json['episodeId'] as int : 0,
      seriesId: json['seriesId'] is int ? json['seriesId'] as int : 0,
      seriesTitle: json['seriesTitle'] is String
          ? json['seriesTitle'] as String
          : 'Series',
      title: json['title'] is String ? json['title'] as String : 'Episode',
      number: json['number'] is int ? json['number'] as int : 0,
      positionSeconds: json['positionSeconds'] is int
          ? json['positionSeconds'] as int
          : 0,
      finished:
          json['finished'] is bool ? json['finished'] as bool : false,
      updatedAtMs: json['updatedAtMs'] is int
          ? json['updatedAtMs'] as int
          : 0,
    );
  }
}
