import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/github_release_datasource.dart';
import '../../data/repositories/update_repository_impl.dart';
import '../../data/services/apk_installer.dart';
import '../../data/services/update_downloader.dart';
import '../cubit/update_cubit.dart';
import '../cubit/update_state.dart';
import 'update_dialogs.dart';

/// Pembungkus layar utama yang menjalankan pemeriksaan pembaruan di
/// latar belakang (sekali sehari, setelah frame pertama) dan mengelola
/// semua dialog updater. Tidak mengubah tampilan/isi layar yang
/// dibungkusnya.
class UpdateGate extends StatefulWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late final UpdateCubit _cubit;
  bool _availableDialogOpen = false;
  bool _downloadDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _cubit = UpdateCubit(
      UpdateRepositoryImpl(GithubReleaseDataSource()),
      UpdateDownloader(),
      ApkInstaller(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cubit.checkIfDue();
      }
    });
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _showSnack(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UpdateCubit>.value(
      value: _cubit,
      child: BlocListener<UpdateCubit, UpdateState>(
        listener: (BuildContext context, UpdateState state) async {
          if (state is UpdateAvailable && !_availableDialogOpen) {
            _availableDialogOpen = true;
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BlocProvider<UpdateCubit>.value(
                value: _cubit,
                child: UpdateAvailableDialog(info: state.info),
              ),
            );
            _availableDialogOpen = false;
          } else if (state is UpdateDownloading && !_downloadDialogOpen) {
            _downloadDialogOpen = true;
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BlocProvider<UpdateCubit>.value(
                value: _cubit,
                child: const UpdateDownloadDialog(),
              ),
            );
            _downloadDialogOpen = false;
          } else if (state is UpdateDownloaded) {
            if (_downloadDialogOpen && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            final String? message = await _cubit.install(state.filePath);
            if (message != null && mounted) {
              _showSnack(message);
            }
          } else if (state is UpdateError) {
            if (_downloadDialogOpen && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            if (mounted) {
              _showSnack(state.message);
            }
          } else if (state is UpdateInitial) {
            if (_downloadDialogOpen && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        },
        child: widget.child,
      ),
    );
  }
}
