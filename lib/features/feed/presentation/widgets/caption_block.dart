import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/episode.dart';

/// Caption bawah: judul, deskripsi, tagar, tombol Tonton + Daftar.
/// Feed hanya browsing: Tonton membuka halaman Player khusus.
class CaptionBlock extends StatelessWidget {
  const CaptionBlock({
    required this.episode,
    required this.onWatch,
    required this.onShowEpisodes,
    super.key,
  });

  final Episode episode;

  /// Buka halaman Player untuk episode ini.
  final VoidCallback onWatch;
  final VoidCallback onShowEpisodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          episode.title,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          episode.description,
          style: theme.textTheme.bodyMedium,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          episode.hashtags.join(' '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            ElevatedButton(
              onPressed: onWatch,
              child: const Text('Tonton'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onShowEpisodes,
              child: const Text('Daftar Episode'),
            ),
          ],
        ),
      ],
    );
  }
}
