import 'entities/episode.dart';

/// Kontrak pengambilan dan perubahan episode. Implementasi hidup di data/.
abstract class EpisodeRepository {
  List<Episode> getEpisodes();

  Episode? toggleLike(String id);

  Episode? toggleBookmark(String id);
}
