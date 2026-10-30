import '../entities/episode.dart';
import '../repositories/episode_repository.dart';

class GetEpisodes {
  const GetEpisodes(this._repository);

  final EpisodeRepository _repository;

  Future<List<Episode>> call() => _repository.getEpisodes();
}

class ToggleLike {
  const ToggleLike(this._repository);

  final EpisodeRepository _repository;

  Episode? call(String id) => _repository.toggleLike(id);
}

class ToggleBookmark {
  const ToggleBookmark(this._repository);

  final EpisodeRepository _repository;

  Episode? call(String id) => _repository.toggleBookmark(id);
}
