import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets.dart';
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
  bool _unwatchedFailed = false;

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
    var failed = false;
    for (final seriesId in seriesIds) {
      try {
        final detail = await repository.getSeriesDetail(seriesId);
        for (final episode in detail.episodes) {
          if (!watchedIds.contains(episode.id)) {
            unwatched.add(episode);
          }
        }
      } on Exception {
        // Series yang gagal dimuat dicatat (bukan disembunyikan):
        // daftar riwayat tetap tampil + catatan gagal di bawah.
        failed = true;
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
      _unwatchedFailed = failed;
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
    Navigator.of(context).pop();
    widget.onOpenEpisode('s${entry.seriesId}e${entry.episodeId}');
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
    if (!episode.locked) {
      Navigator.of(context).pop();
      widget.onOpenEpisode('s${episode.seriesId}e${episode.id}');
      return;
    }
    _openSeriesDetail(episode.seriesId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const DracinAppBar(title: 'Riwayat Tonton'),
      body: SafeArea(
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, state) {
            final history = state.historyItems;
            if (state.errorMessage != null) {
              return DracinErrorState(
                message: state.errorMessage!,
                onRetry: () => context
                    .read<WalletBloc>()
                    .add(const WalletRefreshed()),
              );
            }
            if (!state.loggedIn) {
              return DracinEmptyState(
                icon: Icons.history,
                message: 'Masuk untuk melihat riwayat.\n'
                    'Riwayat tonton tersimpan di server untuk akun Anda.',
                actionLabel: 'Masuk',
                onAction: () {
                  Navigator.of(context).pushNamed('/login');
                },
              );
            }
            if (history.isEmpty) {
              return const DracinEmptyState(
                icon: Icons.history,
                message: 'Belum ada riwayat.\n'
                    'Episode yang Anda buka akan tercatat di sini '
                    'secara otomatis.',
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
                  const DracinRowSkeleton()
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
                if (_unwatchedFailed)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Sebagian episode lanjutan gagal dimuat dari '
                      'server.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Riwayat dari server (akun Anda). Ketuk episode '
                  'untuk melanjutkan dari posisi tersimpan.',
                  style: theme.textTheme.bodySmall,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DracinCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
