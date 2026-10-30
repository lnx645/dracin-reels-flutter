import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets.dart';
import '../../domain/repositories/admin_panel_repository.dart';
import '../bloc/admin_panel_bloc.dart';
import 'admin_members_page.dart';
import 'admin_series_page.dart';
import 'admin_transactions_page.dart';
import 'admin_users_page.dart';

/// Dasbor khusus panel admin mobile (BUKAN web admin — tidak ada
/// web admin). Statistik + terbaru dari GET /admin/stats, navigasi
/// ke Kelola Pengguna / Member VIP / Transaksi Koin / Kelola Konten.
/// Gagal → error asli + Coba Lagi; 401/403 tampil apa adanya (akun
/// bukan admin tidak disembunyikan sebagai layar kosong).
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminDashboardCubit(
        context.read<AdminPanelRepository>(),
      )..load(),
      child: const _AdminDashboardView(),
    );
  }
}

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DracinAppBar(title: 'Panel Admin'),
      body: BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
        builder: (context, state) {
          if (state.errorMessage != null) {
            return DracinErrorState(
              message: state.errorMessage!,
              onRetry: () => context.read<AdminDashboardCubit>().load(),
            );
          }
          if (state.isLoading || state.stats == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const <Widget>[
                DracinRowSkeleton(),
                SizedBox(height: 12),
                DracinRowSkeleton(),
                SizedBox(height: 12),
                DracinRowSkeleton(),
              ],
            );
          }
          final stats = state.stats!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: <Widget>[
                  _StatCard(
                    label: 'Series',
                    value: '${stats.seriesCount}',
                    icon: Icons.movie,
                  ),
                  _StatCard(
                    label: 'Episode',
                    value: '${stats.episodeCount}',
                    icon: Icons.play_circle,
                  ),
                  _StatCard(
                    label: 'Pengguna',
                    value: '${stats.userCount}',
                    icon: Icons.people,
                  ),
                  _StatCard(
                    label: 'Member VIP Aktif',
                    value: '${stats.activeVipCount}',
                    icon: Icons.star,
                  ),
                  _StatCard(
                    label: 'Transaksi Koin',
                    value: '${stats.transactionCount}',
                    icon: Icons.monetization_on,
                  ),
                  _StatCard(
                    label: 'Transaksi Hari Ini',
                    value: '${stats.transactionsToday}',
                    icon: Icons.today,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const DracinSectionHeader(title: 'Kelola'),
              const SizedBox(height: 12),
              _NavTile(
                icon: Icons.people,
                label: 'Kelola Pengguna',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminUsersPage(),
                    ),
                  );
                },
              ),
              _NavTile(
                icon: Icons.star,
                label: 'Kelola Member VIP',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminMembersPage(),
                    ),
                  );
                },
              ),
              _NavTile(
                icon: Icons.monetization_on,
                label: 'Transaksi Koin',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminTransactionsPage(),
                    ),
                  );
                },
              ),
              _NavTile(
                icon: Icons.movie,
                label: 'Kelola Konten (Series & Episode)',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminSeriesPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const DracinSectionHeader(title: 'Series Terbaru'),
              const SizedBox(height: 12),
              if (stats.latestSeries.isEmpty)
                const Text('Belum ada series.')
              else
                for (final series in stats.latestSeries)
                  DracinCard(
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.movie, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(series.status),
                      ],
                    ),
                  ),
              const SizedBox(height: 24),
              const DracinSectionHeader(title: 'Episode Terbaru'),
              const SizedBox(height: 12),
              if (stats.latestEpisodes.isEmpty)
                const Text('Belum ada episode.')
              else
                for (final episode in stats.latestEpisodes)
                  DracinCard(
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.play_circle, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ep. ${episode.number} — ${episode.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          episode.seriesTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DracinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DracinCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
