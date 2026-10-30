import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets.dart';

/// Satu tile episode untuk grid Daftar Episode.
class EpisodeTileData {
  const EpisodeTileData({
    required this.id,
    required this.number,
    this.locked = false,
  });

  /// Id episode API (untuk ceklis tontonan + kunci).
  final int id;
  final int number;
  final bool locked;
}

/// Bottom sheet Daftar Episode pola referensi — dipakai feed DAN
/// tempat lain yang menampilkan daftar episode series (Player memakai
/// implementasi yang sama persis polanya di halamannya sendiri).
///
/// - Header: cover (atau ikon bila kosong) + judul series + ">" +
///   baris status ("Total N episode", tanpa klaim status bila tidak
///   diketahui).
/// - Tab rentang 30 episode hanya bila > 30 episode.
/// - Grid 5 kolom: nomor polos (belum ditonton), ceklis hijau (sudah
///   ditonton, dari WatchProgress API), sorotan oranye (sedang
///   diputar, bukan ceklis), gembok (terkunci — ketuk tetap memanggil
///   [onTapEpisode]; pemanggil yang menampilkan dialog buka kunci,
///   sheet tidak pernah memutar sendiri).
class EpisodeGridSheet extends StatefulWidget {
  const EpisodeGridSheet({
    required this.episodes,
    required this.seriesTitle,
    required this.statusLine,
    required this.coverUrl,
    required this.watchedIds,
    required this.onTapEpisode,
    this.currentKey,
    this.onTapSeries,
    super.key,
  });

  /// Episode series aktif saja (pemanggil yang memfilter + dedupe +
  /// urut nomor — sheet tidak pernah mencampur series lain).
  final List<EpisodeTileData> episodes;
  final String seriesTitle;
  final String statusLine;

  /// URL cover yang sudah di-resolve ('' = tanpa cover).
  final String coverUrl;

  /// Id episode API yang sudah ditonton (dari WatchProgress API).
  final Set<int> watchedIds;

  /// Kunci episode yang sedang diputar ('s{seriesId}e{episodeId}');
  /// null = tidak ada sorotan (mis. sheet dari feed).
  final String? currentKey;
  final void Function(EpisodeTileData episode) onTapEpisode;
  final VoidCallback? onTapSeries;

  @override
  State<EpisodeGridSheet> createState() => _EpisodeGridSheetState();
}

class _EpisodeGridSheetState extends State<EpisodeGridSheet> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final chunks = <List<EpisodeTileData>>[];
    for (var i = 0; i < widget.episodes.length; i += 30) {
      chunks.add(
        widget.episodes.sublist(
          i,
          (i + 30).clamp(0, widget.episodes.length),
        ),
      );
    }
    _tabIndex = _tabIndex.clamp(0, chunks.length - 1);
    final shown =
        chunks.isEmpty ? widget.episodes : chunks[_tabIndex];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: <Widget>[
          const SizedBox(height: DracinSpacing.md),
          const DracinSheetHandle(),
          const SizedBox(height: DracinSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DracinSpacing.lg,
            ),
            child: Row(
              children: <Widget>[
                if (widget.coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      DracinSpacing.radiusThumb,
                    ),
                    child: Image.network(
                      widget.coverUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: DracinColors.card,
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: DracinColors.card,
                      borderRadius: BorderRadius.circular(
                        DracinSpacing.radiusThumb,
                      ),
                    ),
                    child: const Icon(
                      Icons.movie,
                      color: Colors.white70,
                    ),
                  ),
                const SizedBox(width: DracinSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      GestureDetector(
                        onTap: widget.onTapSeries,
                        child: Text(
                          widget.seriesTitle.isEmpty
                              ? 'Series >'
                              : '${widget.seriesTitle} >',
                          style:
                              Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.statusLine,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (chunks.length > 1) ...<Widget>[
            const SizedBox(height: DracinSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: DracinSpacing.lg,
              ),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < chunks.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: DracinSpacing.sm,
                      ),
                      child: DracinChip(
                        label: '${chunks[i].first.number}-'
                            '${chunks[i].last.number}',
                        selected: i == _tabIndex,
                        onTap: () => setState(() => _tabIndex = i),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DracinSpacing.md),
          Expanded(
            child: GridView.count(
              crossAxisCount: 5,
              mainAxisSpacing: DracinSpacing.md,
              crossAxisSpacing: DracinSpacing.md,
              padding: const EdgeInsets.fromLTRB(
                DracinSpacing.lg,
                0,
                DracinSpacing.lg,
                DracinSpacing.lg,
              ),
              children: shown.map((episode) {
                final isCurrent = widget.currentKey != null &&
                    widget.currentKey!.endsWith('e${episode.id}');
                final isWatched =
                    widget.watchedIds.contains(episode.id);
                return Tooltip(
                  message: 'Episode ${episode.number}',
                  child: GestureDetector(
                    onTap: () => widget.onTapEpisode(episode),
                    child: Stack(
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? DracinColors.accent
                                : DracinColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? DracinColors.accent
                                  : DracinColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${episode.number}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        if (episode.locked)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.white70,
                            ),
                          )
                        else if (isWatched && !isCurrent)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.check_circle,
                              size: 14,
                              color: DracinColors.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
