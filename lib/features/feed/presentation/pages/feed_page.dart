import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/widgets/comments_sheet.dart';
import '../../domain/entities/episode.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import '../widgets/action_rail.dart';
import '../widgets/caption_block.dart';
import '../widgets/episode_cover.dart';
import '../widgets/feed_top_bar.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({
    this.showModeSwitch = false,
    this.isSeriesMode = false,
    this.onModeChanged,
    required this.onOpenEpisode,
    super.key,
  });

  /// Teruskan ke FeedTopBar: di mode Reels, header Beranda disembunyikan
  /// sehingga switch mode Series/Reels tinggal di FeedTopBar (tanpa
  /// header ganda). Di pemakaian lain, default false = tanpa switch.
  final bool showModeSwitch;
  final bool isSeriesMode;
  final ValueChanged<bool>? onModeChanged;

  /// Feed hanya browsing: ketuk kartu/tombol Tonton membuka PlayerPage
  /// lewat callback ini (satu jalur dengan detail series & riwayat).
  final void Function(String episodeId) onOpenEpisode;

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
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<FeedBloc>()
                        .add(const FeedStarted()),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (episodes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Belum ada data.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          children: <Widget>[
            FeedTopBar(
              tab: state.tab,
              onTabChanged: (tab) =>
                  context.read<FeedBloc>().add(FeedTabChanged(tab)),
              showModeSwitch: widget.showModeSwitch,
              isSeriesMode: widget.isSeriesMode,
              onModeChanged: widget.onModeChanged,
            ),
            Expanded(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _controller,
                itemCount: episodes.length,
                onPageChanged: (index) {
                  // Browsing saja: ganti episode di feed TIDAK mencatat
                  // riwayat. Riwayat hanya tercatat saat episode dibuka
                  // di halaman Player.
                  context.read<FeedBloc>().add(FeedIndexChanged(index));
                },
                itemBuilder: (context, index) {
                  return ReelCard(
                    episode: episodes[index],
                    onOpenEpisode: widget.onOpenEpisode,
                  );
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
/// Feed hanya browsing: ketuk video/tombol Tonton = buka halaman Player
/// (bukan putar inline), ketuk 2x = suka.
class ReelCard extends StatefulWidget {
  const ReelCard({
    required this.episode,
    required this.onOpenEpisode,
    super.key,
  });

  final Episode episode;

  /// Dibuka dengan id episode API (`s{seriesId}e{episodeId}`).
  final void Function(String episodeId) onOpenEpisode;

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {

  Future<void> _toggleLike() async {
    final episode = widget.episode;
    final bool wasLiked = episode.isLiked;
    context.read<FeedBloc>().add(FeedLikeToggled(episode.id));
    // Sinkronisasi API (id episode API; nomor dipakai hanya bila id
    // API tidak diketahui). Gagal → toggle dibatalkan + pesan asli.
    try {
      await context.read<WalletRepository>().toggleLike(
            episode.apiEpisodeId > 0 ? episode.apiEpisodeId : episode.number,
            !wasLiked,
          );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      context.read<FeedBloc>().add(FeedLikeToggled(episode.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _toggleBookmark() async {
    final episode = widget.episode;
    final bool wasBookmarked = episode.isBookmarked;
    context.read<FeedBloc>().add(FeedBookmarkToggled(episode.id));
    // Bookmark API per series pemilik episode.
    try {
      await context.read<WalletRepository>().toggleBookmark(
            episode.seriesId,
            !wasBookmarked,
          );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      context.read<FeedBloc>().add(FeedBookmarkToggled(episode.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _openPlayer(String episodeId) {
    widget.onOpenEpisode(episodeId);
  }

  void _showComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(episodeId: widget.episode.number),
    );
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
                    Navigator.of(sheetContext).pop();
                    _openPlayer(episode.id);
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
      // Ketuk kartu = buka halaman Player (bukan putar inline).
      onTap: () => _openPlayer(episode.id),
      onDoubleTap: _toggleLike,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: EpisodeCover(
              episode: episode,
              isPlaying: false,
              // Cadangkan zona caption bawah supaya label "Episode N"
              // yang terpusat tidak pernah menimpa deskripsi.
              bottomPadding: 220,
            ),
          ),
          // Rel di band bebas antara tab atas dan caption bawah,
          // dipusatkan vertikal — ikon pertama tidak terpotong atas.
          Positioned(
            right: 12,
            top: 24,
            bottom: 230,
            child: Align(
              alignment: Alignment.centerRight,
              child: ActionRail(
                episode: episode,
                onLike: _toggleLike,
                onComment: _showComments,
                onShare: () => _showPlaceholderSheet(
                  'Bagikan',
                  'Bagikan episode ini menyusul (UI saja).',
                ),
                onBookmark: _toggleBookmark,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 84,
            bottom: 16,
            child: CaptionBlock(
              episode: episode,
              onWatch: () => _openPlayer(episode.id),
              onShowEpisodes: _showEpisodeList,
            ),
          ),
        ],
      ),
    );
  }
}
