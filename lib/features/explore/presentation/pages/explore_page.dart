import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import '../../../series/presentation/pages/series_detail_page.dart';
import '../../../wallet/domain/entities/history.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';

/// Halaman Jelajahi — POLA LAYOUT yang dikunci (bukan salinan konten
/// atau merek aplikasi referensi):
/// - Bilah pencarian di atas: kolom + tombol "Cari".
/// - Baris filter: "Kategori" (pemilih genre → ?genre_id=),
///   "Peringkat" (rating tertinggi dulu), "Baru Tayang" (terbaru dulu).
///   API belum punya param urut → urut sisi klien, dilaporkan jujur.
/// - Grid poster 2 kolom gaya masonry: cover, judul, baris
///   "Genre | N episode"; ketuk → detail series.
/// - Kartu "Lanjutkan" dari WatchProgress API (satu ketukan kembali
///   ke cerita), tanpa angka karangan.
/// - YANG TIDAK DIBUAT (perintah eksplisit): badge kuning mengambang,
///   label "Tarik", dan elemen promo melayang sejenis.
/// - Data tetap API Dracin, merek tetap Dracin Reels, bottom nav tetap
///   milik kita. Kosong → empty state jujur; gagal → error + retry.
class ExplorePage extends StatelessWidget {
  const ExplorePage({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    return ExploreView(onOpenEpisode: onOpenEpisode);
  }
}

class ExploreView extends StatefulWidget {
  const ExploreView({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    context.read<SeriesListBloc>().add(
          SeriesListQueryChanged(_searchController.text.trim()),
        );
  }

  void _toggleSort(SeriesSort sort) {
    final current = context.read<SeriesListBloc>().state.sort;
    context.read<SeriesListBloc>().add(
          SeriesListSortChanged(current == sort ? SeriesSort.none : sort),
        );
  }

  void _pickGenre(BuildContext context, SeriesListState seriesState) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        if (seriesState.genres.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Belum ada genre dari server.'),
          );
        }
        return ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: const Text('Semua'),
              trailing: seriesState.selectedGenreId == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                context
                    .read<SeriesListBloc>()
                    .add(const SeriesListGenreChanged(null));
                Navigator.of(sheetContext).pop();
              },
            ),
            ...seriesState.genres.map(
              (genre) => ListTile(
                title: Text(genre.name),
                trailing: seriesState.selectedGenreId == genre.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  context
                      .read<SeriesListBloc>()
                      .add(SeriesListGenreChanged(genre.id));
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider(
      create: (_) => SeriesListBloc(
        context.read<SeriesRepository>(),
      )..add(const SeriesListStarted()),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 8),
              Text('Jelajahi', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Cari drama berdasarkan judul.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              // (1) Bilah pencarian: kolom + tombol "Cari".
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _applySearch(),
                      decoration: const InputDecoration(
                        hintText: 'Cari judul drama...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _applySearch,
                    child: const Text('Cari'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // (2) Baris filter: Kategori (pemilih) + 2 urutan.
              BlocBuilder<SeriesListBloc, SeriesListState>(
                builder: (context, seriesState) {
                  Genre? selectedGenre;
                  for (final genre in seriesState.genres) {
                    if (genre.id == seriesState.selectedGenreId) {
                      selectedGenre = genre;
                      break;
                    }
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        ChoiceChip(
                          label: Text(
                            selectedGenre?.name ?? 'Kategori',
                          ),
                          selected: seriesState.selectedGenreId != null,
                          onSelected: (_) =>
                              _pickGenre(context, seriesState),
                          avatar: const Icon(
                            Icons.category_outlined,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Peringkat'),
                          selected:
                              seriesState.sort == SeriesSort.rating,
                          onSelected: (_) =>
                              _toggleSort(SeriesSort.rating),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Baru Tayang'),
                          selected:
                              seriesState.sort == SeriesSort.newest,
                          onSelected: (_) =>
                              _toggleSort(SeriesSort.newest),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // (4) Lanjutkan — hanya bila ada riwayat belum selesai
              // (login + WatchProgress API). Tanpa riwayat, seksi ini
              // tidak tampil sama sekali (bukan kartu palsu).
              BlocBuilder<WalletBloc, WalletState>(
                builder: (context, walletState) {
                  final unfinished = walletState.historyItems
                      .where((item) => !item.finished)
                      .toList()
                    ..sort(
                      (a, b) => b.updatedAtMs.compareTo(a.updatedAtMs),
                    );
                  if (unfinished.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Lanjutkan', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 112,
                        child: BlocBuilder<SeriesListBloc, SeriesListState>(
                          builder: (context, seriesState) {
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: unfinished.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final item = unfinished[index];
                                int? total;
                                for (final series
                                    in seriesState.series) {
                                  if (series.id == item.seriesId) {
                                    total = series.totalEpisode;
                                    break;
                                  }
                                }
                                return _ContinueCard(
                                  item: item,
                                  totalEpisodes: total,
                                  onOpen: () => widget.onOpenEpisode(
                                    's${item.seriesId}e${item.episodeId}',
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              // (3) Grid poster masonry 2 kolom (series → detail).
              Expanded(
                child: BlocBuilder<SeriesListBloc, SeriesListState>(
                  builder: (context, seriesState) {
                    if (seriesState.errorMessage != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.cloud_off, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                seriesState.errorMessage!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => context
                                    .read<SeriesListBloc>()
                                    .add(const SeriesListStarted()),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (seriesState.isLoading &&
                        seriesState.series.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (seriesState.series.isEmpty) {
                      final filtering =
                          seriesState.selectedGenreId != null ||
                              seriesState.query.isNotEmpty;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.search_off, size: 64),
                            const SizedBox(height: 16),
                            const Text('Belum ada series yang cocok.'),
                            if (filtering) ...<Widget>[
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () {
                                  _searchController.clear();
                                  context
                                      .read<SeriesListBloc>()
                                      .add(
                                        const SeriesListGenreChanged(null),
                                      );
                                  context
                                      .read<SeriesListBloc>()
                                      .add(
                                        const SeriesListQueryChanged(''),
                                      );
                                },
                                child: const Text('Hapus Filter'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    // Masonry tanpa dependensi baru: satu scroll,
                    // dua kolom, item dibagi selang-seling; tinggi kartu
                    // bervariasi lewat poster 3:4 + judul 1–2 baris.
                    final left = <Series>[];
                    final right = <Series>[];
                    for (var i = 0;
                        i < seriesState.series.length;
                        i++) {
                      if (i.isEven) {
                        left.add(seriesState.series[i]);
                      } else {
                        right.add(seriesState.series[i]);
                      }
                    }
                    Widget column(List<Series> items) {
                      final children = <Widget>[];
                      for (final series in items) {
                        if (children.isNotEmpty) {
                          children.add(const SizedBox(height: 16));
                        }
                        children.add(
                          _SeriesPosterCard(
                            series: series,
                            onOpen: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SeriesDetailPage(
                                    seriesId: series.id,
                                    onOpenEpisode: widget.onOpenEpisode,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children,
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          column(left),
                          const SizedBox(width: 12),
                          column(right),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu "Lanjutkan": satu ketukan kembali ke cerita. Progres
/// "Ep. X / Y" hanya bila total episode series diketahui dari daftar
/// (bila tidak diketahui, hanya "Ep. X" — tidak dikarang).
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.item,
    required this.onOpen,
    this.totalEpisodes,
  });

  final HistoryEntry item;
  final VoidCallback onOpen;
  final int? totalEpisodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = totalEpisodes != null && totalEpisodes! > 0
        ? 'Ep. ${item.number} / $totalEpisodes'
        : 'Ep. ${item.number}';
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.seriesTitle,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            progress,
            style: theme.textTheme.labelMedium,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onOpen,
              child: const Text('Lanjutkan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu poster series: cover (atau gradasi bertitel bila cover tidak
/// ada/gagal), judul Semibold mudah dipindai, baris penanda
/// "Genre | N episode" (bagian yang tidak diketahui dihilangkan,
/// bukan dikarang). Ketuk → detail series.
class _SeriesPosterCard extends StatelessWidget {
  const _SeriesPosterCard({required this.series, required this.onOpen});

  final Series series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedCover = resolveMediaUrl(series.coverUrl);
    final markers = <String>[];
    if (series.genres.isNotEmpty) {
      markers.add(series.genres.first.name);
    }
    if (series.totalEpisode > 0) {
      markers.add('${series.totalEpisode} episode');
    }
    final markerLine =
        markers.isEmpty ? 'Belum ada episode' : markers.join(' | ');
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: resolvedCover.isEmpty
                  ? _TitledGradient(title: series.title)
                  : Image.network(
                      resolvedCover,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _TitledGradient(title: series.title),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            series.title,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            markerLine,
            style: theme.textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Placeholder gradasi rapi bertitel (aturan fallback thumbnail).
class _TitledGradient extends StatelessWidget {
  const _TitledGradient({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3B1D5A), Color(0xFF0B0E14)],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
            ),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
