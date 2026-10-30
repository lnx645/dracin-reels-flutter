import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/pages/series_detail_page.dart';
import '../../../wallet/domain/entities/history.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';

/// Halaman Riwayat Tonton (dari Profil). DUA kelompok jelas, satu sumber
/// data dengan "Lanjutkan Nonton" (riwayat WalletBloc):
/// - "Sudah Ditonton": terbaru di atas, ketuk = tonton ulang.
/// - "Belum Ditonton": episode lanjutan series yang sama yang belum
///   ditonton; ketuk = tonton (atau detail bila masih terkunci).
class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<SeriesEpisode> _unwatched = <SeriesEpisode>[];
  bool _loadingUnwatched = true;

  @override
  void initState() {
    super.initState();
    _loadUnwatched();
  }

  Future<void> _loadUnwatched() async {
    final history = context.read<WalletBloc>().state.historyItems;
    final watchedIds = history.map((item) => item.episodeId).toSet();
    final seriesIds = history.map((item) => item.seriesId).toSet();
    final repository = context.read<SeriesRepository>();
    final unwatched = <SeriesEpisode>[];
    for (final seriesId in seriesIds) {
      try {
        final detail = await repository.getSeriesDetail(seriesId);
        for (final episode in detail.episodes) {
          if (!watchedIds.contains(episode.id)) {
            unwatched.add(episode);
          }
        }
      } on Exception {
        // Series yang gagal dimuat dilewati; riwayat tetap tampil.
        continue;
      }
    }
    unwatched.sort((a, b) {
      final bySeries = a.seriesId.compareTo(b.seriesId);
      if (bySeries != 0) {
        return bySeries;
      }
      return a.number.compareTo(b.number);
    });
    if (!mounted) {
      return;
    }
    setState(() {
      _unwatched = unwatched;
      _loadingUnwatched = false;
    });
  }

  String _positionLabel(HistoryEntry entry) {
    if (entry.finished) {
      return 'Selesai';
    }
    if (entry.positionSeconds <= 0) {
      return 'Baru mulai';
    }
    final minutes = entry.positionSeconds ~/ 60;
    final seconds = entry.positionSeconds % 60;
    return 'Lanjut $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _openWatched(HistoryEntry entry) {
    // Feed sampel hanya berisi series 1 (Qin); series lain dibuka
    // lewat halaman detailnya.
    if (entry.seriesId != 1) {
      _openSeriesDetail(entry.seriesId);
      return;
    }
    Navigator.of(context).pop();
    widget.onOpenEpisode('ep${entry.number}');
  }

  void _openSeriesDetail(int seriesId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeriesDetailPage(
          seriesId: seriesId,
          onOpenEpisode: (episodeId) {
            Navigator.of(context).pop();
            widget.onOpenEpisode(episodeId);
          },
        ),
      ),
    );
  }

  void _openUnwatched(SeriesEpisode episode) {
    if (!episode.locked && episode.seriesId == 1) {
      Navigator.of(context).pop();
      widget.onOpenEpisode('ep${episode.number}');
      return;
    }
    if (!episode.locked) {
      _openSeriesDetail(episode.seriesId);
      return;
    }
    _openSeriesDetail(episode.seriesId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Tonton')),
      body: SafeArea(
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, state) {
            final history = state.historyItems;
            if (history.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.history, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada riwayat',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Episode yang Anda buka akan tercatat di sini '
                        'secara otomatis.',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text('Sudah Ditonton', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                for (final entry in history)
                  _HistoryTile(
                    title: 'Episode ${entry.number} - ${entry.title}',
                    subtitle:
                        '${entry.seriesTitle} • ${_positionLabel(entry)}',
                    onTap: () => _openWatched(entry),
                  ),
                const SizedBox(height: 16),
                Text('Belum Ditonton', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                if (_loadingUnwatched)
                  const Center(child: CircularProgressIndicator())
                else if (_unwatched.isEmpty)
                  const Text(
                    'Semua episode series yang ditonton sudah habis.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  for (final episode in _unwatched)
                    _HistoryTile(
                      title:
                          'Episode ${episode.number} - ${episode.title}',
                      subtitle: episode.coinPrice <= 0
                          ? 'Gratis'
                          : '${episode.coinPrice} koin • Terkunci',
                      onTap: () => _openUnwatched(episode),
                    ),
                const SizedBox(height: 16),
                const Text(
                  'Riwayat tersimpan di perangkat ini. Bila masuk, '
                  'setiap tontonan juga dikirim ke server '
                  '(watch-progress). Video belum memutar — posisi '
                  'lanjut beneran aktif saat pemutar dipasang.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF3B1D5A), Color(0xFF0B0E14)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}
