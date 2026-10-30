import 'package:flutter/material.dart';
import '../../../../core/design/widgets.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';
import '../bloc/admin_bloc.dart';
import 'admin_episode_list_page.dart';
import 'series_form_page.dart';

/// Panel Admin (hanya role=admin): daftar series + kelola episode.
/// Tanpa hak admin, halaman ini menampilkan penolakan jelas.
class AdminSeriesPage extends StatelessWidget {
  const AdminSeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    if (!session.isAdmin) {
      return Scaffold(
        appBar: const DracinAppBar(title: 'Panel Admin'),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Halaman ini hanya untuk admin. Masuk dengan akun '
                'admin untuk mengelola konten.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return BlocProvider(
      create: (_) => AdminBloc(context.read<AdminRepository>())
        ..add(const AdminSeriesStarted()),
      child: const AdminSeriesView(),
    );
  }
}

class AdminSeriesView extends StatelessWidget {
  const AdminSeriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        final message = state.errorMessage ?? state.infoMessage;
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      child: Scaffold(
        appBar: const DracinAppBar(title: 'Panel Admin'),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SeriesFormPage(),
              ),
            );
            if (context.mounted) {
              context.read<AdminBloc>().add(const AdminSeriesStarted());
            }
          },
          child: const Icon(Icons.add),
        ),
        body: SafeArea(
          child: BlocBuilder<AdminBloc, AdminState>(
            builder: (context, state) {
              if (state.isLoading && state.series.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.series.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.tv_outlined, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada series',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tekan tombol + untuk menambah series pertama.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.series.length,
                itemBuilder: (context, index) {
                  final item = state.series[index];
                  final id = item['id'];
                  final title = item['title'];
                  final status = item['status'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DracinCard(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  title is String ? title : 'Series',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'ID ${id is int ? id : '-'} • '
                                  '${status is String ? status : ''}',
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SeriesFormPage(
                                  existing: item,
                                ),
                              ),
                            );
                            if (context.mounted) {
                              context.read<AdminBloc>().add(
                                    const AdminSeriesStarted(),
                                  );
                            }
                          } else if (value == 'episodes') {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AdminEpisodeListPage(
                                  seriesId: id is int ? id : 0,
                                  seriesTitle: title is String
                                      ? title
                                      : 'Series',
                                ),
                              ),
                            );
                          } else if (value == 'delete' && id is int) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Hapus series?'),
                                content: const Text(
                                  'Series dan episodenya akan dihapus.',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext)
                                            .pop(false),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext)
                                            .pop(true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              context.read<AdminBloc>().add(
                                    AdminSeriesDeleted(id),
                                  );
                            }
                          }
                        },
                        itemBuilder: (_) => const <PopupMenuEntry<String>>[
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit series'),
                          ),
                          PopupMenuItem(
                            value: 'episodes',
                            child: Text('Kelola episode'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Hapus'),
                          ),
                        ],
                      ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
