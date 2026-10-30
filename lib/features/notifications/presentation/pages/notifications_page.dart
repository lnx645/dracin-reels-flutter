import 'package:flutter/material.dart';

/// Layar notifikasi: placeholder jujur. Notifikasi DITUNDA uwa:
/// tanpa FCM, tanpa izin notifikasi, tanpa daftar beneran.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text(
              'Fitur notifikasi menyusul.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
