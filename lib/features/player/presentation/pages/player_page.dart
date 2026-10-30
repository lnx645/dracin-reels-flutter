import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../feed/domain/entities/episode.dart';
import '../../../feed/presentation/bloc/feed_bloc.dart';
import '../../../feed/presentation/bloc/feed_event.dart';
import '../../../feed/presentation/bloc/feed_state.dart';
import '../../../feed/presentation/widgets/episode_cover.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/widgets/comments_sheet.dart';

/// Halaman Player khusus — SATU-SATUNYA tempat episode ditonton.
/// Feed (Reels maupun Series) hanya browsing: ketuk kartu/tombol Tonton
/// membuka halaman ini, bukan memutar inline di kartu.
/// Jalur yang sama dari semua tempat: feed, "Tonton Semua" (lewat detail
/// series), detail series, Riwayat/Lanjutkan Nonton — semuanya membuka
/// halaman ini dengan episodeId yang sama (`ep1`..`ep5`).
/// Video masih placeholder (gradasi + judul) sampai pemutar beneran
/// dipasang — dinyatakan jujur di README, bukan diklaim memutar.
class PlayerPage extends StatefulWidget {
  const PlayerPage({required this.episodeId, this.seriesId = 1, super.key});

  /// Id sampel feed (`ep1`..`ep5`) sesuai nomor episode.
  final String episodeId;
  final int seriesId;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late String _currentId;
  bool _isPlaying = false;

  /// Episode yang dibuka kunci di sesi ini (tidak mengandalkan reload).
  final Set<int> _localUnlocked = <int>{};
  int? _pendingUnlockId;
  int? _lastUnlockShown;
  String? _lastErrorShown;

  /// Episode yang sudah tercatat ke riwayat di sesi player ini.
  final Set<String> _recorded = <String>{};

  @override
  void initState() {
    super.initState();
    _currentId = widget.episodeId;
  }

  List<Episode> _sortedEpisodes(List<Episode> episodes) {
    final sorted = episodes.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return sorted;
  }

  Episode? _currentEpisode(List<Episode> episodes) {
    for (final episode in episodes) {
      if (episode.id == _currentId) {
        return episode;
      }
    }
    return null;
  }

  /// Tercatat ke Riwayat + WatchProgress (satu sumber data dengan
  /// "Lanjutkan Nonton"): sekali per episode per sesi player.
  void _recordCurrent(Episode episode) {
    if (_recorded.contains(episode.id)) {
      return;
    }
    _recorded.add(episode.id);
    context.read<WalletBloc>().add(
          WalletContinueSaved(
            episodeId: episode.number,
            title: episode.title,
            number: episode.number,
            seriesId: widget.seriesId,
          ),
        );
  }

  void _switchTo(String episodeId) {
    setState(() {
      _currentId = episodeId;
      _isPlaying = false;
    });
  }

  void _toggleLike(Episode episode) {
    context.read<FeedBloc>().add(FeedLikeToggled(episode.id));
    context.read<WalletRepository>().toggleLike(
          episode.number,
          !episode.isLiked,
        );
  }

  void _toggleBookmark(Episode episode) {
    context.read<FeedBloc>().add(FeedBookmarkToggled(episode.id));
    context.read<WalletRepository>().toggleBookmark(
          widget.seriesId,
          !episode.isBookmarked,
        );
  }

  void _showComments(Episode episode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(episodeId: episode.number),
    );
  }

  void _showShareSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Bagikan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Bagikan episode ini menyusul (UI saja).',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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

  void _showEpisodeList(
    List<Episode> episodes,
    Map<int, SeriesEpisode> detailByNumber,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          children: episodes.map((episode) {
            final detail = detailByNumber[episode.number];
            final locked = detail?.locked ?? false;
            return ListTile(
              leading: locked
                  ? const Icon(Icons.lock, size: 20)
                  : CircleAvatar(child: Text('${episode.number}')),
              title: Text('Episode ${episode.number} - ${episode.title}'),
              subtitle: locked && detail != null
                  ? Text('${detail.coinPrice} koin')
                  : null,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _switchTo(episode.id);
              },
            );
          }).toList(),
        );
      },
    );
  }

  /// Alur kunci — sama persis dengan detail series: belum masuk → dialog
  /// masuk; koin kurang → dialog ke Hadiah; cukup → dispatch unlock dan
  /// tunggu konfirmasi bloc (listener di build).
  Future<void> _onUnlockPressed(SeriesEpisode detail) async {
    final wallet = context.read<WalletBloc>().state;
    final session = context.read<SessionCubit>().state;
    if (!session.isAuthenticated) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Masuk dulu'),
          content: Text(
            'Episode ${detail.number} terkunci (${detail.coinPrice} '
            'koin). Masuk untuk membuka episode dengan koin atau VIP.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Masuk'),
            ),
          ],
        ),
      );
      if (goLogin == true && mounted) {
        await Navigator.of(context).pushNamed('/login');
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Buka Episode ${detail.number}?'),
        content: Text(
          '${detail.title}\n\nHarga: ${detail.coinPrice} koin. '
          'Saldo Anda: ${wallet.balance} koin.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buka dengan Koin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    if (wallet.balance < detail.coinPrice) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Koin tidak cukup'),
          content: Text(
            'Harga ${detail.coinPrice} koin, saldo Anda '
            '${wallet.balance} koin. Klaim check-in harian untuk '
            'menambah koin.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushNamed('/rewards');
              },
              child: const Text('Ke Hadiah'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _pendingUnlockId = detail.id);
    context.read<WalletBloc>().add(
          WalletUnlockRequested(
            episodeId: detail.id,
            price: detail.coinPrice,
          ),
        );
  }

  Widget _lockOverlay(SeriesEpisode detail) {
    return Container(
      color: const Color(0xAA000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock, size: 56, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Episode ${detail.number} terkunci',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${detail.coinPrice} koin untuk membuka episode ini.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _onUnlockPressed(detail),
                child: const Text('Buka dengan Koin'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoArea(Episode episode, bool locked, SeriesEpisode? lockedDetail) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: EpisodeCover(
            episode: episode,
            isPlaying: _isPlaying && !locked,
          ),
        ),
        if (lockedDetail != null)
          Positioned.fill(child: _lockOverlay(lockedDetail)),
      ],
    );
  }

  Widget _infoSection(
    Episode episode,
    Episode? previous,
    Episode? next,
    bool locked,
    List<Episode> episodes,
    Map<int, SeriesEpisode> detailByNumber,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            episode.title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Episode ${episode.number}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            episode.description,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            episode.hashtags.join(' '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      previous == null ? null : () => _switchTo(previous.id),
                  child: const Text('Sebelumnya'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: locked
                      ? null
                      : () => setState(() => _isPlaying = !_isPlaying),
                  child: Text(
                    locked
                        ? 'Terkunci'
                        : (_isPlaying ? 'Jeda' : 'Putar'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: next == null ? null : () => _switchTo(next.id),
                  child: const Text('Berikutnya'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _PlayerAction(
                icon: episode.isLiked
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: 'Suka',
                active: episode.isLiked,
                onPressed: () => _toggleLike(episode),
              ),
              _PlayerAction(
                icon: Icons.chat_bubble_outline,
                label: 'Komentar',
                onPressed: () => _showComments(episode),
              ),
              _PlayerAction(
                icon: Icons.share,
                label: 'Bagikan',
                onPressed: _showShareSheet,
              ),
              _PlayerAction(
                icon: episode.isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                label: 'Simpan',
                active: episode.isBookmarked,
                onPressed: () => _toggleBookmark(episode),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showEpisodeList(episodes, detailByNumber),
              child: const Text('Daftar Episode'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Video belum memutar (UI saja). Area video di atas masih '
            'placeholder sampai pemutar beneran dipasang.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch: player ikut rebuild saat saldo/VIP berubah (mis. kembali
    // dari halaman Hadiah setelah klaim), bukan hanya saat feed berubah.
    final wallet = context.watch<WalletBloc>().state;
    return BlocProvider(
      create: (_) => SeriesDetailBloc(context.read<SeriesRepository>())
        ..add(SeriesDetailStarted(widget.seriesId)),
      child: BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          final unlockedId = state.lastUnlockedId;
          if (_pendingUnlockId != null &&
              unlockedId == _pendingUnlockId &&
              _lastUnlockShown != unlockedId) {
            _lastUnlockShown = unlockedId;
            setState(() {
              _localUnlocked.add(unlockedId!);
              _pendingUnlockId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Episode terbuka!')),
            );
          }
          final error = state.errorMessage;
          if (_pendingUnlockId != null &&
              error != null &&
              error != _lastErrorShown) {
            _lastErrorShown = error;
            setState(() => _pendingUnlockId = null);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
        child: BlocBuilder<FeedBloc, FeedState>(
          builder: (context, feedState) {
            final episodes = _sortedEpisodes(feedState.episodes);
            final episode = _currentEpisode(episodes);
            if (episode == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Player')),
                body: const Center(
                  child: Text('Episode tidak ditemukan.'),
                ),
              );
            }
            final index = episodes.indexOf(episode);
            final previous = index > 0 ? episodes[index - 1] : null;
            final next =
                index < episodes.length - 1 ? episodes[index + 1] : null;
            return BlocBuilder<SeriesDetailBloc, SeriesDetailState>(
              builder: (context, detailState) {
                final detailByNumber = <int, SeriesEpisode>{
                  for (final item
                      in detailState.detail?.episodes ?? <SeriesEpisode>[])
                    item.number: item,
                };
                final detail = detailByNumber[episode.number];
                final locked = detail != null &&
                    detail.locked &&
                    !_localUnlocked.contains(detail.id) &&
                    !wallet.vip.isActive;
                final lockedDetail = locked ? detail : null;
                // Tercatat ke riwayat saat episode terbuka untuk ditonton
                // (bukan saat masih terkunci di balik gembok).
                if (!locked) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _recordCurrent(episode);
                    }
                  });
                }
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Episode ${episode.number}'),
                  ),
                  body: SafeArea(
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          flex: 5,
                          child: _videoArea(
                            episode,
                            locked,
                            lockedDetail,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: _infoSection(
                            episode,
                            previous,
                            next,
                            locked,
                            episodes,
                            detailByNumber,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: active ? AppColors.accent : Colors.white,
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
