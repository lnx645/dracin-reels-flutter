import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../feed/domain/entities/episode.dart';
import '../../feed/domain/repositories/episode_repository.dart';
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
              'Cari episode Cinta Sang Penguasa Qin (contoh).',
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
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<ExploreBloc, ExploreState>(
                builder: (context, state) {
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
