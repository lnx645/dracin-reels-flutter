import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/update_cubit.dart';
import '../cubit/update_state.dart';
import '../../domain/entities/update_info.dart';

/// Dialog tawaran pembaruan: versi baru + changelog + dua tombol.
/// Tidak ada update paksa: "Nanti" selalu tersedia.
class UpdateAvailableDialog extends StatelessWidget {
  const UpdateAvailableDialog({required this.info, super.key});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update tersedia ${info.versionName}'),
      content: SingleChildScrollView(
        child: Text(info.changelog),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            final UpdateCubit cubit = context.read<UpdateCubit>();
            Navigator.of(context).pop();
            cubit.dismiss();
          },
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () {
            final UpdateCubit cubit = context.read<UpdateCubit>();
            Navigator.of(context).pop();
            cubit.download();
          },
          child: const Text('Update Sekarang'),
        ),
      ],
    );
  }
}

/// Dialog progres unduhan. Tombol Batal membatalkan unduhan dan
/// menghapus berkas setengah jadi; versi lama tetap berjalan.
class UpdateDownloadDialog extends StatelessWidget {
  const UpdateDownloadDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mengunduh update'),
      content: BlocBuilder<UpdateCubit, UpdateState>(
        builder: (BuildContext context, UpdateState state) {
          final double progress =
              state is UpdateDownloading ? state.progress : -1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LinearProgressIndicator(
                value: progress >= 0 ? progress : null,
              ),
              const SizedBox(height: 12),
              Text(
                progress >= 0
                    ? 'Terunduh ${(progress * 100).toStringAsFixed(0)}%'
                    : 'Menghubungkan ke server…',
              ),
            ],
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            context.read<UpdateCubit>().cancelDownload();
          },
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
