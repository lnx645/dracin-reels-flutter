import 'package:flutter/material.dart';

import '../../domain/entities/episode.dart';

/// Placeholder area video: gradasi + judul + ikon putar/jeda.
/// VIDEO BELUM MEMUTAR — ini UI saja, dinyatakan jujur di README.
class EpisodeCover extends StatelessWidget {
  const EpisodeCover({
    required this.episode,
    required this.isPlaying,
    this.bottomPadding = 0,
    super.key,
  });

  final Episode episode;
  final bool isPlaying;

  /// Ruang kosong di bawah konten terpusat (dipakai feed untuk
  /// mencadangkan zona caption, supaya label episode tidak menimpa
  /// deskripsi).
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: episode.gradient.map(Color.new).toList(),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0x33000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Episode ${episode.number}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
