import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/playback/playback_state.dart';

/// Video preview autoplay kartu Reels (gaya TikTok/Melolo).
///
/// Aturan yang dikunci (menghapus keadaan palsu "tombol play besar di
/// atas gradasi diam"):
/// - Hanya kartu AKTIF (isActive) yang punya controller — kartu yang
///   digeser menjauh langsung dispose (hemat RAM, maksimal 1 controller
///   aktif). Kartu tidak aktif = area hitam, tanpa ikon play.
/// - Suara MENYALA (volume 1.0) seperti TikTok.
/// - Init → spinner; gagal → error asli + "Coba Lagi" (re-init).
/// - Ikon play HANYA di atas frame video nyata saat jeda (controller
///   sudah init + tidak memutar), tidak pernah di atas placeholder.
/// - Ketuk = jeda/putar (jeda manual diingat sampai kartu aktif lagi).
/// - Rute tertutup (Player didorong di atas feed) → pause saja
///   (controller dipertahankan); kembali → lanjut otomatis bila tidak
///   dijeda manual.
/// - Episode terkunci / tanpa video_url tidak pernah membuat controller:
///   pemanggil menampilkan overlay kunci / state jujur, bukan widget ini.
class ReelVideo extends StatefulWidget {
  const ReelVideo({
    required this.videoUrl,
    required this.isActive,
    required this.isVisible,
    super.key,
  });

  /// `video_url` mentah dari API (boleh relatif media/... atau absolut).
  final String videoUrl;

  /// Kartu ini sedang tampil penuh di PageView.
  final bool isActive;

  /// Rute feed sedang di atas (false saat Player/detail didorong).
  final bool isVisible;

  @override
  State<ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends State<ReelVideo> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  String? _error;
  bool _isPlaying = false;
  bool _userPaused = false;
  int _initGen = 0;

  String get _resolvedUrl => resolveMediaUrl(widget.videoUrl);

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initController();
    }
  }

  @override
  void didUpdateWidget(ReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _userPaused = false;
      if (widget.isActive) {
        _initController();
      } else {
        _disposeController();
      }
      return;
    }
    if (!oldWidget.isActive && widget.isActive) {
      _userPaused = false;
      _initController();
    } else if (oldWidget.isActive && !widget.isActive) {
      // Digeser menjauh: pause + lepas controller (hemat RAM).
      _disposeController();
    } else if (oldWidget.isVisible && !widget.isVisible) {
      _pauseController();
    } else if (!oldWidget.isVisible &&
        widget.isVisible &&
        widget.isActive &&
        !_userPaused) {
      _playController();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _initGen++;
    final wasPlaying = _isPlaying;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    _initializing = false;
    _error = null;
    _isPlaying = false;
    // Kartu yang sedang memutar dibuang → tandai tidak ada yang
    // memutar (bila kartu lain mulai, ia menandainya lagi sendiri).
    if (wasPlaying) {
      playbackActive.value = false;
    }
  }

  Future<void> _initController() async {
    final gen = ++_initGen;
    _disposeControllerWithoutGenBump();
    final uri = Uri.tryParse(_resolvedUrl);
    if (uri == null || _resolvedUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Tautan video tidak valid.';
        });
      }
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_onControllerUpdate);
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      // Batas 90 detik seperti Player: preview yang stall tidak boleh
      // jadi spinner tanpa akhir (tetap jadi error + Coba Lagi).
      await controller.initialize().timeout(const Duration(seconds: 90));
    } catch (error) {
      // Ditangkap luas: kegagalan platform apa pun jadi error UI,
      // bukan crash async yang membekukan kartu.
      if (!mounted || gen != _initGen || _controller != controller) {
        return;
      }
      final message = error is TimeoutException
          ? 'Memuat preview terlalu lama (melebihi 90 detik).'
          : 'Gagal memutar preview: $error';
      setState(() {
        _initializing = false;
        _error = message;
      });
      return;
    }
    if (!mounted || gen != _initGen || _controller != controller) {
      return;
    }
    // Suara menyala seperti TikTok (bukan preview bisu).
    await controller.setVolume(1.0);
    // Await kedua: kartu bisa saja dibuang/digeser selama setVolume —
    // periksa lagi sebelum setState (setState setelah dispose = error).
    if (!mounted || gen != _initGen || _controller != controller) {
      return;
    }
    setState(() {
      _initializing = false;
    });
    if (widget.isActive && widget.isVisible && !_userPaused) {
      controller.play();
    }
  }

  /// Dispose tanpa menaikkan _initGen (dipakai di awal _initController
  /// yang sudah menaikkan generasi sendiri).
  void _disposeControllerWithoutGenBump() {
    final wasPlaying = _isPlaying;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    _initializing = false;
    _error = null;
    _isPlaying = false;
    if (wasPlaying) {
      playbackActive.value = false;
    }
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    if (controller.value.hasError) {
      final message =
          controller.value.errorDescription ?? 'Gagal memutar preview.';
      if (_error != message) {
        setState(() => _error = message);
      }
      return;
    }
    final playing = controller.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
    }
    // Gerbang updater: prompt instal tidak mengganggu saat preview
    // Reels sedang memutar (hanya kartu aktif + terlihat yang dihitung).
    playbackActive.value =
        playing && widget.isActive && widget.isVisible;
  }

  void _playController() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      controller.play();
    }
  }

  void _pauseController() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      controller.pause();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      _userPaused = true;
      controller.pause();
    } else {
      _userPaused = false;
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.cloud_off, size: 48, color: Colors.white70),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _initController,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          // Ikon play HANYA di atas frame nyata saat jeda.
          if (!_isPlaying)
            const Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.play_arrow,
                  size: 72,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
