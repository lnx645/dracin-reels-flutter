import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/update_cubit.dart';
import '../cubit/update_state.dart';
import '../../domain/entities/update_info.dart';

/// Dialog tawaran pembaruan: versi baru + changelog + dua tombol.
/// Tidak ada update paksa: "Nanti" selalu tersedia — dan "Nanti"
/// berarti lewati VERSI INI saja (versi berikutnya tetap memberi tahu;
/// cek paksa "Periksa Update" tetap jalan).
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

/// Dialog izin instal: muncul SEBELUM unduhan apa pun dimulai.
/// Menjelaskan kenapa izin diperlukan (Android menolak pemasangan
/// tanpa izin ini), lalu mengarahkan ke Pengaturan. Sesudah pengguna
/// kembali dengan izin diberikan, unduhan jalan SEKALI — tidak pernah
/// mengunduh dulu baru ketahuan izin belum ada.
class UpdatePermissionDialog extends StatelessWidget {
  const UpdatePermissionDialog({required this.info, super.key});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Izin pemasangan diperlukan'),
      content: const Text(
        'Supaya update bisa dipasang, izinkan Dracin Reels memasang '
        'aplikasi dari sumber ini di Pengaturan. Setelah izin aktif, '
        'kembali ke aplikasi — unduhan akan berjalan sekali, lalu '
        'installer terbuka.',
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
            cubit.openPermissionSettings();
          },
          child: const Text('Buka Pengaturan'),
        ),
      ],
    );
  }
}

/// Dialog ketidakcocokan tanda tangan: installer sistem PASTI menolak
/// APK yang tanda tangannya berbeda — jadi installer tidak dibuka
/// sama sekali (tidak dilempar ke pesan samar). Langkah yang benar:
/// uninstall aplikasi lama sekali, lalu instal dari salinan di folder
/// Downloads (salinan itu bertahan meski aplikasi di-uninstall).
class UpdateSignatureMismatchDialog extends StatelessWidget {
  const UpdateSignatureMismatchDialog({
    required this.info,
    required this.downloadsPath,
    super.key,
  });

  final UpdateInfo info;
  final String? downloadsPath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Versi ini butuh instal ulang sekali'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Tanda tangan versi baru berbeda dari aplikasi yang '
              'terinstal, jadi Android tidak bisa memperbaruinya '
              'langsung. Langkahnya:',
            ),
            const SizedBox(height: 12),
            const Text('1. Uninstall Dracin Reels yang lama.'),
            const Text(
              '2. Instal lagi dari berkas update yang sudah tersimpan '
              'di folder Downloads.',
            ),
            if (downloadsPath != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Berkas tersimpan di: $downloadsPath',
                style: const TextStyle(fontSize: 13),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'Salinan ke folder Downloads gagal dibuat — minta '
                'tautan unduh manual bila perlu instal ulang.',
                style: TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Sesudah instal ulang sekali ini, update berikutnya '
              'akan terpasang normal tanpa konflik.',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            final UpdateCubit cubit = context.read<UpdateCubit>();
            Navigator.of(context).pop();
            cubit.dismiss();
          },
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: () {
            final UpdateCubit cubit = context.read<UpdateCubit>();
            Navigator.of(context).pop();
            cubit.openAppSettings();
          },
          child: const Text('Buka Pengaturan Aplikasi'),
        ),
      ],
    );
  }
}

/// Dialog galat unduhan: "Coba Lagi" MELANJUTKAN dari berkas setengah
/// jadi (HTTP Range), bukan dari nol; "Nanti" = lewati versi ini saja.
class UpdateDownloadErrorDialog extends StatelessWidget {
  const UpdateDownloadErrorDialog({
    required this.message,
    required this.info,
    super.key,
  });

  final String message;
  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unduhan gagal'),
      content: Text(message),
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
            cubit.retryDownload(info);
          },
          child: const Text('Coba Lagi'),
        ),
      ],
    );
  }
}
