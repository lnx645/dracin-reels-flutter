import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/route_observer.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/widgets/comments_sheet.dart';
import '../../domain/entities/episode.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import '../widgets/action_rail.dart';
import '../widgets/caption_block.dart';
import '../widgets/feed_top_bar.dart';
import '../widgets/reel_video.dart';

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

class _FeedPageState extends State<FeedPage> with RouteAware {
  late final PageController _controller;
  PageRoute<dynamic>? _route;

  /// Rute feed sedang di atas (false saat Player/detail didorong).
  bool _routeVisible = true;

  bool _followingLoading = false;
  bool _followingLoaded = false;
  String? _followingError;

  @override
  void initState() {
    super.initState();
    final state = context.read<FeedBloc>().state;
    final visible = state.visibleEpisodes;
    final initial = visible.isEmpty
        ? 0
        : state.currentIndex.clamp(0, visible.length - 1);
    _controller = PageController(initialPage: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFollowingIfNeeded();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // Player/detail didorong di atas feed → video preview pause.
    if (mounted) {
      setState(() => _routeVisible = false);
    }
  }

  @override
  void didPopNext() {
    // Kembali ke feed → video aktif lanjut otomatis (kecuali dijeda
    // manual di kartu).
    if (mounted) {
      setState(() => _routeVisible = true);
    }
  }

  @override
  void dispose() {
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _controller.dispose();
    super.dispose();
  }

  /// Muat id series bookmark dari API (untuk tab Mengikuti). Hanya bila
  /// sudah masuk + belum pernah dimuat + tidak sedang memuat. Belum
  /// masuk → bukan error (tab Mengikuti menampilkan ajakan masuk).
  Future<void> _loadFollowingIfNeeded() async {
    if (_followingLoading || _followingLoaded) {
      return;
    }
    if (!context.read<WalletBloc>().state.loggedIn) {
      return;
    }
    setState(() {
      _followingLoading = true;
      _followingError = null;
    });
    try {
      final series =
          await context.read<WalletRepository>().getBookmarks();
      if (!mounted) {
        return;
      }
      final ids = series.map((item) => item.id).toSet();
      context.read<FeedBloc>().add(FeedFollowingChanged(ids));
      setState(() {
        _followingLoading = false;
        _followingLoaded = true;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _followingLoading = false;
        _followingError = error.toString();
      });
    }
  }

  /// Skor preferensi per series dari data API yang nyata:
  /// bookmark +3, like +2, riwayat +1, plus bonus genre (maks +2) dari
  /// tagar episode series yang sama (tagar diturunkan dari genre API).
  /// Bila semua skor 0 → urutan default terbaru (tanpa klaim
  /// "dipersonalisasi" di UI mana pun).
  Map<int, int> _computeScores(
    List<Episode> episodes,
    WalletState wallet,
    Set<int> followed,
  ) {
    final historySeries =
        wallet.historyItems.map((item) => item.seriesId).toSet();
    final likedSeries = episodes
        .where((episode) => episode.isLiked)
        .map((episode) => episode.seriesId)
        .toSet();
    final signalSeries = <int>{...historySeries, ...likedSeries, ...followed};
    final preferenceTags = <String>{};
    for (final episode in episodes) {
      if (signalSeries.contains(episode.seriesId)) {
        preferenceTags.addAll(episode.hashtags);
      }
    }
    final scores = <int, int>{};
    for (final episode in episodes) {
      var score = 0;
      if (followed.contains(episode.seriesId)) {
        score += 3;
      }
      if (likedSeries.contains(episode.seriesId)) {
        score += 2;
      }
      if (historySeries.contains(episode.seriesId)) {
        score += 1;
      }
      var tagMatches = 0;
      for (final tag in episode.hashtags) {
        if (preferenceTags.contains(tag)) {
          tagMatches++;
        }
      }
      score += tagMatches > 2 ? 2 : tagMatches;
      if (score > 0) {
        scores[episode.seriesId] = score;
      }
    }
    return scores;
  }

  bool _mapsEqual(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  void _syncPreferences(FeedState state, WalletState wallet) {
    final scores =
        _computeScores(state.episodes, wallet, state.followedSeriesIds);
    if (_mapsEqual(scores, state.preferenceScores)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final current = context.read<FeedBloc>().state;
      final fresh = _computeScores(
        current.episodes,
        context.read<WalletBloc>().state,
        current.followedSeriesIds,
      );
      if (!_mapsEqual(fresh, current.preferenceScores)) {
        context.read<FeedBloc>().add(FeedPreferencesChanged(fresh));
      }
    });
  }

  void _onTabChanged(FeedTab tab) {
    context.read<FeedBloc>().add(FeedTabChanged(tab));
    if (tab == FeedTab.following) {
      _loadFollowingIfNeeded();
    }
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
        final wallet = context.watch<WalletBloc>().state;
        _syncPreferences(state, wallet);
        if (state.tab == FeedTab.following &&
            wallet.loggedIn &&
            !_followingLoaded &&
            !_followingLoading &&
            _followingError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadFollowingIfNeeded();
            }
          });
        }
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
          return Column(
            children: <Widget>[
              FeedTopBar(
                tab: state.tab,
                onTabChanged: _onTabChanged,
                showModeSwitch: widget.showModeSwitch,
                isSeriesMode: widget.isSeriesMode,
                onModeChanged: widget.onModeChanged,
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _followingEmptyContent(state, wallet),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: <Widget>[
            FeedTopBar(
              tab: state.tab,
              onTabChanged: _onTabChanged,
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
                  final episode = episodes[index];
                  return ReelCard(
                    key: ValueKey<String>(episode.id),
                    episode: episode,
                    isActive: index == state.currentIndex,
                    isVisible: _routeVisible,
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

  /// Isi empty state tab Mengikuti (jujur, per kondisi):
  /// belum masuk → ajakan masuk; memuat → spinner; gagal → error +
  /// retry; sudah dimuat + kosong → belum ada yang diikuti.
  Widget _followingEmptyContent(FeedState state, WalletState wallet) {
    if (state.tab != FeedTab.following) {
      return const Text(
        'Belum ada data.',
        textAlign: TextAlign.center,
      );
    }
    if (!wallet.loggedIn) {
      return const Text(
        'Masuk untuk melihat series yang diikuti.',
        textAlign: TextAlign.center,
      );
    }
    if (_followingLoading) {
      return const CircularProgressIndicator();
    }
    if (_followingError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off, size: 64),
          const SizedBox(height: 16),
          Text(
            _followingError!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadFollowingIfNeeded,
            child: const Text('Coba Lagi'),
          ),
        ],
      );
    }
    return const Text(
      'Belum ada series yang diikuti.\n'
      'Ketuk Simpan pada episode untuk mengikuti series-nya.',
      textAlign: TextAlign.center,
    );
  }
}

/// Satu layar reels: video autoplay, rel aksi kanan, caption bawah.
/// Ketuk video = jeda/putar; ketuk 2x video = suka; tombol Tonton /
/// ketuk caption = buka halaman Player lengkap. Episode terkunci tidak
/// pernah autoplay (overlay kunci → Player untuk buka kunci).
class ReelCard extends StatefulWidget {
  const ReelCard({
    required this.episode,
    required this.isActive,
    required this.isVisible,
    required this.onOpenEpisode,
    super.key,
  });

  final Episode episode;

  /// Kartu ini sedang tampil penuh di PageView.
  final bool isActive;

  /// Rute feed sedang di atas.
  final bool isVisible;

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
      // Sinkronkan tab Mengikuti: bookmark baru → series masuk daftar
      // diikuti; batal bookmark → keluar (tanpa muat ulang API).
      if (mounted) {
        final bloc = context.read<FeedBloc>();
        final updated = Set<int>.from(bloc.state.followedSeriesIds);
        if (wasBookmarked) {
          updated.remove(episode.seriesId);
        } else {
          updated.add(episode.seriesId);
        }
        bloc.add(FeedFollowingChanged(updated));
      }
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
    // Hanya episode series kartu ini (bukan campuran semua series
    // seperti sheet lama — konsisten dengan daftar Player).
    final seriesEpisodes = context
        .read<FeedBloc>()
        .state
        .episodes
        .where((item) => item.seriesId == widget.episode.seriesId)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          children: seriesEpisodes.map((episode) {
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
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _videoArea(episode)),
        // Gradasi HANYA lapisan baca di belakang teks (bawah), bukan
        // pengganti video.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 260,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Color(0xDD000000),
                  ],
                ),
              ),
            ),
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
          child: GestureDetector(
            // Ketuk area caption = buka Player (perilaku lama kartu);
            // tombol di dalamnya tetap menangani ketukannya sendiri.
            onTap: () => _openPlayer(episode.id),
            child: CaptionBlock(
              episode: episode,
              onWatch: () => _openPlayer(episode.id),
              onShowEpisodes: _showEpisodeList,
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoArea(Episode episode) {
    if (episode.locked) {
      // Terkunci: TIDAK PERNAH autoplay. Overlay kunci → ketuk membuka
      // Player (overlay + dialog buka kunci yang sama di sana).
      return GestureDetector(
        onTap: () => _openPlayer(episode.id),
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock, size: 56, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'Episode terkunci',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  episode.coinPrice > 0
                      ? '${episode.coinPrice} koin untuk membuka'
                      : 'Ketuk untuk membuka di Player',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (episode.videoUrl.trim().isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Video belum tersedia untuk episode ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onDoubleTap: _toggleLike,
      child: ReelVideo(
        videoUrl: episode.videoUrl,
        isActive: widget.isActive,
        isVisible: widget.isVisible,
      ),
    );
  }
}
