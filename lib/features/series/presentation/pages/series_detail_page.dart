import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';
import '../bloc/series_bloc.dart';
import '../widgets/filter_chip.dart';
import 'series_detail_widgets.dart';

/// Halaman detail series ala aplikasi drama profesional:
/// cover + judul + genre + daftar episode bernomor.
/// Episode terkunci dibuka dengan koin (atau VIP aktif).
class SeriesDetailPage extends StatefulWidget {
  const SeriesDetailPage({
    required this.seriesId,
    required this.onOpenEpisode,
    super.key,
  });

  final int seriesId;

  /// Dibuka dengan id episode API (`s{seriesId}e{episodeId}`).
  final void Function(String episodeId) onOpenEpisode;

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  int? _pendingUnlockId;
  String? _lastErrorShown;
  int? _lastUnlockShown;

  String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  Future<void> _onEpisodeTap(
    BuildContext context,
    SeriesEpisode episode,
  ) async {
    final wallet = context.read<WalletBloc>().state;
    final unlocked = !episode.locked || wallet.vip.isActive;
    if (unlocked) {
      // Pop DULU lalu buka player (bukan sebaliknya, supaya pop tidak
      // menutup player yang baru dibuka). Player yang mencatat riwayat.
      Navigator.of(context).pop();
      widget.onOpenEpisode('s${widget.seriesId}e${episode.id}');
      return;
    }
    final session = context.read<SessionCubit>().state;
    if (!session.isAuthenticated) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Masuk dulu'),
          content: Text(
            'Episode ${episode.number} terkunci (${episode.coinPrice} '
            'koin). Masuk untuk membuka episode dengan koin atau VIP.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Masuk'),
            ),
          ],
        ),
      );
      if (goLogin == true && context.mounted) {
        await Navigator.of(context).pushNamed('/login');
      }
      return;
    }
    final int? balance = wallet.balance;
    if (balance == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo tidak dapat dimuat. Coba lagi.'),
          ),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Buka Episode ${episode.number}?'),
        content: Text(
          '${episode.title}\n\nHarga: ${episode.coinPrice} koin. '
          'Saldo Anda: $balance koin.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buka dengan Koin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    if (balance < episode.coinPrice) {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Koin tidak cukup'),
          content: Text(
            'Harga ${episode.coinPrice} koin, saldo Anda '
            '$balance koin. Klaim check-in harian untuk '
            'menambah koin.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushNamed('/rewards');
              },
              child: const Text('Ke Hadiah'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _pendingUnlockId = episode.id);
    context.read<WalletBloc>().add(
          WalletUnlockRequested(
            episodeId: episode.id,
            price: episode.coinPrice,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider(
      create: (_) => SeriesDetailBloc(context.read<SeriesRepository>())
        ..add(SeriesDetailStarted(widget.seriesId)),
      child: BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          final unlockedId = state.lastUnlockedId;
          if (_pendingUnlockId != null &&
              unlockedId == _pendingUnlockId &&
              _lastUnlockShown != unlockedId) {
            _lastUnlockShown = unlockedId;
            setState(() {
              _pendingUnlockId = null;
            });
            context.read<SeriesDetailBloc>().add(
                  SeriesDetailStarted(widget.seriesId),
                );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Episode terbuka!')),
            );
          }
          final error = state.errorMessage;
          if (_pendingUnlockId != null &&
              error != null &&
              error != _lastErrorShown) {
            _lastErrorShown = error;
            setState(() => _pendingUnlockId = null);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
        child: BlocBuilder<SeriesDetailBloc, SeriesDetailState>(
          builder: (context, state) {
            final detail = state.detail;
            if (state.errorMessage != null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Detail Series')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.cloud_off, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          state.errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<SeriesDetailBloc>()
                              .add(
                                SeriesDetailStarted(widget.seriesId),
                              ),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (state.isLoading || detail == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Detail Series')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final series = detail.series;
            return Scaffold(
              appBar: AppBar(title: Text(series.title)),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    SeriesCoverHeader(series: series),
                    const SizedBox(height: 16),
                    Text(series.title, style: theme.textTheme.titleLarge),
                    // Tagline (kontrak baru): di bawah judul, gaya kutipan
                    // italic. Kosong → baris disembunyikan, bukan teks
                    // contoh.
                    if (series.tagline.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '"${series.tagline.trim()}"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      series.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    if (series.genres.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: series.genres
                            .map(
                              (genre) =>
                                  SeriesDisplayChip(label: genre.name),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 8),
                    BlocBuilder<WalletBloc, WalletState>(
                      builder: (context, wallet) {
                        if (!wallet.vip.isActive) {
                          return const SizedBox.shrink();
                        }
                        return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Chip(
                            avatar: Icon(Icons.star, size: 16),
                            label: Text('VIP aktif — semua episode terbuka'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Daftar Episode (${detail.episodes.length})',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    ...detail.episodes.map((episode) {
                      final wallet =
                          context.read<WalletBloc>().state;
                      final unlocked = !episode.locked ||
                          wallet.vip.isActive;
                      return EpisodeRow(
                        episode: episode,
                        unlocked: unlocked,
                        durationLabel: _duration(episode.durationSeconds),
                        coverUrl: series.coverUrl,
                        onTap: () => _onEpisodeTap(context, episode),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      'Video diputar dari tautan episode (file video '
                      'langsung atau HLS). Tautan halaman web tidak dapat '
                      'diputar di sini.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
