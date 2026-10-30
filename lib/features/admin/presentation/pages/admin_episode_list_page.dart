import 'package:flutter/material.dart';
import '../../../../core/design/widgets.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../admin/domain/repositories/admin_repository.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import 'episode_form_page.dart';

/// Daftar episode satu series untuk admin (edit/hapus).
/// Data diambil dari detail series publik (id + status sama).
class AdminEpisodeListPage extends StatelessWidget {
  const AdminEpisodeListPage({
    required this.seriesId,
    required this.seriesTitle,
    super.key,
  });

  final int seriesId;
  final String seriesTitle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SeriesDetailBloc(context.read<SeriesRepository>())
        ..add(SeriesDetailStarted(seriesId)),
      child: AdminEpisodeListView(
        seriesId: seriesId,
        seriesTitle: seriesTitle,
      ),
    );
  }
}

class AdminEpisodeListView extends StatelessWidget {
  const AdminEpisodeListView({
    required this.seriesId,
    required this.seriesTitle,
    super.key,
  });

  final int seriesId;
  final String seriesTitle;

  /// Hapus episode (dulu method deleteEpisode ada tapi tidak punya
  /// pemanggil UI). Konfirmasi dulu; gagal → pesan asli server.
  Future<void> _confirmDelete(
    BuildContext context,
    SeriesEpisode episode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus episode?'),
        content: Text(
          'Episode ${episode.number} — ${episode.title} akan dihapus '
          'permanen.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await context.read<AdminRepository>().deleteEpisode(episode.id);
      if (context.mounted) {
        context.read<SeriesDetailBloc>().add(
              SeriesDetailStarted(seriesId),
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Episode dihapus.')),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Map<String, dynamic> _existingOf(SeriesEpisode episode) {
    return <String, dynamic>{
      'id': episode.id,
      'number': episode.number,
      'title': episode.title,
      'description': episode.description,
      'video_url': episode.videoUrl,
      'hls_url': episode.hlsUrl,
      'subtitle_url': episode.subtitleUrl,
      'thumbnail_url': episode.thumbnailUrl,
      'duration_seconds': episode.durationSeconds,
      'coin_price': episode.coinPrice,
      'status': episode.status,
    };
  }

  Future<void> _openEdit(
    BuildContext context,
    SeriesEpisode episode,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeFormPage(
          seriesId: seriesId,
          seriesTitle: seriesTitle,
          existing: _existingOf(episode),
        ),
      ),
    );
    if (context.mounted) {
      context.read<SeriesDetailBloc>().add(
            SeriesDetailStarted(seriesId),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DracinAppBar(title: 'Episode — $seriesTitle'),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EpisodeFormPage(
                seriesId: seriesId,
                seriesTitle: seriesTitle,
              ),
            ),
          );
          // Muat ulang juga sesudah TAMBAH (dulu hanya sesudah edit
          // yang memuat ulang, jadi episode baru tidak muncul sampai
          // halaman dibuka ulang).
          if (context.mounted) {
            context.read<SeriesDetailBloc>().add(
                  SeriesDetailStarted(seriesId),
                );
          }
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: BlocBuilder<SeriesDetailBloc, SeriesDetailState>(
          builder: (context, state) {
            final detail = state.detail;
            if (state.isLoading || detail == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (detail.episodes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada episode. Tekan tombol + untuk menambah.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: detail.episodes.length,
              itemBuilder: (context, index) {
                final episode = detail.episodes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DracinCard(
                    onTap: () => _openEdit(context, episode),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Episode ${episode.number} - ${episode.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                episode.coinPrice <= 0
                                    ? 'Gratis • ${episode.status}'
                                    : '${episode.coinPrice} koin • ${episode.status}',
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Ubah',
                          onPressed: () => _openEdit(context, episode),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Hapus',
                          onPressed: () =>
                              _confirmDelete(context, episode),
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
    );
  }
}
