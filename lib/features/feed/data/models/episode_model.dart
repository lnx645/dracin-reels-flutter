import '../../domain/entities/episode.dart';

/// Model data episode. Saat ini diisi dari datasource sampel; bentuk
/// fromJson/toJson disiapkan agar nanti bisa diganti sumber API tanpa
/// mengubah entitas domain.
class EpisodeModel extends Episode {
  const EpisodeModel({
    required super.id,
    required super.title,
    required super.number,
    required super.description,
    required super.hashtags,
    required super.likes,
    required super.comments,
    required super.shares,
    required super.gradient,
    super.isLiked,
    super.isBookmarked,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: json['id'] as String,
      title: json['title'] as String,
      number: json['number'] as int,
      description: json['description'] as String,
      hashtags: (json['hashtags'] as List<dynamic>).cast<String>(),
      likes: json['likes'] as int,
      comments: json['comments'] as int,
      shares: json['shares'] as int,
      gradient: (json['gradient'] as List<dynamic>).cast<int>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'number': number,
      'description': description,
      'hashtags': hashtags,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'gradient': gradient,
    };
  }
}
