import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../admin/presentation/pages/admin_series_page.dart';
import '../../../admin/presentation/pages/login_page.dart';
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
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RewardsPage(),
                  ),
                );
              },
              child: const Text('Lihat Hadiah'),
            ),
            if (session.isAdmin) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminSeriesPage(),
                    ),
                  );
                },
                child: const Text('Panel Admin'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
