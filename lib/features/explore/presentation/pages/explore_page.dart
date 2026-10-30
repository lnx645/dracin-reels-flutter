import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import '../../../series/presentation/pages/series_detail_page.dart';
import '../../../wallet/domain/entities/history.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';

/// Halaman Jelajahi — POLA LAYOUT yang dikunci (bukan salinan konten
/// atau merek aplikasi referensi):
/// - Bilah pencarian di atas: kolom + tombol "Cari".
/// - Baris filter SATU BARIS GESER: chip genre terlihat langsung
///   (Semua + tiap genre → ?genre_id=), pemisah, chip urutan
///   Peringkat / Baru Tayang. Tanpa wrap, tanpa chip yatim.
///   API belum punya param urut → urut sisi klien, dilaporkan jujur.
/// - Grid COMPACT 3 kolom rapat (pola dari referensi uwa, BUKAN
///   salinan kontennya): poster portrait 3:4, gap 8, judul kecil
///   (13px semibold, maks 2 baris + elipsis) + baris penanda kecil;
///   lebih banyak item terlihat per layar dibanding masonry 2 kolom.
///   Badge di poster HANYA "Baru" — untuk series yang created_at-nya
///   dalam 30 hari terakhir (ambang kNewSeriesDays, di bawah); TIDAK
///   ADA badge "Populer" dan TIDAK ADA angka tontonan karena API
///   tidak menyediakan data itu — jangan dikarang, jangan disalin.
/// - Kartu "Lanjutkan" dari WatchProgress API (satu ketukan kembali
///   ke cerita), tanpa angka karangan.
/// - YANG TIDAK DIBUAT (perintah eksplisit): badge kuning mengambang,
///   label "Tarik", elemen promo melayang, baris tab referensi
///   (Baru/Kategori/Komunitas/VIP), bottom nav referensi, ikon
///   mahkota VIP, dan badge hadiah melayang (+55).
/// - Data tetap API Dracin, merek tetap Dracin Reels, bottom nav tetap
///   milik kita. Kosong → empty state jujur; gagal → error + retry.
///
/// Ambang "Baru": series yang dibuat dalam 30 hari terakhir
/// (berdasarkan created_at API). Series tanpa created_at atau
/// created_at di masa depan tidak pernah ber-badge "Baru".
const int kNewSeriesDays = 30;

bool _isNewSeries(Series series) {
  final createdAt = series.createdAt;
  if (createdAt == null) {
    return false;
  }
  final age = DateTime.now().difference(createdAt);
  return !age.isNegative && age.inDays <= kNewSeriesDays;
}
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<SeriesListBloc>().add(const SeriesListMoreRequested());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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
                  DracinButton(
                    label: 'Cari',
                    onPressed: _applySearch,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Baris filter SATU BARIS GESER (bukan wrap): chip genre
              // terlihat langsung (Semua + tiap genre) + pemisah +
              // chip urutan. Tidak boleh ada chip yatim di baris kedua
              // — baris ini SingleChildScrollView horizontal.
              BlocBuilder<SeriesListBloc, SeriesListState>(
                builder: (context, seriesState) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        DracinChip(
                          label: 'Semua',
                          selected: seriesState.selectedGenreId == null,
                          onTap: () => context
                              .read<SeriesListBloc>()
                              .add(const SeriesListGenreChanged(null)),
                        ),
                        ...seriesState.genres.map(
                          (genre) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: DracinChip(
                              label: genre.name,
                              selected:
                                  seriesState.selectedGenreId == genre.id,
                              onTap: () => context
                                  .read<SeriesListBloc>()
                                  .add(
                                    SeriesListGenreChanged(genre.id),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColors.border,
                        ),
                        const SizedBox(width: 8),
                        DracinChip(
                          label: 'Peringkat',
                          selected:
                              seriesState.sort == SeriesSort.rating,
                          onTap: () =>
                              _toggleSort(SeriesSort.rating),
                        ),
                        const SizedBox(width: 8),
                        DracinChip(
                          label: 'Baru Tayang',
                          selected:
                              seriesState.sort == SeriesSort.newest,
                          onTap: () =>
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
              // (3) Grid poster COMPACT 3 kolom (series → detail).
              Expanded(
                child: BlocBuilder<SeriesListBloc, SeriesListState>(
                  builder: (context, seriesState) {
                    if (seriesState.errorMessage != null) {
                      return DracinErrorState(
                        message: seriesState.errorMessage!,
                        onRetry: () => context
                            .read<SeriesListBloc>()
                            .add(const SeriesListStarted()),
                      );
                    }
                    if (seriesState.isLoading &&
                        seriesState.series.isEmpty) {
                      return const DracinCompactGridSkeleton();
                    }
                    if (seriesState.series.isEmpty) {
                      final filtering =
                          seriesState.selectedGenreId != null ||
                              seriesState.query.isNotEmpty;
                      return DracinEmptyState(
                        icon: Icons.search_off,
                        message: 'Belum ada series yang cocok.',
                        actionLabel: filtering ? 'Hapus Filter' : null,
                        onAction: filtering
                            ? () {
                                _searchController.clear();
                                context.read<SeriesListBloc>().add(
                                      const SeriesListGenreChanged(null),
                                    );
                                context.read<SeriesListBloc>().add(
                                      const SeriesListQueryChanged(''),
                                    );
                              }
                            : null,
                      );
                    }
                    // Grid COMPACT 3 kolom rapat: poster portrait +
                    // judul kecil 2 baris + penanda kecil. Lazy via
                    // ScrollController yang sama (near-bottom → More).
                    return Column(
                      children: <Widget>[
                        Expanded(
                          child: GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.52,
                            ),
                            itemCount: seriesState.series.length,
                            itemBuilder: (context, index) {
                              final series = seriesState.series[index];
                              return _CompactSeriesCard(
                                series: series,
                                onOpen: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SeriesDetailPage(
                                        seriesId: series.id,
                                        onOpenEpisode:
                                            widget.onOpenEpisode,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (seriesState.isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
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
            child: DracinButton(
              label: 'Lanjutkan',
              onPressed: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu poster series COMPACT (grid 3 kolom Jelajahi): cover
/// portrait 3:4 (atau gradasi bertitel bila cover tidak ada/gagal —
/// aturan fallback thumbnail tetap), judul KECIL semibold maks 2
/// baris + elipsis, baris penanda kecil "Genre | N episode" (bagian
/// yang tidak diketahui dihilangkan, bukan dikarang). Badge HANYA
/// "Baru" (series.createdAt dalam 30 hari terakhir — lihat
/// _isNewSeries); tidak ada badge "Populer", tidak ada angka
/// tontonan. Ketuk → detail series.
class _CompactSeriesCard extends StatelessWidget {
  const _CompactSeriesCard({required this.series, required this.onOpen});

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
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: resolvedCover.isEmpty
                        ? _TitledGradient(title: series.title)
                        : Image.network(
                            resolvedCover,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _TitledGradient(title: series.title),
                          ),
                  ),
                  if (_isNewSeries(series))
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: DracinColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Baru',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            series.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            markerLine,
            style: theme.textTheme.labelMedium?.copyWith(fontSize: 11),
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
