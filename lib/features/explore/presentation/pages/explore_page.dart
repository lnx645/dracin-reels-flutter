import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/entities/episode.dart';
import '../../../feed/domain/repositories/episode_repository.dart';
import '../../../home/presentation/widgets/series_card.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import '../../../series/presentation/pages/series_detail_page.dart';
import '../bloc/explore_bloc.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExploreBloc(
        context.read<EpisodeRepository>(),
      )..add(const ExploreStarted()),
      child: ExploreView(onOpenEpisode: onOpenEpisode),
    );
  }
}

class ExploreView extends StatelessWidget {
  const ExploreView({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Text('Jelajahi', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Cari judul drama atau episode.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => context
                  .read<ExploreBloc>()
                  .add(ExploreQueryChanged(value)),
              decoration: const InputDecoration(
                hintText: 'Cari judul drama atau episode...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Text('Series', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: BlocProvider(
                create: (_) => SeriesListBloc(
                  context.read<SeriesRepository>(),
                )..add(const SeriesListStarted()),
                child: BlocBuilder<SeriesListBloc, SeriesListState>(
                  builder: (context, seriesState) {
                    if (seriesState.errorMessage != null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              seriesState.errorMessage!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => context
                                  .read<SeriesListBloc>()
                                  .add(const SeriesListStarted()),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (seriesState.isLoading &&
                        seriesState.series.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (seriesState.series.isEmpty) {
                      return const Center(
                        child: Text('Belum ada series.'),
                      );
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: seriesState.series.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final series = seriesState.series[index];
                        return SizedBox(
                          width: 130,
                          child: SeriesMiniCard(
                            series: series,
                            onOpen: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SeriesDetailPage(
                                    seriesId: series.id,
                                    onOpenEpisode: onOpenEpisode,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Episode', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<ExploreBloc, ExploreState>(
                builder: (context, state) {
                  if (state.errorMessage != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.cloud_off, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context
                                  .read<ExploreBloc>()
                                  .add(const ExploreStarted()),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (state.episodes.isEmpty) {
                    return const Center(
                      child: Text('Tidak ada episode yang cocok.'),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: state.episodes.length,
                    itemBuilder: (context, index) {
                      final episode = state.episodes[index];
                      return _ExploreCard(
                        episode: episode,
                        onOpen: () => onOpenEpisode(episode.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.episode, required this.onOpen});

  final Episode episode;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 110,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: episode.gradient.map(Color.new).toList(),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: <Widget>[
              const Center(
                child: Icon(Icons.play_arrow, size: 36, color: Colors.white),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Text(
                  'Episode ${episode.number}',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          episode.title,
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          episode.description,
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onOpen,
            child: const Text('Buka'),
          ),
        ),
      ],
    );
  }
}
