import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/episode.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import 'widgets/action_rail.dart';
import 'widgets/caption_block.dart';
import 'widgets/episode_cover.dart';
import 'widgets/feed_top_bar.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final state = context.read<FeedBloc>().state;
    final visible = state.visibleEpisodes;
    final initial = visible.isEmpty
        ? 0
        : state.currentIndex.clamp(0, visible.length - 1);
    _controller = PageController(initialPage: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedBloc, FeedState>(
      listener: (context, state) {
        if (!_controller.hasClients || state.visibleEpisodes.isEmpty) {
          return;
        }
        final page = _controller.page?.round();
        if (page != null && page != state.currentIndex) {
          _controller.jumpToPage(state.currentIndex);
        }
      },
      builder: (context, state) {
        final episodes = state.visibleEpisodes;
        if (episodes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: <Widget>[
            FeedTopBar(
              tab: state.tab,
              onTabChanged: (tab) =>
                  context.read<FeedBloc>().add(FeedTabChanged(tab)),
            ),
            Expanded(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _controller,
                itemCount: episodes.length,
                onPageChanged: (index) => context.read<FeedBloc>().add(
                      FeedIndexChanged(index),
                    ),
                itemBuilder: (context, index) {
                  return ReelCard(episode: episodes[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Satu layar reels: cover, rel aksi kanan, caption bawah.
/// Ketuk video = putar/jeda (state UI), ketuk 2x = suka.
class ReelCard extends StatefulWidget {
  const ReelCard({required this.episode, super.key});

  final Episode episode;

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  bool _isPlaying = false;

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
  }

  void _showPlaceholderSheet(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEpisodeList() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return BlocBuilder<FeedBloc, FeedState>(
          builder: (context, state) {
            return ListView(
              shrinkWrap: true,
              children: state.episodes.map((episode) {
                return ListTile(
                  title: Text('Episode ${episode.number} - ${episode.title}'),
                  onTap: () {
                    context
                        .read<FeedBloc>()
                        .add(FeedEpisodeJumped(episode.id));
                    Navigator.of(sheetContext).pop();
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: () =>
          context.read<FeedBloc>().add(FeedLikeToggled(episode.id)),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: EpisodeCover(
              episode: episode,
              isPlaying: _isPlaying,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 150,
            child: ActionRail(
              episode: episode,
              onLike: () =>
                  context.read<FeedBloc>().add(FeedLikeToggled(episode.id)),
              onComment: () => _showPlaceholderSheet(
                'Komentar',
                'Komentar untuk episode ini menyusul (UI saja).',
              ),
              onShare: () => _showPlaceholderSheet(
                'Bagikan',
                'Bagikan episode ini menyusul (UI saja).',
              ),
              onBookmark: () => context
                  .read<FeedBloc>()
                  .add(FeedBookmarkToggled(episode.id)),
            ),
          ),
          Positioned(
            left: 16,
            right: 84,
            bottom: 16,
            child: CaptionBlock(
              episode: episode,
              isPlaying: _isPlaying,
              onPlayPause: _togglePlay,
              onShowEpisodes: _showEpisodeList,
            ),
          ),
        ],
      ),
    );
  }
}
