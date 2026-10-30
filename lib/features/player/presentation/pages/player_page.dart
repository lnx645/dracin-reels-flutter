import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

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

  /// Status putar yang diminta untuk area video (ketuk video memutar /
  /// menjeda lewat controller; status tombol mengikuti controller).
  final ValueNotifier<bool> _playRequest = ValueNotifier<bool>(false);

  /// Permintaan seek dari Slider progress bawah (diteruskan ke area
  /// video; tiap nilai baru langsung di-seek).
  final ValueNotifier<Duration> _seekRequest =
      ValueNotifier<Duration>(Duration.zero);

  /// Durasi video aktif (dari controller, untuk Slider progress).
  Duration _videoDuration = Duration.zero;

  /// Rasio video aktif (lebar / tinggi, dari controller setelah init).
  /// Sebelum init = 9/16 (default reels): cover tampil besar vertikal,
  /// bukan strip kecil. Sesudah init = rasio asli file (portrait
  /// 9:16 tetap besar penuh lebar; landscape 16:9 lebar penuh).
  /// Di-reset tiap pindah episode agar episode baru tidak mewarisi
  /// kotak episode lama.
  double _videoAspectRatio = 9 / 16;

  /// Episode TERAKHIR series sudah selesai diputar (bukan mengulang
  /// diam-diam, bukan loading tanpa akhir): overlay status akhir.
  bool _ended = false;

  /// Info episode berikutnya yang dihitung di build (dipakai auto-next
  /// + prefetch; diperbarui tiap build, bukan sumber kebenaran sendiri).
  String? _latestNextId;
  bool _latestNextLocked = false;
  SeriesEpisode? _latestNextDetail;

  /// Prefetch episode berikutnya (init + buffer awal saja). Dibatalkan
  /// (dispose) saat pindah episode / keluar Player bila belum diklaim
  /// area video; bila sudah diklaim, area yang men-dispose-nya.
  PrewarmedController? _prewarm;
  String _prewarmUrl = '';

  int? _pendingUnlockId;
  int? _lastUnlockShown;
  String? _lastErrorShown;

  /// Episode yang sudah tercatat ke riwayat di sesi player ini.
  final Set<String> _recorded = <String>{};

  /// DUA STATE PLAYER (klarifikasi uwa):
  /// - PAUSE = kontrol: chrome lengkap sesuai GEOMETRI REFERENSI
  ///   (header kiri, video 16:9 full-width di tengah atas, pil
  ///   "Layar Penuh" di tengah bawah video, rel ikon rapat di kanan
  ///   video (tengah vertikal), judul + deskripsi, baris seek,
  ///   baris Total).
  ///   Play/pause HANYA lewat ketuk video (overlay play besar saat
  ///   pause); pindah episode HANYA lewat Daftar Episode (baris Total
  ///   / menu "...") — baris tombol Sebelumnya/Putar/Berikutnya
  ///   DIHAPUS atas perintah uwa.
  /// - PLAY = imersi: chrome menghilang (fade/collapse), tersisa video
  ///   + subtitle + progress tipis. Ketuk video saat play → pause +
  ///   chrome kembali; ketuk saat pause → play + chrome hilang
  ///   otomatis setelah ~3 detik (timer di-reset tiap interaksi).
  /// - AUTO-NEXT: video selesai → episode berikutnya dalam series
  ///   yang sama otomatis diputar; episode terkunci berikutnya tetap
  ///   menampilkan gembok (tidak auto-play); episode TERAKHIR selesai
  ///   → overlay status akhir (bukan ulang diam-diam).
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
    _seekRequest.dispose();
    // Keluar Player = prefetch dibatalkan (bila belum diklaim area).
    _disposePrewarm();
    // Pulihkan orientasi bila keluar halaman saat fullscreen aktif.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// Buang controller prefetch bila belum diklaim area video.
  void _disposePrewarm() {
    final prewarm = _prewarm;
    _prewarm = null;
    _prewarmUrl = '';
    if (prewarm != null && !prewarm.claimed) {
      prewarm.controller.dispose();
    }
  }

  /// Mulai prefetch episode berikutnya: init + buffer awal saja
  /// (ExoPlayer tidak mengunduh file penuh saat init). Hanya sekali
  /// per URL berikutnya, hanya bila berikutnya ada + tidak terkunci +
  /// punya URL yang bisa diputar. Dipicu saat episode aktif mulai
  /// memutar (buffer episode aktif sudah cukup, sisa bandwidth untuk
  /// berikutnya) — supaya auto-next tidak buffering dari nol.
  Future<void> _maybePrewarmNext() async {
    final next = _latestNextDetail;
    if (next == null || _latestNextLocked) {
      return;
    }
    final raw = next.hlsUrl.isNotEmpty ? next.hlsUrl : next.videoUrl;
    final resolved = resolveMediaUrl(raw);
    if (resolved.isEmpty || resolved == _prewarmUrl) {
      return;
    }
    _disposePrewarm();
    final uri = Uri.tryParse(resolved);
    if (uri == null) {
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    final prewarm = PrewarmedController(controller);
    _prewarm = prewarm;
    _prewarmUrl = resolved;
    try {
      await controller.initialize().timeout(const Duration(seconds: 90));
    } on Exception {
      // Prefetch gagal = tidak masalah: auto-next tetap jalan dengan
      // init biasa. Buang controller gagal bila belum diklaim.
      if (mounted && _prewarm == prewarm && !prewarm.claimed) {
        _disposePrewarm();
      }
      return;
    }
    if (!mounted || _prewarm != prewarm || prewarm.claimed) {
      return;
    }
    // Siap diklaim area video episode berikutnya saat auto-next /
    // pindah manual lewat Daftar Episode.
  }

  /// Video selesai: lanjut otomatis ke episode berikutnya (auto-play),
  /// kecuali berikutnya terkunci (pindah + tampil gembok, tanpa
  /// auto-play) atau ini episode terakhir (overlay status akhir).
  void _onVideoEnded() {
    if (!mounted) {
      return;
    }
    final nextId = _latestNextId;
    if (nextId != null) {
      _switchTo(nextId, autoPlay: !_latestNextLocked);
    } else if (!_ended) {
      setState(() => _ended = true);
    }
  }

  /// Putar ulang manual dari overlay akhir (satu-satunya pengulangan:
  /// atas ketukan pengguna, bukan otomatis).
  void _replayEnded() {
    setState(() => _ended = false);
    _seekRequest.value = Duration.zero;
    _playRequest.value = true;
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
      // Episode aktif jalan → mulai prefetch berikutnya.
      _maybePrewarmNext();
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

  void _onVideoDuration(Duration duration) {
    if (mounted) {
      setState(() => _videoDuration = duration);
    }
  }

  /// Rasio video dari controller (dipanggil area video sekali setelah
  /// init sukses / klaim prewarm). Ditunda ke post-frame karena area
  /// bisa melaporkannya dari dalam initState-nya (setState saat build
  /// induk berjalan = error Flutter). Nilai tidak waras diabaikan;
  /// nilai sama tidak memicu rebuild (hindari loop layout).
  void _onVideoAspectRatio(double aspect) {
    if (aspect <= 0.1 || aspect > 10) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_videoAspectRatio - aspect).abs() > 0.001) {
        setState(() => _videoAspectRatio = aspect);
      }
    });
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

  void _switchTo(String episodeId, {bool autoPlay = false}) {
    _hideTimer?.cancel();
    // Prefetch TIDAK dibuang di sini: bila pindah ke episode yang
    // memang di-prefetch (auto-next), area barulah yang mengklaimnya.
    // Prefetch basi dibersihkan di build (URL tidak cocok dengan
    // episode aktif/berikutnya yang baru).
    setState(() {
      _currentId = episodeId;
      _seriesId = _parseSeriesId(episodeId) ?? _seriesId;
      _isPlaying = false;
      // Episode baru = state PAUSE (chrome kembali) + posisi +
      // deskripsi + status akhir di-reset.
      _chromeVisible = true;
      _videoPosition = Duration.zero;
      _videoDuration = Duration.zero;
      _videoAspectRatio = 9 / 16;
      _descriptionExpanded = false;
      _ended = false;
    });
    // Pindah MANUAL tidak auto-memutar (pengguna mengetuk Daftar
    // Episode → ia yang mengetuk play). AUTO-NEXT memutar langsung.
    _playRequest.value = autoPlay;
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
    // Geometri referensi: "Ep. N" di KIRI tepat setelah tombol
    // kembali (bukan tengah), "..." di kanan.
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        Text(
          'Ep. ${episode.number}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
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
        // Judul untuk layar loading + tombol Kembali selama loading.
        title: detail.title.isNotEmpty
            ? 'Ep. ${detail.number} · ${detail.title}'
            : 'Ep. ${detail.number}',
        onRequestClose: () => Navigator.of(context).maybePop(),
        // HLS diutamakan bila backend menyediakannya (ABR ExoPlayer);
        // MP4 progresif hanya fallback.
        hlsUrl: detail.hlsUrl,
        playRequest: _playRequest,
        onPlayingChanged: _onPlayingChanged,
        posterUrl: coverUrl,
        // Portrait (PAUSE maupun PLAY fokus) = video bersih: kontrol
        // penuh HANYA di fullscreen (seek + posisi/durasi di sana).
        // PAUSE: progress + seek lewat Slider bawah (pola referensi);
        // PLAY fokus: progress tipis di tepi bawah video.
        showControls: _fullscreen,
        onPositionChanged: _onVideoPosition,
        onDurationChanged: _onVideoDuration,
        onAspectRatioChanged: _onVideoAspectRatio,
        onVideoEnded: _onVideoEnded,
        seekRequest: _seekRequest,
        // Prefetch HANYA bila URL-nya memang episode ini (bila tidak
        // cocok, area init biasa — controller orang lain tidak pernah
        // dipakai untuk episode yang salah).
        prewarmed: _prewarmUrl ==
                resolveMediaUrl(
                  detail.hlsUrl.isNotEmpty
                      ? detail.hlsUrl
                      : detail.videoUrl,
                )
            ? _prewarm
            : null,
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
    // Rel di DALAM area video, tengah vertikal (keluhan uwa:
    // rel di bawah video terlalu renggang + ikon terpotong tepi
    // bawah). Jarak antar ikon RAPAT dan konsisten (12px), tiap item
    // ikon saja (tanpa subteks — API tidak menyediakan angka nyata,
    // dan label kata panjang dilarang). Total tinggi rel (~174px)
    // proporsional dengan tinggi video 16:9 dan selalu muat penuh
    // karena terpusat di dalam kotak video, bukan menempel ke bawah
    // layar. Di PLAY fokus / fullscreen, rel hilang bersama chrome.
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
        if (railVisible)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            // Pengaman anti-potong terakhir: bila kotak video lebih
            // pendek dari tinggi alami rel (174px), ikon MENGECIL
            // proporsional (FittedBox scaleDown) — tidak pernah
            // terpotong tepi. Pada video normal (tinggi >= 174px)
            // scaleDown tidak mengubah apa-apa.
            child: LayoutBuilder(
              builder: (context, railConstraints) {
                return SizedBox(
                  width: 52,
                  height: railConstraints.maxHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                  _PlayerAction(
                    icon: episode.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    tooltip: 'Suka',
                    active: episode.isLiked,
                    onPressed: () {
                      _resetHideTimer();
                      _toggleLike(episode);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PlayerAction(
                    icon: Icons.chat_bubble_outline,
                    tooltip: 'Komentar',
                    onPressed: () {
                      _resetHideTimer();
                      _showComments(episode);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PlayerAction(
                    icon: episode.isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    tooltip: 'Simpan',
                    active: episode.isBookmarked,
                    onPressed: () {
                      _resetHideTimer();
                      _toggleBookmark(episode);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PlayerAction(
                    icon: Icons.share,
                    tooltip: 'Bagikan',
                    onPressed: () {
                      _resetHideTimer();
                      _showShareSheet();
                    },
                  ),
                      ],
                    ),
                  ),
                );
              },
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
            right: 16,
            // Portrait = video bersih (tanpa bar kontrol) → subtitle
            // dekat tepi bawah video; fullscreen = di atas bar kontrol.
            bottom: _fullscreen ? 64 : 16,
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

  /// Pil "Layar Penuh" pola referensi: di TENGAH bawah video (bukan
  /// teks oranye kanan atas), pil gelap + ikon + label.
  Widget _fullscreenPill() {
    return Center(
      child: InkWell(
        onTap: _toggleFullscreen,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF26262B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.fullscreen, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text('Layar Penuh', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  /// Kolom bawah state PAUSE (pola referensi): pil layar penuh,
  /// judul, deskripsi 1 baris + chevron expand, baris seek tipis
  /// NYATA (posisi/durasi controller), baris Total. Baris tombol
  /// Sebelumnya/Putar/
  /// Berikutnya DIHAPUS (perintah uwa: play/pause hanya ketuk video,
  /// pindah episode hanya lewat Daftar Episode). Catatan penjelasan
  /// permanen DIHAPUS — hanya tampil di error state area video.
  Widget _infoSection(
    Episode episode,
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
    final durationMs = _videoDuration.inMilliseconds;
    final positionMs =
        _videoPosition.inMilliseconds.clamp(0, durationMs);
    final content = <Widget>[
      InkWell(
        onTap: _openSeriesDetail,
        child: Text(
          titleLine,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: _descriptionExpanded ? null : 1,
              overflow: _descriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),
          if (showExpand)
            InkWell(
              onTap: () {
                _resetHideTimer();
                setState(
                  () => _descriptionExpanded = !_descriptionExpanded,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  _descriptionExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      // Progress NYATA dari controller (seekable): baris tipis
      // selebar layar seperti baris progress referensi (Slider
      // material setinggi 48px akan merusak geometri referensi, jadi
      // dipakai baris seek tipis buatan sendiri: ketuk/geser = seek).
      _SeekBar(
        fraction: durationMs == 0
            ? 0
            : (positionMs / durationMs).clamp(0.0, 1.0).toDouble(),
        enabled: canPlay && durationMs > 0,
        onSeek: (fraction) => _seekRequest.value = Duration(
          milliseconds: (fraction * durationMs).round(),
        ),
      ),
      // Baris bawah pola referensi: "Total N Ep · [status gratis] >"
      // (ketuk → bottom sheet Daftar Episode). Hanya bila daftar
      // episode series sudah dimuat (angka dari API, bukan karangan).
      if (seriesEpisodes.isNotEmpty)
        InkWell(
          onTap: () => _showEpisodeList(seriesEpisodes, seriesId),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                const Icon(Icons.list, size: 20),
                const SizedBox(width: 8),
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
        ),
    ];
    // Kolom konten saja (tanpa Spacer/scroll sendiri): area bawah di
    // build membungkusnya dengan scroll + gap tetap, jadi layar
    // pendek (16:9 lama) ikut aman — konten meluber = bisa di-scroll,
    // bukan error overflow merah.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
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
                // Episode berikutnya di dalam series aktif (untuk
                // auto-next + prefetch; bukan feed global).
                final currentDetailId = currentDetail?.id;
                final currentIndex = currentDetailId == null
                    ? -1
                    : seriesEpisodes.indexWhere(
                        (item) => item.id == currentDetailId,
                      );
                final hasNext = currentIndex >= 0 &&
                    currentIndex < seriesEpisodes.length - 1;
                final SeriesEpisode? nextDetail =
                    hasNext ? seriesEpisodes[currentIndex + 1] : null;
                final String? nextId = nextDetail == null
                    ? null
                    : 's$_seriesId' 'e${nextDetail.id}';
                final nextLocked = nextDetail != null &&
                    nextDetail.locked &&
                    !wallet.vip.isActive;
                _latestNextId = nextId;
                _latestNextLocked = nextLocked;
                _latestNextDetail = nextDetail;
                // Prefetch basi dibersihkan: hanya dipertahankan bila
                // URL-nya = episode aktif atau episode berikutnya
                // yang baru (bila sudah diklaim area, area pemiliknya).
                if (_prewarm != null && !_prewarm!.claimed) {
                  final currentUrl = detail == null
                      ? ''
                      : resolveMediaUrl(
                          detail.hlsUrl.isNotEmpty
                              ? detail.hlsUrl
                              : detail.videoUrl,
                        );
                  final nextUrl = nextDetail == null
                      ? ''
                      : resolveMediaUrl(
                          nextDetail.hlsUrl.isNotEmpty
                              ? nextDetail.hlsUrl
                              : nextDetail.videoUrl,
                        );
                  if (_prewarmUrl != currentUrl &&
                      _prewarmUrl != nextUrl) {
                    _disposePrewarm();
                  }
                }
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
                final videoWidget = _videoArea(
                  lockedDetail,
                  detail,
                  detailState.detail == null &&
                      detailState.errorMessage == null,
                  detailState.detail?.series.coverUrl ?? '',
                  episode,
                );
                // Overlay status akhir series (episode terakhir
                // selesai): bukan ulang diam-diam, bukan loading.
                final videoWithEnd = Stack(
                  children: <Widget>[
                    videoWidget,
                    if (_ended)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 56,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Episode terakhir sudah selesai '
                                    'diputar.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _showEpisodeList(
                                      seriesEpisodes,
                                      _seriesId,
                                    ),
                                    child: const Text('Daftar Episode'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _replayEnded,
                                    child: const Text('Putar Ulang'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
                // PLAY fokus / fullscreen = video saja (perilaku lama
                // yang dikunci: chrome hilang, fokus video).
                if (!chromeVisible) {
                  return Scaffold(
                    body: SafeArea(
                      child: Column(
                        children: <Widget>[
                          Expanded(child: videoWithEnd),
                        ],
                      ),
                    ),
                  );
                }
                // PAUSE = KOTAK VIDEO MENGIKUTI RASIO ASLI (dracin
                // itu reels): rasio dari controller setelah init
                // (default 9:16 sebelum init) — portrait tampil BESAR
                // penuh lebar (bukan strip kecil di kotak 16:9),
                // landscape lebar penuh; tanpa distorsi, tanpa bar
                // ganda (kotak luar dan AspectRatio dalam sama).
                // - LANDSCAPE: geometri referensi (persen tinggi
                //   layar, tangkapan 614x1280): header ~11%, video
                //   atas ~33,4% tinggi ~27%, pil tengah gap 2%,
                //   rel ikon di DALAM video tengah vertikal, judul
                //   ~81,7%, progress ~93%, Total ~94,1%.
                // - PORTRAIT: badan PAUSE bisa di-scroll (video
                //   natural + chrome mengalir di bawahnya).
                //
                // ANTI-POTONG (keluhan 12:53: pil terpotong setengah +
                // ikon share keluar layar): pil adalah anak Column
                // BIASA dengan tinggi tetap + margin jelas — bukan di
                // dalam Stack, bukan di dalam scroll view — sehingga
                // tidak mungkin tertumpuk/terpotong panel mana pun.
                // Bila ruang sempit (landscape), yang mengecil adalah
                // VIDEO (tinggi dihitung dari sisa ruang, dibatasi
                // lebar/rasio) dan yang menggeser adalah GAP (kaskade:
                // gap tengah, lalu gap pil→judul, lalu gap atas) — pil
                // TIDAK PERNAH dikorbankan. Blok info di bawah pil
                // adalah Expanded + scroll, sehingga ia yang meluap
                // (scroll), bukan pil.
                return Scaffold(
                  body: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availH = constraints.maxHeight;
                        final availW = constraints.maxWidth;
                        // Rasio video dari controller (default 9/16
                        // sebelum init). Kotak video MENGIKUTI rasio
                        // ini — bukan kotak tetap: portrait tampil
                        // besar penuh lebar, landscape lebar penuh.
                        final aspect = _videoAspectRatio;
                        final info = _infoSection(
                          episode,
                          locked,
                          seriesEpisodes,
                          _seriesId,
                          detail,
                          seriesTitle,
                          detailState.detail?.series.freeEpisodeCount ??
                              0,
                        );
                        if (aspect < 1.0) {
                          // PORTRAIT (reels): video natural penuh
                          // lebar (9:16 di layar 390px = 693px
                          // tinggi). Seluruh badan PAUSE bisa
                          // di-scroll: chrome mengalir di bawah video
                          // (pil, judul, progress) — semua ter-render
                          // penuh, tidak ada yang terpotong atau
                          // terjepit; yang bergeser hanya posisi
                          // scroll, bukan kotak video. Tanpa Expanded
                          // di dalam scroll (tinggi tak terbatas).
                          // AnimatedSize: perubahan ukuran sekali
                          // saat init selesai berjalan halus (300ms),
                          // bukan lompatan + tanpa frame kosong
                          // (poster tetap tampil selama transisi).
                          return SingleChildScrollView(
                            child: Column(
                              children: <Widget>[
                                SizedBox(height: availH * 0.02),
                                _headerRow(
                                  episode,
                                  seriesEpisodes,
                                  _seriesId,
                                ),
                                const SizedBox(height: 12),
                                AnimatedSize(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: SizedBox(
                                    width: availW,
                                    height: availW / aspect,
                                    child: videoWithEnd,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _fullscreenPill(),
                                const SizedBox(height: 16),
                                info,
                              ],
                            ),
                          );
                        }
                        // LANDSCAPE (16:9 dst.): geometri referensi
                        // (persen tinggi layar, diukur dari tangkapan
                        // 614x1280) + anti-potong 0.2.11: pil anak
                        // tetap Column, video mengecil bila sempit,
                        // info yang scroll — bukan pil yang dikorban.
                        // Cadangan tinggi tetap (header 48 + slack,
                        // pil 44 + slack — skala font besar ikut aman).
                        const headerReserve = 56.0;
                        const pillReserve = 48.0;
                        const infoMin = 120.0;
                        const railMinVideo = 180.0;
                        var gapTop = availH * 0.05;
                        var gapMid = availH * 0.197;
                        var gapPillTop = availH * 0.02;
                        var gapPillBottom = availH * 0.135;
                        double fixedSum() => gapTop +
                            headerReserve +
                            gapMid +
                            gapPillTop +
                            pillReserve +
                            gapPillBottom;
                        var videoH = availH - fixedSum() - infoMin;
                        // Kaskade penghematan bila video terlalu pendek
                        // untuk rel (rel butuh 180px): kecilkan gap
                        // tengah dulu, lalu gap pil→judul, lalu gap
                        // atas — pil dan video tidak dikorbankan.
                        if (videoH < railMinVideo) {
                          final deficit = railMinVideo - videoH;
                          final cutMid =
                              deficit < gapMid ? deficit : gapMid;
                          gapMid -= cutMid;
                          videoH = availH - fixedSum() - infoMin;
                        }
                        if (videoH < railMinVideo) {
                          final deficit = railMinVideo - videoH;
                          final cutBottom = deficit < gapPillBottom
                              ? deficit
                              : gapPillBottom;
                          gapPillBottom -= cutBottom;
                          videoH = availH - fixedSum() - infoMin;
                        }
                        if (videoH < railMinVideo) {
                          final deficit = railMinVideo - videoH;
                          final cutTop =
                              deficit < gapTop ? deficit : gapTop;
                          gapTop -= cutTop;
                          videoH = availH - fixedSum() - infoMin;
                        }
                        // Batas akhir: video selebar layar penuh bila
                        // muat (tinggi = lebar / rasio asli), mengecil
                        // bila sempit, tidak pernah negatif (sisa
                        // untuk info selalu >= 0 via Expanded).
                        videoH = videoH.clamp(0.0, availW / aspect);
                        return Column(
                          children: <Widget>[
                            SizedBox(height: gapTop),
                            _headerRow(
                              episode,
                              seriesEpisodes,
                              _seriesId,
                            ),
                            SizedBox(height: gapMid),
                            AnimatedSize(
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: SizedBox(
                                width: availW,
                                height: videoH,
                                child: videoWithEnd,
                              ),
                            ),
                            // Pil SELALU penuh: anak tetap Column di
                            // antara video dan info, margin jelas di
                            // kedua sisi, tidak di dalam Stack/scroll.
                            SizedBox(height: gapPillTop),
                            _fullscreenPill(),
                            SizedBox(height: gapPillBottom),
                            // Hanya blok info yang boleh scroll bila
                            // sempit — pil di atasnya tidak ikut geser.
                            Expanded(
                              child: SingleChildScrollView(
                                child: info,
                              ),
                            ),
                          ],
                        );
                      },
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

/// Baris seek tipis pola referensi (bukan Slider material 48px):
/// trek 4px + isi + thumb 12px; ketuk/geser di mana saja = seek.
/// Fraksi & status dari controller (nyata, bukan animasi).
class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.fraction,
    required this.enabled,
    required this.onSeek,
  });

  final double fraction;
  final bool enabled;
  final ValueChanged<double> onSeek;

  double _fractionFrom(Offset local, double width) {
    if (width <= 12) {
      return 0;
    }
    return ((local.dx - 6) / (width - 12)).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = width - 12;
        final thumbLeft = 6 + fraction * travel - 6;
        final color = enabled ? Colors.white : Colors.white38;
        return GestureDetector(
          onTapDown: enabled
              ? (details) =>
                  onSeek(_fractionFrom(details.localPosition, width))
              : null,
          onHorizontalDragUpdate: enabled
              ? (details) =>
                  onSeek(_fractionFrom(details.localPosition, width))
              : null,
          child: Container(
            height: 28,
            color: Colors.transparent,
            child: Stack(
              children: <Widget>[
                Center(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 4,
                      width: 6 + fraction * travel,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Satu aksi rel: IKON SAJA (pola referensi) — tanpa label kata,
/// tanpa angka. Tooltip menjaga aksesibilitas.
class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // Tombol ringkas 36px (ikon 28 + padding 2): total rel 4×36 +
    // 3×12 = 174px — muat penuh di dalam tinggi video 16:9 (203px
    // pada lebar 360) tanpa terpotong, dengan jarak antar ikon rapat
    // dan konsisten (12px, bukan renggang).
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        padding: const EdgeInsets.all(2),
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        icon: Icon(
          icon,
          size: 28,
          color: active ? AppColors.accent : Colors.white,
        ),
      ),
    );
  }
}
