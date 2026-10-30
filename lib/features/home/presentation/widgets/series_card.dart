import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/design/widgets.dart';
import '../../../series/domain/entities/series.dart';

/// Kartu series — desain yang sama dipakai di Beranda, halaman
/// "Tonton Semua", dan strip series Jelajahi: cover (foto dari API bila
/// ada, gradasi bila tidak ada/gagal), judul, deskripsi 2 baris,
/// tombol selebar kartu.
class SeriesCard extends StatelessWidget {
  const SeriesCard({required this.series, required this.onOpen, super.key});

  final Series series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = resolveMediaUrl(series.coverUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 110,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF3B1D5A), Color(0xFF0B0E14)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              if (coverUrl.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              if (coverUrl.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 56,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x00000000),
                          Color(0xAA000000),
                        ],
                      ),
                    ),
                  ),
                ),
              const Center(
                child: Icon(Icons.play_arrow, size: 36, color: Colors.white),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        series.rating.toStringAsFixed(1),
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Text(
                  '${series.totalEpisode} episode',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          series.title,
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          series.description,
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: DracinButton(
            label: 'Lihat',
            onPressed: onOpen,
          ),
        ),
      ],
    );
  }
}

/// Kartu series ringkas untuk strip horizontal: cover + judul overlay.
class SeriesMiniCard extends StatelessWidget {
  const SeriesMiniCard({required this.series, required this.onOpen, super.key});

  final Series series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = resolveMediaUrl(series.coverUrl);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF3B1D5A), Color(0xFF0B0E14)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: <Widget>[
            if (coverUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            if (coverUrl.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x00000000),
                        Color(0xAA000000),
                      ],
                    ),
                  ),
                ),
              ),
            const Center(
              child: Icon(Icons.play_arrow, size: 32, color: Colors.white),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      series.rating.toStringAsFixed(1),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                series.title,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
