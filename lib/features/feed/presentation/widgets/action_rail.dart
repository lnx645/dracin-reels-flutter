import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_count.dart';
import '../../domain/entities/episode.dart';

/// Satu tombol aksi di rel kanan: ikon lingkaran + angka di bawahnya.
class _RailButton extends StatelessWidget {
  const _RailButton({
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            color: Color(0x33000000),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: active ? AppColors.accent : Colors.white,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class ActionRail extends StatelessWidget {
  const ActionRail({
    required this.episode,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
    super.key,
  });

  final Episode episode;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _RailButton(
          icon: episode.isLiked ? Icons.favorite : Icons.favorite_border,
          label: formatCount(episode.likes),
          onPressed: onLike,
          active: episode.isLiked,
        ),
        const SizedBox(height: 16),
        _RailButton(
          icon: Icons.chat_bubble_outline,
          label: formatCount(episode.comments),
          onPressed: onComment,
        ),
        const SizedBox(height: 16),
        _RailButton(
          icon: Icons.share,
          label: formatCount(episode.shares),
          onPressed: onShare,
        ),
        const SizedBox(height: 16),
        _RailButton(
          icon: episode.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          label: 'Simpan',
          onPressed: onBookmark,
          active: episode.isBookmarked,
        ),
      ],
    );
  }
}
