import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Episode — $seriesTitle')),
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(
                      'Episode ${episode.number} - ${episode.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      episode.coinPrice <= 0
                          ? 'Gratis • ${episode.status}'
                          : '${episode.coinPrice} koin • ${episode.status}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EpisodeFormPage(
                            seriesId: seriesId,
                            seriesTitle: seriesTitle,
                            existing: <String, dynamic>{
                              'id': episode.id,
                              'number': episode.number,
                              'title': episode.title,
                              'description': episode.description,
                              'video_url': episode.videoUrl,
                              'coin_price': episode.coinPrice,
                              'status': episode.status,
                            },
                          ),
                        ),
                      );
                      if (context.mounted) {
                        context.read<SeriesDetailBloc>().add(
                              SeriesDetailStarted(seriesId),
                            );
                      }
                    },
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
