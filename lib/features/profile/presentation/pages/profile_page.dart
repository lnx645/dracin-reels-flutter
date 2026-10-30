import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../admin/presentation/pages/admin_series_page.dart';
import '../../../admin/presentation/pages/login_page.dart';
import '../../../bookmark/presentation/pages/bookmark_page.dart';
import '../../../history/presentation/pages/history_page.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/pages/rewards_page.dart';
import '../../../wallet/presentation/pages/vip_page.dart';
import '../../domain/repositories/episode_repository.dart';
import '../bloc/profile_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileBloc(
        context.read<EpisodeRepository>(),
      )..add(const ProfileStarted()),
      child: ProfileView(onOpenEpisode: onOpenEpisode),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, wallet) {
        return BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            final session = context.watch<SessionCubit>().state;
            final continueItem = wallet.continueItems.isEmpty
                ? null
                : wallet.continueItems.first;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 36,
                          child: Text(
                            session.isAuthenticated &&
                                    (session.name ?? '').isNotEmpty
                                ? session.name![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                session.isAuthenticated
                                    ? (session.name ?? 'Pengguna Dracin')
                                    : 'Pengguna Dracin',
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                session.isAuthenticated
                                    ? '${session.email ?? ''} • '
                                        '${session.role ?? ''}'
                                    : 'Belum masuk (mode lokal)',
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (session.isAuthenticated)
                          OutlinedButton(
                            onPressed: () {
                              context.read<SessionCubit>().logout();
                            },
                            child: const Text('Keluar'),
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text('Masuk'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _Stat(label: 'Koin', value: '${wallet.balance}'),
                        _Stat(
                          label: 'Bookmark',
                          value: '${state.bookmarkCount}',
                        ),
                        _Stat(
                          label: 'Disukai',
                          value: '${state.likedCount}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Lanjutkan Nonton',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    if (continueItem != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFF3B1D5A),
                              Color(0xFF0B0E14),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Episode ${continueItem.number} - '
                                    '${continueItem.title}',
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    continueItem.finished
                                        ? 'Selesai'
                                        : continueItem.positionSeconds > 0
                                            ? 'Lanjut '
                                                '${continueItem.positionSeconds ~/ 60}'
                                                ':${(continueItem.positionSeconds % 60).toString().padLeft(2, '0')}'
                                            : 'Baru mulai',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => onOpenEpisode(
                                'ep${continueItem.number}',
                              ),
                              child: const Text('Tonton'),
                            ),
                          ],
                        ),
                      )
                    else if (state.continueEpisode != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: state.continueEpisode!.gradient
                                .map(Color.new)
                                .toList(),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Episode ${state.continueEpisode!.number} - '
                                    '${state.continueEpisode!.title}',
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    state.continueEpisode!.description,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => onOpenEpisode(
                                state.continueEpisode!.id,
                              ),
                              child: const Text('Tonton'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HistoryPage(
                                onOpenEpisode: onOpenEpisode,
                              ),
                            ),
                          );
                        },
                        child: const Text('Riwayat Tonton'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BookmarkPage(
                                onOpenEpisode: (episodeId) {
                                  Navigator.of(context).pop();
                                  onOpenEpisode(episodeId);
                                },
                              ),
                            ),
                          );
                        },
                        child: const Text('Bookmark Saya'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RewardsPage(),
                            ),
                          );
                        },
                        child: const Text('Dompet & Hadiah'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const VipPage(),
                            ),
                          );
                        },
                        child: const Text('VIP'),
                      ),
                    ),
                    if (session.isAdmin) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AdminSeriesPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text('Panel Admin'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
