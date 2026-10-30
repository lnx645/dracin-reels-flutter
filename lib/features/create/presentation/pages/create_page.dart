import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../admin/presentation/pages/login_page.dart';

/// Layar buat video: placeholder jujur, unggah dan rekam menyusul.
/// Admin mendapat tombol ke Panel Admin (upload konten lewat sana).
class CreatePage extends StatelessWidget {
  const CreatePage({super.key});

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
            const Icon(Icons.videocam_outlined, size: 64),
            const SizedBox(height: 16),
            Text('Buat Video', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Unggah dan rekam menyusul (UI saja).',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (session.isAdmin)
              DracinButton(
                label: 'Buka Panel Admin',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminDashboardPage(),
                    ),
                  );
                },
              )
            else
              DracinButton(
                label: 'Masuk sebagai Admin',
                variant: DracinButtonVariant.ghost,
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
      ),
    );
  }
}
