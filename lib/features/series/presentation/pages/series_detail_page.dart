import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';
import '../bloc/series_bloc.dart';
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

  /// Dibuka dengan id sampel feed (`ep1`..`ep5`) sesuai nomor episode.
  final void Function(String episodeId) onOpenEpisode;

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  final Set<int> _localUnlocked = <int>{};
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
    final unlocked = !episode.locked ||
        _localUnlocked.contains(episode.id) ||
        wallet.vip.isActive;
    if (unlocked) {
      context.read<WalletBloc>().add(
            WalletContinueSaved(
              episodeId: episode.id,
              title: episode.title,
              number: episode.number,
            ),
          );
      widget.onOpenEpisode('ep${episode.number}');
      Navigator.of(context).pop();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Buka Episode ${episode.number}?'),
        content: Text(
          '${episode.title}\n\nHarga: ${episode.coinPrice} koin. '
          'Saldo Anda: ${wallet.balance} koin.',
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
    if (wallet.balance < episode.coinPrice) {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Koin tidak cukup'),
          content: Text(
            'Harga ${episode.coinPrice} koin, saldo Anda '
            '${wallet.balance} koin. Klaim check-in harian untuk '
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
              _localUnlocked.add(unlockedId!);
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
                    const SizedBox(height: 8),
                    Text(
                      series.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: series.genres
                          .map(
                            (genre) => Chip(label: Text(genre.name)),
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
                          _localUnlocked.contains(episode.id) ||
                          wallet.vip.isActive;
                      return EpisodeRow(
                        episode: episode,
                        unlocked: unlocked,
                        durationLabel: _duration(episode.durationSeconds),
                        onTap: () => _onEpisodeTap(context, episode),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Video belum memutar (UI saja). Area video pada '
                      'feed masih placeholder sampai pemutar beneran '
                      'dipasang.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
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
