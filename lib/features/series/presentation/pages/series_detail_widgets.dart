import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/series.dart';

/// Gradasi cadangan bila cover/thumbnail tidak ada atau gagal dimuat —
/// rapi bertitel/bernomor, bukan kotak kosong atau rusak.
class _GradientBox extends StatelessWidget {
  const _GradientBox({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3B1D5A), Color(0xFF0B0E14)],
        ),
      ),
      child: child,
    );
  }
}

/// Cover header detail series: foto cover dari API bila ada (URL relatif
/// di-resolve lewat basis media proxy), gradasi bila tidak ada/gagal.
/// Judul tetap terbaca lewat scrim bawah saat foto tampil.
class SeriesCoverHeader extends StatelessWidget {
  const SeriesCoverHeader({required this.series, super.key});

  final Series series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = resolveMediaUrl(series.coverUrl);
    return Container(
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: coverUrl.isEmpty
                ? const _GradientBox()
                : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _GradientBox(),
                  ),
          ),
          if (coverUrl.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 110,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x00000000),
                      Color(0xDD000000),
                    ],
                  ),
                ),
              ),
            ),
          // Badge rating: HANYA dari average_rating nyata (backend
          // rating). NULL = belum ada yang menilai → badge tidak
          // tampil sama sekali (bukan "0.0"). Kolom lama `rating`
          // tidak dipakai di sini.
          if (series.averageRating != null)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      series.averageRating!.toStringAsFixed(1),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  series.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${series.totalEpisode} episode • '
                  '${series.freeEpisodeCount} gratis',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris episode ala aplikasi drama profesional: nomor, judul
/// 1 baris + ellipsis, durasi, badge kanan yang sejajar.
class EpisodeRow extends StatelessWidget {
  const EpisodeRow({
    required this.episode,
    required this.unlocked,
    required this.durationLabel,
    required this.onTap,
    this.coverUrl = '',
    super.key,
  });

  final SeriesEpisode episode;
  final bool unlocked;
  final String durationLabel;
  final VoidCallback onTap;

  /// Cover series pemilik episode — dipakai sebagai thumbnail bila
  /// thumbnail episode null/kosong (aturan fallback yang dikunci).
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Aturan fallback thumbnail (dikunci): (1) thumbnail episode bila
    // ada (relatif media/... atau http, di-resolve lewat basis media);
    // (2) bila null/kosong → cover series; (3) bila keduanya tidak ada
    // atau gagal dimuat → placeholder gradasi rapi bertitel (angka
    // episode), bukan kotak kosong/rusak.
    final thumbnailSource = episode.thumbnailUrl.trim().isNotEmpty
        ? episode.thumbnailUrl
        : coverUrl;
    final thumbUrl = resolveMediaUrl(thumbnailSource);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: thumbUrl.isEmpty
                      ? _GradientBox(
                          child: Center(
                            child: Text(
                              '${episode.number}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        )
                      : Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _GradientBox(
                            child: Center(
                              child: Text(
                                '${episode.number}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      episode.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Durasi 0 = tidak diketahui (link eksternal tanpa
                    // probe): disembunyikan, bukan "0:00".
                    if (durationLabel.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        durationLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _EpisodeBadge(episode: episode, unlocked: unlocked),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeBadge extends StatelessWidget {
  const _EpisodeBadge({required this.episode, required this.unlocked});

  final SeriesEpisode episode;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (unlocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.play_circle_fill, color: AppColors.accent),
          const SizedBox(width: 4),
          Text('Buka', style: theme.textTheme.labelMedium),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.lock, size: 14),
          const SizedBox(width: 4),
          Text(
            '${episode.coinPrice} Koin',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
