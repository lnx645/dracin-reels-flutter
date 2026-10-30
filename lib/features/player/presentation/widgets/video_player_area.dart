import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api/api_client.dart';

/// Controller yang sudah di-init di latar untuk episode BERIKUTNYA
/// (prefetch auto-next). Pemiliknya (PlayerPage) membuat +
/// meng-init-nya; begitu area video episode itu dipasang, area
/// mengklaimnya (`claimed = true`) dan mengambil alih dispose.
/// Pemilik HANYA boleh dispose bila belum diklaim — jadi tidak pernah
/// ada dispose ganda. Prefetch hanya init + buffer awal ExoPlayer
/// (bukan unduh file penuh): cukup supaya auto-next tidak mulai
/// buffering dari nol di internet lambat.
class PrewarmedController {
  PrewarmedController(this.controller);

  final VideoPlayerController controller;

  bool claimed = false;

  bool get ready =>
      controller.value.isInitialized && !controller.value.hasError;
}

/// Format durasi `m:ss` (atau `h:mm:ss` bila ≥ 1 jam) untuk label posisi.
String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}

/// Area video beneran di halaman Player — SATU-SATUNYA tempat video
/// diputar (bukan di kartu feed). Memiliki controller sendiri:
/// init → loading, siap → video + kontrol, gagal → error asli + retry.
/// Ganti episode = widget baru (key per episode dari pemanggil) atau
/// `videoUrl` berubah → controller lama di-dispose, init ulang.
///
/// Pemutar pintar (internet jelek):
/// - HLS diutamakan bila [hlsUrl] ada (ABR ExoPlayer otomatis); MP4
///   progresif hanya fallback.
/// - Buffering DITUNJUKKAN nyata (persen buffer dari controller),
///   bukan spinner diam; init dibatasi timeout 90 detik.
/// - Jaringan putus DI TENGAH putar (controller pernah init sukses)
///   → coba lagi otomatis dengan backoff 2/4/8/16/16 detik (maks 5x)
///   dan lanjut dari posisi terakhir; gagal init dari awal → error
///   asli + Coba Lagi manual (tautan jelek tidak di-retry buta).
/// - Batas jujur: video_player TIDAK mengekspos cache ExoPlayer, jadi
///   cache segmen tidak bisa diaktifkan dari sini (butuh platform
///   code/fork di luar paket ini); yang dibangun sebagai gantinya
///   adalah prefetch buffer awal + lanjut posisi + retry backoff.
class VideoPlayerArea extends StatefulWidget {
  const VideoPlayerArea({
    required this.videoUrl,
    required this.playRequest,
    required this.onPlayingChanged,
    this.localFile,
    this.posterUrl = '',
    this.showControls = true,
    this.thinProgressOnly = false,
    this.onPositionChanged,
    this.onDurationChanged,
    this.onAspectRatioChanged,
    this.initialPosition,
    this.onVideoEnded,
    this.seekRequest,
    this.hlsUrl = '',
    this.prewarmed,
    this.title = '',
    this.onRequestClose,
    super.key,
  });

  /// `video_url` mentah dari API (boleh relatif atau absolut).
  final String videoUrl;

  /// `hls_url` mentah dari API ('' bila belum ada). Bila ada, URL
  /// inilah yang dipakai (bukan [videoUrl]).
  final String hlsUrl;

  /// Controller prefetch episode ini (bila sudah siap saat widget
  /// dipasang, dipakai langsung tanpa init ulang).
  final PrewarmedController? prewarmed;

  /// Permintaan seek dari luar (Slider progress induk): tiap nilai
  /// baru langsung di-seek oleh controller.
  final ValueNotifier<Duration>? seekRequest;

  /// File lokal yang baru dipilih (pratinjau formulir admin, sebelum
  /// diunggah). Bila ada, file inilah yang diputar, bukan [videoUrl].
  final File? localFile;

  /// Poster (cover series) yang tampil sebelum video mulai diputar —
  /// aturan fallback thumbnail: sebelum frame pertama, area Player
  /// memakai cover series, bukan hitam kosong. Hilang begitu video
  /// benar-benar memutar; tidak pernah menutupi video yang jalan.
  final String posterUrl;

  /// Bila false (state PLAY fokus), bar kontrol penuh diganti progress
  /// tipis — video tetap jalan, chrome disembunyikan.
  final bool showControls;

  /// Mode fokus/fullscreen video saja (perintah uwa): bar bawah
  /// BUKAN bar kontrol penuh (tombol + Slider + teks waktu), melainkan
  /// progress tipis YANG BISA DI-SEEK — ketuk/geser = seek, tanpa
  /// tombol apa pun. Dipakai PlayerPage saat fullscreen; pratinjau
  /// form tetap memakai showControls (bar penuh).
  final bool thinProgressOnly;

  /// Posisi putar terbaru (dilaporkan saat detik berubah — cukup untuk
  /// sinkronisasi subtitle; bukan setiap frame agar induk tidak
  /// rebuild berlebihan).
  final ValueChanged<Duration>? onPositionChanged;

  /// Durasi terbaru (dilaporkan saat detik berubah) — untuk Slider
  /// progress induk (posisi/durasi nyata dari controller).
  final ValueChanged<Duration>? onDurationChanged;

  /// Rasio video (lebar / tinggi) dari controller, dilaporkan SEKALI
  /// setelah init sukses / klaim prewarm — induk menyesuaikan ukuran
  /// kotak video ke rasio asli (portrait tidak lagi jadi strip kecil
  /// di dalam kotak 16:9). Null = induk tidak peduli (pratinjau form).
  final ValueChanged<double>? onAspectRatioChanged;

  /// Posisi lanjut episode ini (dari penyimpanan, bukan 0) — di-seek
  /// SEKALI sesudah init sukses (bila valid: > 0 dan > 10 detik
  /// sebelum akhir; posisi ujung = sudah habis → mulai dari 0).
  /// Tiba terlambat (sesudah init) tetap diterapkan lewat
  /// didUpdateWidget, kecuali pengguna sudah seek manual (niat
  /// pengguna menang). Null = mulai dari 0 (episode baru / auto-next).
  final Duration? initialPosition;

  /// Dipanggil SEKALI saat video mencapai akhir (untuk auto-next
  /// induk; episode terakhir ditangani induk sebagai status akhir).
  final VoidCallback? onVideoEnded;

  /// Judul episode untuk layar loading (bukan '') — supaya pengguna
  /// tahu video APA yang sedang dimuat, bukan menatap spinner kosong.
  final String title;

  /// Dipanggil tombol Kembali di layar loading (induk menutup Player).
  /// Bila null (mis. pratinjau formulir), tombol Kembali tidak tampil
  /// di area video — pratinjau bukan halaman yang bisa ditutup.
  final VoidCallback? onRequestClose;

  /// Status putar yang diminta tombol Putar/Jeda di luar area video
  /// (true = putar, false = jeda). Perubahan di sini memutar/menjeda
  /// controller; perubahan dari controller sendiri (mis. ketuk video)
  /// dilaporkan balik lewat [onPlayingChanged].
  final ValueNotifier<bool> playRequest;

  /// Dipanggil setiap kali status putar controller benar-benar berubah.
  final ValueChanged<bool> onPlayingChanged;

  @override
  State<VideoPlayerArea> createState() => _VideoPlayerAreaState();
}

class _VideoPlayerAreaState extends State<VideoPlayerArea> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  String? _error;

  /// Status retry otomatis (jaringan putus di tengah putar) — tampil
  /// sebagai chip, BUKAN layar error yang mematikan.
  String? _retryStatus;
  Timer? _retryTimer;
  int _retryGen = 0;
  int _autoRetryCount = 0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _bufferedFraction = 0;
  bool _isBufferingValue = false;

  /// Timer layar loading: detik berjalan + panel opsi lambat (>10 dtk).
  /// Berjalan HANYA selama init; berhenti saat init selesai/gagal.
  Timer? _loadingTimer;
  int _loadingElapsed = 0;
  bool _showSlowOptions = false;
  bool _slowDismissed = false;
  bool _lastReportedPlaying = false;
  bool _everInitialized = false;

  /// Seek posisi lanjut sudah diterapkan (sekali per controller).
  bool _initialSeekDone = false;

  /// Pengguna sudah seek manual (Slider / Putar Ulang) — posisi
  /// tersimpan yang tiba terlambat TIDAK BOLEH menimpanya.
  bool _manualSeekHappened = false;
  bool _endedReported = false;
  bool _resumeAfterRetry = false;
  Duration _lastPosition = Duration.zero;
  String _positionUrl = '';

  /// URL efektif yang sedang di-init (untuk reset state per-URL).
  String _initUrl = '';

  /// URL mentah yang dipakai: HLS dulu bila ada, MP4 bila tidak.
  String get _effectiveRawUrl =>
      widget.hlsUrl.isNotEmpty ? widget.hlsUrl : widget.videoUrl;

  String get _resolvedUrl => resolveMediaUrl(_effectiveRawUrl);

  @override
  void initState() {
    super.initState();
    widget.playRequest.addListener(_onPlayRequest);
    widget.seekRequest?.addListener(_onSeekRequest);
    final prewarmed = widget.prewarmed;
    if (prewarmed != null && !prewarmed.claimed && prewarmed.ready) {
      prewarmed.claimed = true;
      _adoptController(prewarmed.controller);
    } else {
      _initController();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.hlsUrl != widget.hlsUrl ||
        oldWidget.localFile?.path != widget.localFile?.path) {
      _initController();
    }
    // Posisi lanjut tiba terlambat (sesudah init): terapkan bila
    // controller sudah siap dan belum ada seek manual / seek awal.
    if (oldWidget.initialPosition != widget.initialPosition &&
        widget.initialPosition != null) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        _applyInitialSeek(controller);
      }
    }
  }

  /// Seek sekali ke posisi tersimpan episode ini (bila ada dan valid).
  /// Posisi dalam 10 detik terakhir durasi = episode sudah habis →
  /// tidak di-seek (mulai dari 0). Dipanggil sesudah init sukses,
  /// sesudah klaim prewarm, dan saat initialPosition tiba terlambat.
  Future<void> _applyInitialSeek(
    VideoPlayerController controller,
  ) async {
    if (_initialSeekDone || _manualSeekHappened) {
      return;
    }
    final resume = widget.initialPosition;
    if (resume == null || resume <= Duration.zero) {
      return;
    }
    final duration = controller.value.duration;
    if (duration <= Duration.zero) {
      return;
    }
    _initialSeekDone = true;
    if (resume < duration - const Duration(seconds: 10)) {
      await controller.seekTo(resume);
    }
  }

  @override
  void dispose() {
    widget.playRequest.removeListener(_onPlayRequest);
    widget.seekRequest?.removeListener(_onSeekRequest);
    _retryTimer?.cancel();
    _retryGen++;
    _stopLoadingTimer();
    _disposeController();
    super.dispose();
  }

  void _onSeekRequest() {
    final target = widget.seekRequest?.value;
    final controller = _controller;
    if (target == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    // Seek dari luar (Slider / Putar Ulang) = niat pengguna: posisi
    // tersimpan yang tiba terlambat tidak boleh menimpanya.
    _manualSeekHappened = true;
    controller.seekTo(target);
  }

  void _onPlayRequest() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      // Controller belum siap: saat init selesai, _initController
      // memeriksa playRequest dan memutar bila diminta.
      return;
    }
    if (widget.playRequest.value) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
  }

  /// Pakai controller prefetch yang sudah init (tanpa init ulang):
  /// posisi/durasi dibaca dari nilainya; putar bila diminta.
  void _adoptController(VideoPlayerController controller) {
    _controller = controller;
    controller.addListener(_onControllerUpdate);
    _initUrl = _resolvedUrl;
    _everInitialized = true;
    _endedReported = false;
    if (mounted) {
      setState(() {
        _initializing = false;
        _error = null;
        _retryStatus = null;
        _position = controller.value.position;
        _duration = controller.value.duration;
      });
    }
    // Controller prefetch sudah init: rasionya langsung diketahui.
    final aspect = controller.value.aspectRatio;
    if (aspect > 0) {
      widget.onAspectRatioChanged?.call(aspect);
    }
    // Lanjut posisi tersimpan dulu, baru putar (bila diminta) — agar
    // tidak sempat tampil frame 0 sebelum seek.
    _applyInitialSeek(controller).then((_) {
      if (widget.playRequest.value && _controller == controller) {
        controller.play();
      }
    });
  }

  /// Retry manual (tombol Coba Lagi): hitungan auto-retry di-reset dan
  /// video dimainkan lagi setelah init (niat pengguna jelas: putar).
  void _manualRetry() {
    _autoRetryCount = 0;
    _retryStatus = null;
    _resumeAfterRetry = true;
    _initController();
  }

  /// Timer detik loading: mulai tiap init, berhenti saat init selesai
  /// / gagal / widget dibuang. Lewat 10 detik → panel opsi lambat
  /// (Tetap menunggu / Coba lagi / Kembali), bukan spinner tanpa akhir.
  void _startLoadingTimer() {
    _stopLoadingTimer();
    _loadingElapsed = 0;
    _showSlowOptions = false;
    _slowDismissed = false;
    _loadingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopLoadingTimer();
        return;
      }
      if (!_initializing) {
        _stopLoadingTimer();
        return;
      }
      setState(() {
        _loadingElapsed++;
        if (_loadingElapsed >= 10 && !_slowDismissed) {
          _showSlowOptions = true;
        }
      });
    });
  }

  void _stopLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  /// Jadwalkan satu percobaan ulang dengan backoff 2/4/8/16/16 detik.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    const delays = <int>[2, 4, 8, 16, 16];
    final delay = delays[_autoRetryCount.clamp(0, delays.length - 1)];
    _autoRetryCount++;
    _resumeAfterRetry = _lastReportedPlaying;
    final gen = _retryGen;
    if (mounted) {
      setState(() {
        _retryStatus =
            'Jaringan putus, mencoba lagi… (percobaan $_autoRetryCount)';
      });
    }
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (!mounted || gen != _retryGen) {
        return;
      }
      _initController();
    });
  }

  Future<void> _initController() async {
    _retryTimer?.cancel();
    _disposeController();
    final localFile = widget.localFile;
    if (localFile == null && _resolvedUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = null;
        });
      }
      return;
    }
    // URL baru = state per-URL di-reset (posisi/retry/akhir).
    if (_resolvedUrl != _initUrl) {
      _initUrl = _resolvedUrl;
      _autoRetryCount = 0;
      _lastPosition = Duration.zero;
      _positionUrl = '';
      _everInitialized = false;
      _endedReported = false;
      _retryStatus = null;
      _retryGen++;
    }
    VideoPlayerController controller;
    if (localFile != null) {
      controller = VideoPlayerController.file(localFile);
    } else {
      final uri = Uri.tryParse(_resolvedUrl);
      if (uri == null) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = 'Tautan video tidak valid: $_resolvedUrl';
          });
        }
        return;
      }
      controller = VideoPlayerController.networkUrl(uri);
    }
    _controller = controller;
    controller.addListener(_onControllerUpdate);
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _bufferedFraction = 0;
      });
      _startLoadingTimer();
    }
    try {
      // Timeout: jangan pernah "Memuat video…" tanpa akhir. File
      // besar (kasus nyata 336 MB) tetap bisa init lewat progressive
      // download, tapi bila 90 detik belum ada frame pertama, itu
      // error yang harus terlihat + bisa di-retry — bukan spinner diam.
      await controller.initialize().timeout(const Duration(seconds: 90));
    } catch (error) {
      // Ditangkap luas (bukan hanya Exception): kegagalan init
      // platform apa pun harus jadi error UI + Coba Lagi, bukan
      // crash async yang membekukan halaman.
      // Init gagal (URL stub, tautan halaman web, jaringan, timeout):
      // error asli, bukan crash dan bukan placeholder gerak.
      if (!mounted || _controller != controller) {
        return;
      }
      final message = error is TimeoutException
          ? 'Memuat video terlalu lama (melebihi 90 detik). '
              'Periksa koneksi lalu coba lagi.'
          : 'Gagal memutar video: $error';
      setState(() {
        _initializing = false;
        _error = message;
      });
      _stopLoadingTimer();
      return;
    }
    if (!mounted || _controller != controller) {
      return;
    }
    final duration = controller.value.duration;
    setState(() {
      _initializing = false;
      _everInitialized = true;
      _retryStatus = null;
      _autoRetryCount = 0;
      _duration = duration;
    });
    _stopLoadingTimer();
    widget.onDurationChanged?.call(duration);
    // Rasio asli file — induk menyesuaikan kotak video (portrait
    // besar penuh lebar, landscape lebar penuh, tanpa bar ganda).
    final aspect = controller.value.aspectRatio;
    if (aspect > 0) {
      widget.onAspectRatioChanged?.call(aspect);
    }
    // Lanjut posisi tersimpan episode ini (bukan 0) — sekali saja.
    await _applyInitialSeek(controller);
    // Lanjut dari posisi terakhir (retry jaringan) bila masih valid.
    if (_positionUrl == _resolvedUrl &&
        _lastPosition > Duration.zero &&
        _lastPosition < duration) {
      await controller.seekTo(_lastPosition);
    }
    if (widget.playRequest.value || _resumeAfterRetry) {
      _resumeAfterRetry = false;
      controller.play();
    }
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final value = controller.value;
    if (value.hasError) {
      // Gagal DI TENGAH putar (pernah init sukses) = kemungkinan besar
      // jaringan putus → retry otomatis + lanjut posisi, bukan layar
      // error yang mematikan. Gagal init dari awal ditangani
      // _initController (error + Coba Lagi manual).
      if (_everInitialized && _autoRetryCount < 5) {
        _scheduleRetry();
      } else {
        final message = value.errorDescription ?? 'Gagal memutar video.';
        if (_error != message) {
          setState(() {
            _error = message;
            _retryStatus = null;
          });
        }
      }
      return;
    }
    final playing = value.isPlaying;
    if (playing != _lastReportedPlaying) {
      _lastReportedPlaying = playing;
      widget.onPlayingChanged(playing);
    }
    final position = value.position;
    final duration = value.duration;
    // Fraksi buffer NYATA dari controller (ujung buffer / durasi).
    var buffered = 0.0;
    if (duration > Duration.zero && value.buffered.isNotEmpty) {
      var endMs = 0;
      for (final range in value.buffered) {
        if (range.end.inMilliseconds > endMs) {
          endMs = range.end.inMilliseconds;
        }
      }
      buffered =
          (endMs / duration.inMilliseconds).clamp(0.0, 1.0).toDouble();
    }
    final bufferingChanged = value.isBuffering != _isBufferingValue;
    final oldPositionSec = _position.inSeconds;
    final oldDurationSec = _duration.inSeconds;
    if (position.inSeconds != oldPositionSec ||
        duration.inSeconds != oldDurationSec ||
        bufferingChanged ||
        (buffered - _bufferedFraction).abs() > 0.01) {
      setState(() {
        _position = position;
        _duration = duration;
        _bufferedFraction = buffered;
        _isBufferingValue = value.isBuffering;
        if (position > Duration.zero) {
          _lastPosition = position;
          _positionUrl = _resolvedUrl;
        }
      });
      if (position.inSeconds != oldPositionSec) {
        widget.onPositionChanged?.call(position);
      }
      if (duration.inSeconds != oldDurationSec) {
        widget.onDurationChanged?.call(duration);
      }
    }
    // Akhir video: SEKALI saja (flag di-reset tiap init baru).
    if (!_endedReported &&
        duration > Duration.zero &&
        position >= duration &&
        _everInitialized) {
      _endedReported = true;
      widget.onVideoEnded?.call();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedUrl.isEmpty && widget.localFile == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.videocam_off, size: 56, color: Colors.white70),
                SizedBox(height: 16),
                Text(
                  'Video belum tersedia untuk episode ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.cloud_off, size: 56, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _manualRetry,
                  child: const Text('Coba Lagi'),
                ),
                // Catatan ini HANYA tampil saat video benar-benar gagal
                // (bukan permanen di bawah Player): halaman web tidak
                // bisa diputar di sini, hanya file video langsung/HLS.
                const SizedBox(height: 16),
                const Text(
                  'Hanya file video langsung atau HLS yang bisa '
                  'diputar di sini; tautan halaman web tidak bisa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      // Layar loading TIDAK BOLEH hitam kosong: cover episode (atau
      // cover series bila thumbnail kosong — posterUrl sudah
      // mengikuti aturan fallback) sebagai latar + judul episode +
      // detik berjalan. Persen/MB buffer BELUM tersedia selama init
      // (controller belum punya nilai) — yang ditampilkan jujur
      // adalah detik berjalan + panel opsi lambat (>10 detik); persen
      // buffer nyata tampil sesudah init lewat chip buffering.
      // Selama init, video_player belum memberi angka buffer — angka
      // apa pun di sini akan karangan, jadi tidak dibuat.
      final loadingPoster = resolveMediaUrl(widget.posterUrl);
      final elapsedText = _loadingElapsed > 0
          ? 'Memuat video… $_loadingElapsed dtk'
          : 'Memuat video…';
      return Container(
        color: Colors.black,
        child: Stack(
          children: <Widget>[
            if (loadingPoster.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  loadingPoster,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.black),
                ),
              ),
            Positioned.fill(
              child: Container(color: Colors.black54),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    if (widget.title.isNotEmpty)
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (widget.title.isNotEmpty)
                      const SizedBox(height: 8),
                    Text(
                      elapsedText,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Koneksi lambat bisa membuat pemutaran lebih lama.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    // Panel opsi lambat (>10 detik): pengguna TIDAK
                    // PERNAH dijebak spinner tanpa akhir.
                    if (_showSlowOptions) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text(
                              'Memuat sudah lebih dari 10 detik.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => setState(() {
                                _showSlowOptions = false;
                                _slowDismissed = true;
                              }),
                              child: const Text('Tetap menunggu'),
                            ),
                            ElevatedButton(
                              onPressed: _manualRetry,
                              child: const Text('Coba lagi'),
                            ),
                            if (widget.onRequestClose != null)
                              TextButton(
                                onPressed: widget.onRequestClose,
                                child: const Text('Kembali'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Tombol Kembali SELALU terlihat selama loading (di atas
            // area video sendiri, tidak bergantung pada chrome header)
            // — keluar dari Player kapan saja, controller dilepas
            // bersih lewat dispose.
            if (widget.onRequestClose != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: 'Kembali',
                    onPressed: widget.onRequestClose,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final durationMs = _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds.clamp(0, durationMs);
    // Poster cover series: hanya sebelum video mulai (posisi 0 dan
    // belum memutar). Begitu video jalan, poster hilang; jeda di
    // tengah video menampilkan frame video, bukan poster.
    final resolvedPoster = resolveMediaUrl(widget.posterUrl);
    final showPoster = resolvedPoster.isNotEmpty &&
        !controller.value.isPlaying &&
        _position == Duration.zero;
    return Container(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (showPoster)
            Positioned.fill(
              child: Image.network(
                resolvedPoster,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlay,
              behavior: HitTestBehavior.translucent,
              child: Center(
                // Ikon play BESAR transparan tepat di tengah video
                // saat pause (pola referensi) — TIDAK PERNAH saat
                // sedang retry jaringan (chip retry yang tampil).
                child: controller.value.isPlaying ||
                        _retryStatus != null
                    ? const SizedBox.shrink()
                    : Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          // Chip retry otomatis (jaringan putus di tengah putar):
          // status jelas + spinner kecil, video tidak ditutup layar
          // error — begitu jaringan kembali, putar lanjut dari
          // posisi terakhir.
          if (_retryStatus != null)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _retryStatus!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Indikator buffering JUJUR (internet lambat): persen buffer
          // nyata dari controller + bar, bukan spinner diam dan bukan
          // ikon play palsu.
          if (controller.value.isBuffering && _duration > Duration.zero)
            Positioned(
              left: 16,
              right: 16,
              bottom: widget.showControls
                  ? 72
                  : (widget.thinProgressOnly ? 40 : 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Internet lambat, sedang memuat… '
                      '${(_bufferedFraction * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _bufferedFraction,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // State PLAY fokus: hanya progress tipis (posisi/durasi
            // nyata dari controller), tanpa tombol.
            // Mode fokus/fullscreen: progress tipis YANG BISA
            // DI-SEEK (bukan indikator mati) — satu-satunya kontrol
            // di mode video saja; ketuk video = jeda/putar.
            child: widget.thinProgressOnly
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: durationMs == 0 ? 0 : positionMs.toDouble(),
                      max: durationMs == 0 ? 1 : durationMs.toDouble(),
                      onChanged: durationMs == 0
                          ? null
                          : (value) {
                              // Seek eksplisit pengguna: posisi
                              // tersimpan yang tiba terlambat tidak
                              // boleh menimpanya.
                              _manualSeekHappened = true;
                              controller.seekTo(
                                Duration(milliseconds: value.round()),
                              );
                            },
                    ),
                  )
                : widget.showControls
                    ? Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: _togglePlay,
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value:
                                durationMs == 0 ? 0 : positionMs.toDouble(),
                            max: durationMs == 0
                                ? 1
                                : durationMs.toDouble(),
                            onChanged: durationMs == 0
                                ? null
                                : (value) => controller.seekTo(
                                      Duration(
                                        milliseconds: value.round(),
                                      ),
                                    ),
                          ),
                        ),
                        Text(
                          '${_formatDuration(_position)} / '
                          '${_formatDuration(_duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : LinearProgressIndicator(
                    value: durationMs == 0
                        ? 0
                        : positionMs / durationMs,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
