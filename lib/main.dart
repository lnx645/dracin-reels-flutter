import 'package:flutter/material.dart';

import 'app.dart';
import 'features/feed/data/datasources/sample_episode_datasource.dart';
import 'features/feed/data/repositories/episode_repository_impl.dart';
import 'features/feed/domain/repositories/episode_repository.dart';

void main() {
  final EpisodeRepository repository =
      EpisodeRepositoryImpl(SampleEpisodeDataSource());
  runApp(DracinApp(repository: repository));
}
