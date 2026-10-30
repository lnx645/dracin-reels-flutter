import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api/api_client.dart';

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
class VideoPlayerArea extends StatefulWidget {
  const VideoPlayerArea({
    required this.videoUrl,
    required this.playRequest,
    required this.onPlayingChanged,
    this.localFile,
    this.posterUrl = '',
    super.key,
  });

  /// `video_url` mentah dari API (boleh relatif atau absolut).
  final String videoUrl;

  /// File lokal yang baru dipilih (pratinjau formulir admin, sebelum
  /// diunggah). Bila ada, file inilah yang diputar, bukan [videoUrl].
  final File? localFile;

  /// Poster (cover series) yang tampil sebelum video mulai diputar —
  /// aturan fallback thumbnail: sebelum frame pertama, area Player
  /// memakai cover series, bukan hitam kosong. Hilang begitu video
  /// benar-benar memutar; tidak pernah menutupi video yang jalan.
  final String posterUrl;

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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _lastReportedPlaying = false;

  String get _resolvedUrl => resolveMediaUrl(widget.videoUrl);

  @override
  void initState() {
    super.initState();
    widget.playRequest.addListener(_onPlayRequest);
    _initController();
  }

  @override
  void didUpdateWidget(VideoPlayerArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.localFile?.path != widget.localFile?.path) {
      _initController();
    }
  }

  @override
  void dispose() {
    widget.playRequest.removeListener(_onPlayRequest);
    _disposeController();
    super.dispose();
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

  Future<void> _initController() async {
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
      });
    }
    try {
      await controller.initialize();
    } on Exception catch (error) {
      // Init gagal (URL stub, tautan halaman web, jaringan): error asli,
      // bukan crash dan bukan placeholder gerak.
      if (!mounted || _controller != controller) {
        return;
      }
      setState(() {
        _initializing = false;
        _error = 'Gagal memutar video: $error';
      });
      return;
    }
    if (!mounted || _controller != controller) {
      return;
    }
    setState(() {
      _initializing = false;
      _duration = controller.value.duration;
    });
    if (widget.playRequest.value) {
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
      final message = value.errorDescription ?? 'Gagal memutar video.';
      if (_error != message) {
        setState(() => _error = message);
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
    if (position.inSeconds != _position.inSeconds ||
        duration.inSeconds != _duration.inSeconds) {
      setState(() {
        _position = position;
        _duration = duration;
      });
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
                  onPressed: _initController,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat video…', style: TextStyle(color: Colors.white)),
            ],
          ),
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
                child: controller.value.isPlaying
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      value: durationMs == 0 ? 0 : positionMs.toDouble(),
                      max: durationMs == 0 ? 1 : durationMs.toDouble(),
                      onChanged: durationMs == 0
                          ? null
                          : (value) => controller.seekTo(
                                Duration(milliseconds: value.round()),
                              ),
                    ),
                  ),
                  Text(
                    '${_formatDuration(_position)} / '
                    '${_formatDuration(_duration)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
