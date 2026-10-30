import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/design/widgets.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../admin/presentation/pages/login_page.dart';
import '../../../bookmark/presentation/pages/bookmark_page.dart';
import '../../../history/presentation/pages/history_page.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/presentation/pages/series_detail_page.dart';
import '../../../update/presentation/cubit/update_cubit.dart';
import '../../../update/presentation/cubit/update_state.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/pages/rewards_page.dart';
import '../../../wallet/presentation/pages/vip_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    return ProfileView(onOpenEpisode: onOpenEpisode);
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
                        style: theme.textTheme.displayLarge,
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
                                : 'Belum masuk',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (session.isAuthenticated)
                      DracinButton(
                        label: 'Keluar',
                        variant: DracinButtonVariant.ghost,
                        onPressed: () {
                          context.read<SessionCubit>().logout();
                        },
                      )
                    else
                      DracinButton(
                        label: 'Masuk',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _Stat(
                      label: 'Koin',
                      value: wallet.balance?.toString() ?? '—',
                    ),
                    _BookmarkStat(),
                    _Stat(
                      label: 'Ditonton',
                      value: '${wallet.historyItems.length}',
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
                            DracinButton(
                              label: 'Tonton',
                              onPressed: () => onOpenEpisode(
                                's${continueItem.seriesId}'
                                'e${continueItem.episodeId}',
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        'Belum ada lanjutan. Buka episode untuk mulai '
                        'menonton.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: DracinButton(
                        label: 'Riwayat Tonton',
                        variant: DracinButtonVariant.ghost,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HistoryPage(
                                onOpenEpisode: onOpenEpisode,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: DracinButton(
                        label: 'Bookmark Saya',
                        variant: DracinButtonVariant.ghost,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BookmarkPage(
                                onOpenSeries: (seriesId) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SeriesDetailPage(
                                        seriesId: seriesId,
                                        onOpenEpisode: onOpenEpisode,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: DracinButton(
                        label: 'Dompet & Hadiah',
                        variant: DracinButtonVariant.ghost,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RewardsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: DracinButton(
                        label: 'VIP',
                        variant: DracinButtonVariant.ghost,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const VipPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    if (session.isAdmin) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: DracinButton(
                          label: 'Panel Admin',
                          icon: Icons.admin_panel_settings,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const AdminDashboardPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    // Label versi TERLIHAT — pembuktian APK mana yang
                    // terinstal (versi + build dari package_info_plus),
                    // supaya tidak lagi menebak "yang terbaru".
                    const SizedBox(height: 24),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        final info = snapshot.data!;
                        return Center(
                          child: Text(
                            'Versi ${info.version} '
                            '(build ${info.buildNumber})',
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                    // Tombol "Periksa Update": cek PAKSA sekarang tanpa
                    // peduli jeda 24 jam cek otomatis. Perbaikan keluhan
                    // "aplikasi terinstal kok gak ada dialog update":
                    // cek otomatis hanya sekali sehari, jadi rilis baru
                    // tidak memunculkan dialog sampai cek berikutnya.
                    // - Memeriksa → tombol nonaktif + "Memeriksa…".
                    // - Update tersedia → dialog (dari listener gate,
                    //   cubit yang sama).
                    // - Sudah terbaru → status di bawah tombol.
                    // - Gagal → snackbar (dari listener gate).
                    const SizedBox(height: 12),
                    BlocBuilder<UpdateCubit, UpdateState>(
                      builder: (context, updateState) {
                        final checking =
                            updateState is UpdateChecking;
                        return Center(
                          child: Column(
                            children: <Widget>[
                              DracinButton(
                                label: checking
                                    ? 'Memeriksa…'
                                    : 'Periksa Update',
                                icon: Icons.system_update,
                                isLoading: checking,
                                variant: DracinButtonVariant.ghost,
                                onPressed: checking
                                    ? null
                                    : () => context
                                        .read<UpdateCubit>()
                                        .checkNow(),
                              ),
                              if (updateState is UpdateUpToDate) ...<Widget>[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sudah versi terbaru.',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
      },
    );
  }
}

/// Jumlah bookmark dari API; '—' bila belum masuk atau gagal dimuat
/// (bukan angka contoh). Dimuat sekali saat widget dibuat (bukan tiap
/// rebuild) agar tidak menembak API berulang.
class _BookmarkStat extends StatefulWidget {
  const _BookmarkStat();

  @override
  State<_BookmarkStat> createState() => _BookmarkStatState();
}

class _BookmarkStatState extends State<_BookmarkStat> {
  late final Future<List<Series>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<WalletRepository>().getBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Series>>(
      future: _future,
      builder: (context, snapshot) {
        // '—' selama memuat, belum masuk, atau gagal dimuat —
        // bukan angka contoh.
        final String value =
            snapshot.hasData ? '${snapshot.data!.length}' : '—';
        return _Stat(label: 'Bookmark', value: value);
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
