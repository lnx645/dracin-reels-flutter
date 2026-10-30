import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_count.dart';
import '../../presentation/bloc/wallet_bloc.dart';
import 'vip_page.dart';

/// Halaman Dompet & Hadiah: saldo, check-in harian, tugas, paket koin.
/// Pembelian beneran BELUM ada — tombol beli menjelaskan itu, bukan
/// pura-pura memproses pembayaran.
class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  String? _lastMessage;

  void _showMessage(String message) {
    if (message == _lastMessage) {
      return;
    }
    _lastMessage = message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showPaymentLater() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pembayaran menyusul'),
        content: const Text(
          'Pembelian koin beneran belum tersedia. Paket di bawah ini '
          'hanya katalog. Koin saat ini didapat dari check-in harian '
          'dan tugas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.infoMessage != current.infoMessage,
      listener: (context, state) {
        final error = state.errorMessage;
        if (error != null) {
          _showMessage(error);
        }
        final info = state.infoMessage;
        if (info != null) {
          _showMessage(info);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Dompet & Hadiah')),
        body: SafeArea(
          child: BlocBuilder<WalletBloc, WalletState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  if (state.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => context
                                .read<WalletBloc>()
                                .add(const WalletRefreshed()),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.monetization_on,
                          color: AppColors.accent,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'SALDO KOIN',
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.balance == null
                                    ? '—'
                                    : '${state.balance}',
                                style: theme.textTheme.displayLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.loggedIn
                                    ? 'Saldo dari server'
                                    : 'Belum masuk — masuk untuk melihat saldo',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: state.isLoading
                              ? null
                              : () => context
                                  .read<WalletBloc>()
                                  .add(const WalletCheckinRequested()),
                          child: const Text('Check-in'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tugas Hadiah', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  if (state.tasks.isEmpty)
                    const Text(
                      'Belum ada tugas.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  for (final task in state.tasks)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  task.name,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${task.coinReward} koin • maks '
                                  '${task.dailyLimit}x/hari',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (task.type == 'checkin')
                            ElevatedButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () => context.read<WalletBloc>().add(
                                        const WalletCheckinRequested(),
                                      ),
                              child: const Text('Klaim'),
                            )
                          else
                            OutlinedButton(
                              onPressed: () async {
                                await showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(task.name),
                                    content: const Text(
                                      'Tugas ini menyusul: iklan '
                                      'beneran dan pelacakan selesai '
                                      'series belum tersedia.',
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(),
                                        child: const Text('Tutup'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text('Lihat'),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Paket Koin', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  if (state.packages.isEmpty)
                    const Text(
                      'Belum ada paket.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  for (final package in state.packages)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  package.name,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  package.bonusCoins > 0
                                      ? 'Bonus ${package.bonusCoins} koin'
                                      : formatRupiah(package.priceIdr),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatRupiah(package.priceIdr),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _showPaymentLater,
                            child: const Text('Beli'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const VipPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star),
                      label: const Text('Lihat Paket VIP'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<SessionCubit, SessionState>(
                    builder: (context, session) {
                      if (session.isAuthenticated) {
                        return const SizedBox.shrink();
                      }
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/login');
                          },
                          child: const Text('Masuk untuk saldo server'),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
