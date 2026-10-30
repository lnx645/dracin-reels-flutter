import '../../domain/entities/episode.dart';
import '../../domain/repositories/episode_repository.dart';
import '../datasources/api_episode_datasource.dart';

/// Implementasi repository dari API. Daftar episode dimuat sekali lalu
/// disimpan di memori untuk status suka/simpan sesi ini (aksi pengguna
/// sendiri, bukan data contoh). Muat ulang selalu dari API.
class EpisodeRepositoryImpl implements EpisodeRepository {
  EpisodeRepositoryImpl(this._datasource);

  final ApiEpisodeDataSource _datasource;
  List<Episode> _episodes = <Episode>[];

  @override
  Future<List<Episode>> getEpisodes() async {
    final List<Episode> fresh = await _datasource.fetchEpisodes();
    final Map<String, Episode> kept = <String, Episode>{
      for (final episode in _episodes) episode.id: episode,
    };
    _episodes = fresh.map((episode) {
      final Episode? old = kept[episode.id];
      if (old == null) {
        return episode;
      }
      return episode.copyWith(
        isLiked: old.isLiked,
        isBookmarked: old.isBookmarked,
      );
    }).toList();
    return List<Episode>.unmodifiable(_episodes);
  }

  @override
  List<Episode> get cachedEpisodes => List<Episode>.unmodifiable(_episodes);

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
