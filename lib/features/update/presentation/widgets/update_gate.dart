import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/playback/playback_state.dart';
import '../../data/datasources/github_release_datasource.dart';
import '../../data/repositories/update_repository_impl.dart';
import '../../data/services/apk_installer.dart';
import '../../data/services/update_downloader.dart';
import '../cubit/update_cubit.dart';
import '../cubit/update_state.dart';
import 'update_dialogs.dart';

/// Pembungkus layar utama yang menjalankan pemeriksaan pembaruan di
/// latar belakang (sekali sehari, setelah frame pertama) dan mengelola
/// semua dialog + banner updater. Tidak mengubah tampilan/isi layar
/// yang dibungkusnya.
///
/// Prinsip prompt pintar: JANGAN PERNAH mengganggu saat video sedang
/// diputar. Bila unduhan selesai saat pengguna menonton, yang tampil
/// hanya banner "Update siap dipasang" (Pasang/Nanti); installer
/// langsung hanya dibuka bila pengguna TIDAK sedang menonton.
/// Installer yang dibatalkan tidak menagih lagi di sesi yang sama —
/// dan unduhan yang sudah selesai DIINGAT, jadi ketuk update lagi
/// langsung membuka installer tanpa unduh ulang.
class UpdateGate extends StatefulWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate>
    with WidgetsBindingObserver {
  late final UpdateCubit _cubit;
  bool _availableDialogOpen = false;
  bool _permissionDialogOpen = false;
  bool _mismatchDialogOpen = false;
  bool _errorDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final ApkInstaller installer = ApkInstaller();
    _cubit = UpdateCubit(
      UpdateRepositoryImpl(GithubReleaseDataSource()),
      UpdateDownloader(installer),
      installer,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cubit.checkIfDue();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  /// Kembali dari Pengaturan izin → lanjutkan alur (unduh bila izin
  /// sudah diberikan, dialog izin lagi bila belum).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _cubit.state is UpdateAwaitingPermission) {
      _cubit.checkPermissionAndContinue();
    }
  }

  void _showSnack(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showIfClosed(
    bool isOpen,
    void Function() markOpen,
    void Function() markClosed,
    Widget Function() build,
  ) async {
    if (isOpen) {
      return;
    }
    markOpen();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider<UpdateCubit>.value(
        value: _cubit,
        child: build(),
      ),
    );
    markClosed();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UpdateCubit>.value(
      value: _cubit,
      child: BlocListener<UpdateCubit, UpdateState>(
        listener: (BuildContext context, UpdateState state) async {
          if (state is UpdateAvailable) {
            await _showIfClosed(
              _availableDialogOpen,
              () => _availableDialogOpen = true,
              () => _availableDialogOpen = false,
              () => UpdateAvailableDialog(info: state.info),
            );
          } else if (state is UpdatePermissionRequired) {
            await _showIfClosed(
              _permissionDialogOpen,
              () => _permissionDialogOpen = true,
              () => _permissionDialogOpen = false,
              () => UpdatePermissionDialog(info: state.info),
            );
          } else if (state is UpdateSignatureMismatch) {
            await _showIfClosed(
              _mismatchDialogOpen,
              () => _mismatchDialogOpen = true,
              () => _mismatchDialogOpen = false,
              () => UpdateSignatureMismatchDialog(
                info: state.info,
                downloadsPath: state.downloadsPath,
              ),
            );
          } else if (state is UpdateDownloadError) {
            await _showIfClosed(
              _errorDialogOpen,
              () => _errorDialogOpen = true,
              () => _errorDialogOpen = false,
              () => UpdateDownloadErrorDialog(
                message: state.message,
                info: state.info,
              ),
            );
          } else if (state is UpdateDownloaded) {
            // Prompt pintar: sedang menonton → banner saja (dibangun
            // di bawah lewat BlocBuilder); tidak menonton → installer
            // langsung. Installer yang dibatalkan tidak memunculkan
            // apa-apa lagi di sesi ini (state kembali Initial dan
            // tidak ada yang meng-emit ulang Downloaded).
            if (!playbackActive.value && mounted) {
              final String? message =
                  await _cubit.install(state.filePath, state.info);
              if (message != null && mounted) {
                _showSnack(message);
              }
            }
          } else if (state is UpdateError) {
            if (mounted) {
              _showSnack(state.message);
            }
          }
        },
        child: Stack(
          children: <Widget>[
            widget.child,
            // Banner non-modal: unduhan berjalan (tidak memblokir
            // pemakaian aplikasi) + update siap pasang saat menonton.
            // Banner tidak pernah menutupi layar penuh dan selalu bisa
            // ditutup (Batal / Nanti).
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: BlocBuilder<UpdateCubit, UpdateState>(
                  builder: (BuildContext context, UpdateState state) {
                    if (state is UpdateDownloading) {
                      final double progress = state.progress;
                      return _UpdateBanner(
                        title: 'Mengunduh update…',
                        subtitle: progress >= 0
                            ? 'Terunduh '
                                '${(progress * 100).toStringAsFixed(0)}%'
                            : 'Menghubungkan ke server…',
                        progress: progress >= 0 ? progress : null,
                        actionLabel: 'Batal',
                        onAction: () => _cubit.cancelDownload(),
                      );
                    }
                    if (state is UpdateDownloaded) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: playbackActive,
                        builder: (
                          BuildContext context,
                          bool watching,
                          _,
                        ) {
                          // Banner siap-pasang hanya relevan saat
                          // menonton (bila tidak menonton, listener
                          // sudah membuka installer langsung).
                          if (!watching) {
                            return const SizedBox.shrink();
                          }
                          return _UpdateBanner(
                            title: 'Update siap dipasang',
                            subtitle:
                                'Ketuk Pasang saat sudah selesai menonton.',
                            progress: 1,
                            actionLabel: 'Nanti',
                            onAction: () => _cubit.dismiss(),
                            secondLabel: 'Pasang',
                            onSecondAction: () async {
                              final String? message = await _cubit.install(
                                state.filePath,
                                state.info,
                              );
                              if (message != null && mounted) {
                                _showSnack(message);
                              }
                            },
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner bawah non-modal untuk progres unduhan / update siap pasang.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.progress,
    this.secondLabel,
    this.onSecondAction,
  });

  final String title;
  final String subtitle;
  final double? progress;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondLabel;
  final VoidCallback? onSecondAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF26262B),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
                if (secondLabel != null && onSecondAction != null)
                  FilledButton(
                    onPressed: onSecondAction,
                    child: Text(secondLabel!),
                  ),
              ],
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}
