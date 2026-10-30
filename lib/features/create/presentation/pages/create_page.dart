import 'package:flutter/material.dart';

/// Layar buat video: placeholder jujur, unggah dan rekam menyusul.
class CreatePage extends StatelessWidget {
  const CreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.videocam_outlined, size: 64),
            const SizedBox(height: 16),
            Text('Buat Video', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Unggah dan rekam menyusul (UI saja).',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
