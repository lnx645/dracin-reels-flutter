import 'package:flutter/material.dart';
import '../../../../core/design/widgets.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../presentation/bloc/wallet_bloc.dart';

/// Layar VIP: paket mingguan/bulanan/tahunan dari katalog API +
/// status VIP. Klaim VIP lewat API belum menagih (pembelian/langganan
/// beneran BELUM ada dan dinyatakan di sini).
class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  String? _lastMessage;

  static const List<(String, String, String)> _plans = <(String, String, String)>[
    ('weekly', 'Mingguan', 'VIP 7 hari'),
    ('monthly', 'Bulanan', 'VIP 30 hari'),
    ('yearly', 'Tahunan', 'VIP 365 hari'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.infoMessage != current.infoMessage,
      listener: (context, state) {
        final message = state.errorMessage ?? state.infoMessage;
        if (message != null && message != _lastMessage) {
          _lastMessage = message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      child: Scaffold(
        appBar: const DracinAppBar(title: 'VIP'),
        body: SafeArea(
          child: BlocBuilder<WalletBloc, WalletState>(
            builder: (context, state) {
              final session = context.watch<SessionCubit>().state;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.star, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(
                              'Status VIP',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.vip.isActive
                              ? 'VIP aktif'
                                  '${state.vip.plan == null ? '' : ' (${state.vip.plan})'}'
                                  '${state.vip.endsAt == null ? '' : ' sampai ${state.vip.endsAt}'}'
                              : 'Belum VIP — semua episode terkunci tetap '
                                  'butuh koin.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Klaim VIP di bawah ini belum menagih. '
                          'Langganan berbayar beneran (auto-renew) '
                          'menyusul bersama backend pembayaran.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Paket VIP', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  for (final plan in _plans)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  plan.$2,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plan.$3,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          DracinButton(
                            label: 'Klaim',
                            onPressed: state.isLoading
                                ? null
                                : () async {
                                    if (!session.isAuthenticated) {
                                      await Navigator.of(context)
                                          .pushNamed('/login');
                                      return;
                                    }
                                    if (!context.mounted) {
                                      return;
                                    }
                                    context.read<WalletBloc>().add(
                                          WalletVipClaimRequested(plan.$1),
                                        );
                                  },
                          ),
                        ],
                      ),
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
