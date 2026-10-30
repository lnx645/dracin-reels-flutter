import '../../domain/entities/episode.dart';
import '../../domain/repositories/episode_repository.dart';
import '../datasources/sample_episode_datasource.dart';

/// Implementasi repository di memori, dari datasource sampel.
/// Nanti diganti implementasi API tanpa mengubah domain maupun UI.
class EpisodeRepositoryImpl implements EpisodeRepository {
  EpisodeRepositoryImpl(this._datasource)
      : _episodes = List<Episode>.of(_datasource.getSampleEpisodes());

  final SampleEpisodeDataSource _datasource;
  final List<Episode> _episodes;

  @override
  List<Episode> getEpisodes() => List<Episode>.unmodifiable(_episodes);

  @override
  Episode? toggleLike(String id) {
    final index = _episodes.indexWhere((episode) => episode.id == id);
    if (index == -1) {
      return null;
    }
    final updated =
        _episodes[index].copyWith(isLiked: !_episodes[index].isLiked);
    _episodes[index] = updated;
    return updated;
  }

  @override
  Episode? toggleBookmark(String id) {
    final index = _episodes.indexWhere((episode) => episode.id == id);
    if (index == -1) {
      return null;
    }
    final updated = _episodes[index]
        .copyWith(isBookmarked: !_episodes[index].isBookmarked);
    _episodes[index] = updated;
    return updated;
  }
}
