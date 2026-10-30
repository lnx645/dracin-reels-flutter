import 'package:flutter/material.dart';

import '../../../../core/design/widgets.dart';
import '../../domain/entities/episode.dart';

/// Caption bawah: judul, deskripsi, tagar, tombol Tonton + Daftar.
/// Feed hanya browsing: Tonton membuka halaman Player khusus.
/// Deskripsi/tag kosong = TIDAK DIRIENDER (tinggi nol, tanpa gap) —
/// bukan Text('') + SizedBox yang menyisakan ruang kosong.
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
    final description = episode.description.trim();
    final hashtags = episode.hashtags.join(' ').trim();
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
        if (description.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (hashtags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            hashtags,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            DracinButton(label: 'Tonton', onPressed: onWatch),
            const SizedBox(width: 12),
            DracinButton(
              label: 'Daftar Episode',
              onPressed: onShowEpisodes,
              variant: DracinButtonVariant.ghost,
            ),
          ],
        ),
      ],
    );
  }
}
