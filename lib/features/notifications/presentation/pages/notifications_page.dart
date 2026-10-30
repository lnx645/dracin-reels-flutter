import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../wallet/presentation/pages/rewards_page.dart';

/// Layar notifikasi: placeholder jujur. Notifikasi DITUNDA uwa:
/// tanpa FCM, tanpa izin notifikasi, tanpa daftar beneran.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionCubit>().state;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.notifications_outlined, size: 64),
            const SizedBox(height: 16),
            Text('Belum ada notifikasi', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Fitur notifikasi menyusul.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DracinButton(
              label: 'Lihat Hadiah',
              variant: DracinButtonVariant.ghost,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RewardsPage(),
                  ),
                );
              },
            ),
            if (session.isAdmin) ...<Widget>[
              const SizedBox(height: 12),
              DracinButton(
                label: 'Panel Admin',
                variant: DracinButtonVariant.ghost,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminDashboardPage(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
