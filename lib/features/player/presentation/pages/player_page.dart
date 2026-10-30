import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../feed/domain/entities/episode.dart';
import '../../../feed/presentation/bloc/feed_bloc.dart';
import '../../../feed/presentation/bloc/feed_event.dart';
import '../../../feed/presentation/bloc/feed_state.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import '../../../series/presentation/pages/series_detail_page.dart';
import '../widgets/video_player_area.dart';
import '../widgets/subtitle_parser.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/widgets/comments_sheet.dart';

/// Halaman Player khusus — SATU-SATUNYA tempat episode ditonton.
/// Feed (Reels maupun Series) hanya browsing: ketuk kartu/tombol Tonton
/// membuka halaman ini, bukan memutar inline di kartu.
/// Jalur yang sama dari semua tempat: feed, "Tonton Semua" (lewat detail
/// series), detail series, Riwayat/Lanjutkan Nonton — semuanya membuka
/// halaman ini dengan id episode API (`s{seriesId}e{episodeId}`).
/// Video diputar beneran dari `video_url` episode (file video langsung
/// atau HLS) lewat VideoPlayerArea; episode terkunci tetap tidak memutar.
/// Tautan halaman web (mis. halaman YouTube) tidak dapat diputar oleh
/// pemutar ini — init gagal ditampilkan sebagai error asli + Coba Lagi.
class PlayerPage extends StatefulWidget {
  const PlayerPage({required this.episodeId, this.seriesId = 1, super.key});

  /// Id episode API (`s{seriesId}e{episodeId}`).
  final String episodeId;

  /// Series fallback bila id tidak memuat series (tidak terjadi untuk
  /// id dari feed/detail/riwayat yang baru).
  final int seriesId;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late String _currentId;
  late int _seriesId;
  bool _isPlaying = false;

  /// Status putar yang diminta untuk area video (tombol Putar/Jeda di
  /// bawah ikut status controller yang sebenarnya lewat callback).
  final ValueNotifier<bool> _playRequest = ValueNotifier<bool>(false);

  int? _pendingUnlockId;
  int? _lastUnlockShown;
  String? _lastErrorShown;

  /// Episode yang sudah tercatat ke riwayat di sesi player ini.
  final Set<String> _recorded = <String>{};

  /// DUA STATE PLAYER (klarifikasi uwa):
  /// - PAUSE = kontrol: chrome lengkap (header, rel kanan, judul,
  ///   tombol, progress, baris episode).
  /// - PLAY = imersi: chrome menghilang (fade/collapse), tersisa video
  ///   + subtitle + progress tipis. Ketuk video saat play → pause +
  ///   chrome kembali; ketuk saat pause → play + chrome hilang
  ///   otomatis setelah ~3 detik (timer di-reset tiap interaksi).
  bool _chromeVisible = true;
  Timer? _hideTimer;

  /// Mode layar penuh (landscape, orientasi dikunci selama aktif).
  bool _fullscreen = false;

  /// Subtitle episode aktif (VTT/SRT ter-parse). Kosong = tidak ada
  /// subtitle atau gagal dimuat/parse → tanpa overlay, bukan teks
  /// contoh.
  List<SubtitleCue> _subtitleCues = <SubtitleCue>[];
  String _subtitleUrlFetched = '';

  /// Posisi putar terbaru (untuk sinkronisasi subtitle).
  Duration _videoPosition = Duration.zero;

  /// Deskripsi diperluas atau cuplikan 2 baris.
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _currentId = widget.episodeId;
    _seriesId = _parseSeriesId(widget.episodeId) ?? widget.seriesId;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playRequest.dispose();
    // Pulihkan orientasi bila keluar halaman saat fullscreen aktif.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// Status putar dari controller video (bukan lagi bool UI semata):
  /// label tombol Putar/Jeda mengikuti apa yang benar-benar terjadi.
  /// Memutar → mulai timer sembunyikan chrome 3 detik; dijeda →
  /// batalkan timer + chrome kembali.
  void _onPlayingChanged(bool playing) {
    if (!mounted || playing == _isPlaying) {
      return;
    }
    setState(() => _isPlaying = playing);
    if (playing) {
      _resetHideTimer();
    } else {
      _hideTimer?.cancel();
      if (!_chromeVisible) {
        setState(() => _chromeVisible = true);
      }
    }
  }

  /// Timer auto-hide chrome: hanya berjalan saat benar-benar memutar;
  /// tiap interaksi memanggil ini lagi (timer di-reset).
  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_isPlaying) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && _chromeVisible) {
        setState(() => _chromeVisible = false);
      }
    });
  }

  /// Layar penuh: kunci orientasi landscape; keluar → pulihkan semua
  /// orientasi. Controller video TIDAK dipindah — halaman yang sama
  /// yang membesar, jadi posisi putar tidak hilang.
  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setPreferredOrientations(
        <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _resetHideTimer();
  }

  /// Ambil + parse subtitle episode aktif. Gagal/parse kosong → cue
  /// kosong (tanpa overlay), bukan error yang memblokir video.
  Future<void> _fetchSubtitles(String rawUrl) async {
    final resolved = resolveMediaUrl(rawUrl);
    if (resolved.isEmpty) {
      return;
    }
    try {
      final text = await context.read<ApiClient>().getText(resolved);
      if (!mounted || _subtitleUrlFetched != rawUrl) {
        return;
      }
      setState(() => _subtitleCues = parseSubtitle(text));
    } on Exception {
      if (mounted && _subtitleUrlFetched == rawUrl) {
        setState(() => _subtitleCues = <SubtitleCue>[]);
      }
    }
  }

  void _onVideoPosition(Duration position) {
    if (mounted) {
      setState(() => _videoPosition = position);
    }
  }

  /// Id `s{seriesId}e{episodeId}` → seriesId; `epN` lama → 1.
  int? _parseSeriesId(String id) {
    final RegExpMatch? match = RegExp(r'^s(\d+)e\d+$').firstMatch(id);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    if (id.startsWith('ep')) {
      return 1;
    }
    return null;
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

  /// Id `s{seriesId}e{episodeId}` → episodeId API; `epN` lama → nomor N.
  int? _parseApiEpisodeId(String id) {
    final RegExpMatch? match = RegExp(r'^s\d+e(\d+)$').firstMatch(id);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    if (id.startsWith('ep')) {
      return int.tryParse(id.substring(2));
    }
    return null;
  }

  /// Episode series aktif dari detail API: dedupe per id, urut per nomor.
  /// Ini SATU-SATUNYA sumber daftar episode Player — tidak pernah dari
  /// feed global (yang mencampur semua series) dan tidak pernah dari
  /// cache lokal yang tidak ada di API.
  List<SeriesEpisode> _sortedUniqueSeriesEpisodes(
    List<SeriesEpisode> input,
  ) {
    final Map<int, SeriesEpisode> byId = <int, SeriesEpisode>{};
    for (final SeriesEpisode item in input) {
      byId[item.id] = item;
    }
    final List<SeriesEpisode> list = byId.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  /// Episode tampilan cadangan bila feed (yang bisa basi — dimuat sebelum
  /// episode dibuat) belum memuat episode yang sudah ada di detail API.
  /// Judul/deskripsi dari detail API, bukan karangan.
  Episode _episodeFromDetail(SeriesEpisode detail, Series series) {
    final int seriesId = detail.seriesId > 0 ? detail.seriesId : _seriesId;
    return Episode(
      id: 's$seriesId' 'e${detail.id}',
      title: detail.title,
      number: detail.number,
      description: detail.description,
      hashtags: series.genres
          .map((genre) => '#${genre.name.replaceAll(' ', '')}')
          .toList(),
      likes: 0,
      comments: 0,
      shares: 0,
      gradient: const <int>[0xFF3B1D5A, 0xFF0B0E14],
      seriesId: seriesId,
      apiEpisodeId: detail.id,
    );
  }

  /// Tercatat ke Riwayat + WatchProgress (satu sumber data dengan
  /// "Lanjutkan Nonton"): sekali per episode per sesi player.
  /// Judul series dari detail API (bukan default karangan).
  void _recordCurrent(Episode episode, String seriesTitle) {
    if (_recorded.contains(episode.id)) {
      return;
    }
    _recorded.add(episode.id);
    context.read<WalletBloc>().add(
          WalletContinueSaved(
            episodeId: episode.apiEpisodeId > 0
                ? episode.apiEpisodeId
                : episode.number,
            title: episode.title,
            number: episode.number,
            seriesId: _seriesId,
            seriesTitle: seriesTitle,
          ),
        );
  }

  void _switchTo(String episodeId) {
    _hideTimer?.cancel();
    setState(() {
      _currentId = episodeId;
      _seriesId = _parseSeriesId(episodeId) ?? _seriesId;
      _isPlaying = false;
      // Episode baru = state PAUSE (chrome kembali) + posisi +
      // deskripsi di-reset.
      _chromeVisible = true;
      _videoPosition = Duration.zero;
      _descriptionExpanded = false;
    });
    // Controller baru tidak boleh auto-memutar episode pengganti.
    _playRequest.value = false;
  }

  Future<void> _toggleLike(Episode episode) async {
    final bool wasLiked = episode.isLiked;
    context.read<FeedBloc>().add(FeedLikeToggled(episode.id));
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

  Future<void> _toggleBookmark(Episode episode) async {
    final bool wasBookmarked = episode.isBookmarked;
    context.read<FeedBloc>().add(FeedBookmarkToggled(episode.id));
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

  void _showComments(Episode episode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(
        episodeId:
            episode.apiEpisodeId > 0 ? episode.apiEpisodeId : episode.number,
      ),
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

  /// Bottom sheet daftar episode — HANYA episode series yang sedang
  /// diputar (dari detail API, sudah dedupe + urut). Tidak pernah
  /// mencampur series lain, tidak pernah dari feed global.
  void _showEpisodeList(List<SeriesEpisode> seriesEpisodes, int seriesId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          children: seriesEpisodes.map((detail) {
            final locked = detail.locked;
            return ListTile(
              leading: locked
                  ? const Icon(Icons.lock, size: 20)
                  : CircleAvatar(child: Text('${detail.number}')),
              title: Text('Episode ${detail.number} - ${detail.title}'),
              subtitle:
                  locked ? Text('${detail.coinPrice} koin') : null,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _switchTo('s$seriesId' 'e${detail.id}');
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
    final int? balance = wallet.balance;
    if (balance == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo tidak dapat dimuat. Coba lagi.'),
          ),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Buka Episode ${detail.number}?'),
        content: Text(
          '${detail.title}\n\nHarga: ${detail.coinPrice} koin. '
          'Saldo Anda: $balance koin.',
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
    if (balance < detail.coinPrice) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Koin tidak cukup'),
          content: Text(
            'Harga ${detail.coinPrice} koin, saldo Anda '
            '$balance koin. Klaim check-in harian untuk '
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

  /// Buka detail series dari Player (judul / menu "..."): kembali ke
  /// Player bila episode dipilih di detail (pop + ganti episode).
  void _openSeriesDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeriesDetailPage(
          seriesId: _seriesId,
          onOpenEpisode: (episodeId) {
            Navigator.of(context).pop();
            _switchTo(episodeId);
          },
        ),
      ),
    );
  }

  /// Header pola referensi: kembali + "Ep. N" + "..." (menu →
  /// Daftar Episode / Detail Series). Dibangun di body (bukan AppBar)
  /// agar bisa collapse bersama chrome saat PLAY fokus.
  Widget _headerRow(
    Episode episode,
    List<SeriesEpisode> seriesEpisodes,
    int seriesId,
  ) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Text(
            'Ep. ${episode.number}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Opsi',
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            _resetHideTimer();
            if (value == 'episodes') {
              _showEpisodeList(seriesEpisodes, seriesId);
            } else if (value == 'detail') {
              _openSeriesDetail();
            }
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            if (seriesEpisodes.isNotEmpty)
              const PopupMenuItem(
                value: 'episodes',
                child: Text('Daftar Episode'),
              ),
            const PopupMenuItem(
              value: 'detail',
              child: Text('Detail Series'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _videoArea(
    bool locked,
    SeriesEpisode? lockedDetail,
    SeriesEpisode? detail,
    bool detailLoading,
    String coverUrl,
    Episode episode,
  ) {
    // ATURAN KEJUJURAN STATE (cacat kelas terburuk: ikon "memutar" tanpa
    // video jalan): area video TIDAK PERNAH menampilkan gradasi statis
    // berikon putar sebagai "sedang memutar".
    // - Terkunci → cover series + gembok (video tidak pernah di-init).
    // - Detail ada → pemutar beneran (poster cover sebelum frame
    //   pertama, loading = spinner, gagal = error).
    // - Detail masih dimuat → cover series + spinner, bukan gradasi.
    // - Detail sudah dimuat tapi episode tidak ada → state jujur
    //   "Video belum tersedia" dari VideoPlayerArea.
    final resolvedCover = resolveMediaUrl(coverUrl);
    final Widget video;
    if (lockedDetail != null) {
      video = resolvedCover.isEmpty
          ? Container(color: Colors.black)
          : Image.network(
              resolvedCover,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.black),
            );
    } else if (detail != null) {
      video = VideoPlayerArea(
        key: ValueKey<String>('video-${detail.id}'),
        videoUrl: detail.videoUrl,
        playRequest: _playRequest,
        onPlayingChanged: _onPlayingChanged,
        posterUrl: coverUrl,
        // State PLAY fokus: kontrol penuh → progress tipis.
        showControls: _chromeVisible,
        onPositionChanged: _onVideoPosition,
      );
    } else if (detailLoading) {
      video = Stack(
        children: <Widget>[
          if (resolvedCover.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                resolvedCover,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.black),
              ),
            ),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    } else {
      video = VideoPlayerArea(
        key: const ValueKey<String>('video-missing'),
        videoUrl: '',
        playRequest: _playRequest,
        onPlayingChanged: _onPlayingChanged,
      );
    }
    // Rel kanan hanya saat video (tidak terkunci); di state PLAY fokus
    // dan di fullscreen ia menghilang bersama chrome.
    final railVisible =
        lockedDetail == null && _chromeVisible && !_fullscreen;
    final currentCue = detail != null && lockedDetail == null
        ? cueAt(_subtitleCues, _videoPosition)
        : null;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: video),
        if (lockedDetail != null)
          Positioned.fill(child: _lockOverlay(lockedDetail)),
        // Rel kanan: Suka / Komentar / Bagikan / Simpan — ikon TANPA
        // angka (API tidak menyediakan hitungan; angka referensi
        // 18,4K/192/24,6K TIDAK PERNAH ditiru).
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !railVisible,
            child: AnimatedOpacity(
              opacity: railVisible ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _PlayerAction(
                      icon: episode.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: 'Suka',
                      active: episode.isLiked,
                      onPressed: () {
                        _resetHideTimer();
                        _toggleLike(episode);
                      },
                    ),
                    const SizedBox(height: 16),
                    _PlayerAction(
                      icon: Icons.chat_bubble_outline,
                      label: 'Komentar',
                      onPressed: () {
                        _resetHideTimer();
                        _showComments(episode);
                      },
                    ),
                    const SizedBox(height: 16),
                    _PlayerAction(
                      icon: Icons.share,
                      label: 'Bagikan',
                      onPressed: () {
                        _resetHideTimer();
                        _showShareSheet();
                      },
                    ),
                    const SizedBox(height: 16),
                    _PlayerAction(
                      icon: episode.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: 'Simpan',
                      active: episode.isBookmarked,
                      onPressed: () {
                        _resetHideTimer();
                        _toggleBookmark(episode);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Overlay subtitle: hanya bila ada cue pada posisi putar saat
        // ini. Gaya keterbacaan (arahan senior UI/UX): teks cukup besar
        // (17, Semibold), putih kontras tinggi, bayangan gelap +
        // scrim hitam transparan, posisi aman DI ATAS kontrol/progress
        // (tidak menabrak progress bar).
        if (currentCue != null)
          Positioned(
            left: 16,
            right: railVisible ? 72 : 16,
            bottom: _chromeVisible ? 64 : 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentCue.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    shadows: <Shadow>[
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                      Shadow(
                        color: Colors.black,
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Keluar fullscreen: selalu terlihat saat fullscreen (jalan
        // keluar imersi tidak boleh hilang bersama chrome).
        if (_fullscreen)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'Keluar dari layar penuh',
                onPressed: _toggleFullscreen,
                icon: const Icon(
                  Icons.fullscreen_exit,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoSection(
    Episode episode,
    String? previousId,
    String? nextId,
    bool locked,
    List<SeriesEpisode> seriesEpisodes,
    int seriesId,
    SeriesEpisode? detail,
    String? seriesTitle,
    int freeEpisodeCount,
  ) {
    // Tombol Putar hanya bermakna bila ada video yang bisa diputar.
    final canPlay = !locked &&
        detail != null &&
        detail.videoUrl.trim().isNotEmpty;
    // Blok judul pola referensi: "Ep. N | [Judul Series] >" (ketuk →
    // detail series). Judul series dari API; bila belum ada, hanya
    // "Ep. N" (bukan judul karangan).
    final titleLine = seriesTitle != null && seriesTitle.isNotEmpty
        ? 'Ep. ${episode.number} | $seriesTitle >'
        : 'Ep. ${episode.number}';
    final description = detail?.description ?? episode.description;
    final showExpand = description.length > 120;
    final total = seriesEpisodes.length;
    // Status gratis JUJUR: "Gratis Semua" HANYA bila episode gratis
    // >= total episode; bila tidak, jumlah gratis sebenarnya.
    final freeText = total > 0 && freeEpisodeCount >= total
        ? 'Gratis Semua'
        : '$freeEpisodeCount Ep gratis';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: _openSeriesDetail,
            child: Text(
              titleLine,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: _descriptionExpanded ? null : 2,
            overflow: _descriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          if (showExpand)
            TextButton(
              onPressed: () => setState(
                () => _descriptionExpanded = !_descriptionExpanded,
              ),
              child: Text(
                _descriptionExpanded ? 'Sembunyikan' : 'Selengkapnya',
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: Tooltip(
                  message: 'Sebelumnya',
                  child: OutlinedButton(
                    style: const ButtonStyle(
                      padding: WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    onPressed: previousId == null
                        ? null
                        : () => _switchTo(previousId),
                    // Ikon + label satu baris (FittedBox mengecilkan
                    // label, bukan wrap tengah kata). Ikon tidak pernah
                    // mengecil — label yang menyesuaikan.
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.skip_previous, size: 20),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Sebelumnya',
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tooltip(
                  message: locked
                      ? 'Terkunci'
                      : (_isPlaying ? 'Jeda' : 'Putar'),
                  child: ElevatedButton(
                    style: const ButtonStyle(
                      padding: WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    onPressed: !canPlay
                        ? null
                        : () => _playRequest.value = !_isPlaying,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          locked
                              ? Icons.lock
                              : (_isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow),
                          size: 22,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              locked
                                  ? 'Terkunci'
                                  : (_isPlaying ? 'Jeda' : 'Putar'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tooltip(
                  message: 'Berikutnya',
                  child: OutlinedButton(
                    style: const ButtonStyle(
                      padding: WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    onPressed:
                        nextId == null ? null : () => _switchTo(nextId),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Berikutnya',
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.skip_next, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Baris bawah pola referensi: "Total N Ep · [status gratis] >"
          // (ketuk → bottom sheet Daftar Episode). Hanya bila daftar
          // episode series sudah dimuat (angka dari API, bukan karangan).
          if (seriesEpisodes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showEpisodeList(seriesEpisodes, seriesId),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Total $total Ep · $freeText >',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Video diputar dari tautan episode (file video langsung '
            'atau HLS). Tautan halaman web tidak dapat diputar di sini.',
            style: Theme.of(context).textTheme.bodySmall,
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
      key: ValueKey<int>(_seriesId),
      create: (_) => SeriesDetailBloc(context.read<SeriesRepository>())
        ..add(SeriesDetailStarted(_seriesId)),
      child: BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          final unlockedId = state.lastUnlockedId;
          if (_pendingUnlockId != null &&
              unlockedId == _pendingUnlockId &&
              _lastUnlockShown != unlockedId) {
            _lastUnlockShown = unlockedId;
            setState(() {
              _pendingUnlockId = null;
            });
            // Status kunci dibaca ulang dari server (bukan ditandai
            // lokal): bila server masih mengunci, gembok tetap tampil.
            context.read<SeriesDetailBloc>().add(
                  SeriesDetailStarted(_seriesId),
                );
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
            // Episode feed hanya untuk data tampilan (suka/simpan sesi).
            // Daftar + navigasi episode TIDAK dari sini: feed bersifat
            // global (semua series) dan bisa basi.
            final feedEpisode =
                _currentEpisode(_sortedEpisodes(feedState.episodes));
            return BlocBuilder<SeriesDetailBloc, SeriesDetailState>(
              builder: (context, detailState) {
                // Status kunci tidak bisa diverifikasi bila detail gagal
                // dimuat — jangan diam-diam memutar episode yang mungkin
                // terkunci: tampilkan error asli + Coba Lagi.
                if (detailState.errorMessage != null &&
                    detailState.detail == null) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(
                        'Episode ${feedEpisode?.number ?? ''}',
                      ),
                    ),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.cloud_off, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              detailState.errorMessage!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context
                                  .read<SeriesDetailBloc>()
                                  .add(
                                    SeriesDetailStarted(_seriesId),
                                  ),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final detailByNumber = <int, SeriesEpisode>{
                  for (final item
                      in detailState.detail?.episodes ?? <SeriesEpisode>[])
                    item.number: item,
                };
                // Daftar episode series aktif — dari detail API saja.
                final seriesEpisodes = _sortedUniqueSeriesEpisodes(
                  detailState.detail?.episodes ?? <SeriesEpisode>[],
                );
                final apiId = _parseApiEpisodeId(_currentId);
                SeriesEpisode? currentDetail;
                for (final item in seriesEpisodes) {
                  if (apiId != null && item.id == apiId) {
                    currentDetail = item;
                    break;
                  }
                }
                final series = detailState.detail?.series;
                final episode = feedEpisode ??
                    (currentDetail != null && series != null
                        ? _episodeFromDetail(currentDetail, series)
                        : null);
                if (episode == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Player')),
                    body: const Center(
                      child: Text('Episode tidak ditemukan.'),
                    ),
                  );
                }
                final detail = detailByNumber[episode.number];
                final locked = detail != null &&
                    detail.locked &&
                    !wallet.vip.isActive;
                final lockedDetail = locked ? detail : null;
                // Navigasi Sebelumnya/Berikutnya HANYA di dalam series
                // aktif (bukan feed global).
                final currentDetailId = currentDetail?.id;
                final currentIndex = currentDetailId == null
                    ? -1
                    : seriesEpisodes.indexWhere(
                        (item) => item.id == currentDetailId,
                      );
                final String? previousId = currentIndex > 0
                    ? 's$_seriesId'
                        'e${seriesEpisodes[currentIndex - 1].id}'
                    : null;
                final String? nextId =
                    currentIndex >= 0 &&
                            currentIndex < seriesEpisodes.length - 1
                        ? 's$_seriesId'
                            'e${seriesEpisodes[currentIndex + 1].id}'
                        : null;
                // Tercatat ke riwayat saat episode terbuka untuk ditonton
                // (bukan saat masih terkunci di balik gembok) dan hanya
                // bila detail series dari API tersedia (judul series
                // harus dari server, bukan default karangan).
                final seriesTitle = detailState.detail?.series.title;
                if (!locked && seriesTitle != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _recordCurrent(episode, seriesTitle);
                    }
                  });
                }
                // Subtitle: ambil sekali per URL subtitle baru (di
                // luar build lewat post-frame agar tidak setState saat
                // build).
                final subtitleUrl = detail?.subtitleUrl;
                if (subtitleUrl != null &&
                    subtitleUrl.isNotEmpty &&
                    _subtitleUrlFetched != subtitleUrl) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _subtitleUrlFetched != subtitleUrl) {
                      _subtitleUrlFetched = subtitleUrl;
                      _fetchSubtitles(subtitleUrl);
                    }
                  });
                }
                final chromeVisible = _chromeVisible && !_fullscreen;
                return Scaffold(
                  body: SafeArea(
                    child: Column(
                      children: <Widget>[
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: chromeVisible
                              ? Column(
                                  children: <Widget>[
                                    _headerRow(
                                      episode,
                                      seriesEpisodes,
                                      _seriesId,
                                    ),
                                    // Tombol "Layar Penuh" di atas video.
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: _toggleFullscreen,
                                        icon: const Icon(Icons.fullscreen),
                                        label:
                                            const Text('Layar Penuh'),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        Expanded(
                          flex: 5,
                          child: _videoArea(
                            locked,
                            lockedDetail,
                            detail,
                            detailState.detail == null &&
                                detailState.errorMessage == null,
                            detailState.detail?.series.coverUrl ?? '',
                            episode,
                          ),
                        ),
                        if (chromeVisible)
                          Expanded(
                            flex: 4,
                            child: _infoSection(
                              episode,
                              previousId,
                              nextId,
                              locked,
                              seriesEpisodes,
                              _seriesId,
                              detail,
                              seriesTitle,
                              detailState.detail?.series.freeEpisodeCount ??
                                  0,
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
