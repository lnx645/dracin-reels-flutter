import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/entities/episode.dart';
import '../../../feed/domain/repositories/episode_repository.dart';
import '../bloc/bookmark_bloc.dart';

class BookmarkPage extends StatelessWidget {
  const BookmarkPage({this.onOpenEpisode, super.key});

  final void Function(String episodeId)? onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookmarkBloc(
        context.read<EpisodeRepository>(),
      )..add(const BookmarkStarted()),
      child: BookmarkView(onOpenEpisode: onOpenEpisode),
    );
  }
}

class BookmarkView extends StatelessWidget {
  const BookmarkView({this.onOpenEpisode, super.key});

  final void Function(String episodeId)? onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmark')),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state.episodes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada episode tersimpan. Ketuk Simpan di feed '
                  'untuk menambahkannya ke sini.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: state.episodes.length,
            itemBuilder: (context, index) {
              final episode = state.episodes[index];
              return _BookmarkTile(
                episode: episode,
                onOpen: onOpenEpisode == null
                    ? null
                    : () => onOpenEpisode!(episode.id),
                onRemove: () => context
                    .read<BookmarkBloc>()
                    .add(BookmarkRemoved(episode.id)),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({
    required this.episode,
    required this.onRemove,
    this.onOpen,
  });

  final Episode episode;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: episode.gradient.map(Color.new).toList(),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white),
      ),
      title: Text(
        'Episode ${episode.number} - ${episode.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        episode.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextButton(onPressed: onRemove, child: const Text('Hapus')),
          if (onOpen != null)
            TextButton(onPressed: onOpen, child: const Text('Buka')),
        ],
      ),
    );
  }
}
