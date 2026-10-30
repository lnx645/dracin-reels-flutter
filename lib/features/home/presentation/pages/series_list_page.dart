import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import '../widgets/series_card.dart';

/// Halaman daftar penuh satu seksi ("Tonton Semua"): grid kartu series
/// dengan tombol kembali. Desain kartu sama dengan Jelajahi.
class SeriesListPage extends StatelessWidget {
  const SeriesListPage({
    required this.title,
    required this.series,
    required this.onOpenSeries,
    super.key,
  });

  final String title;
  final List<Series> series;
  final void Function(int seriesId) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: series.isEmpty
            ? Center(
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
                        'Seksi ini masih kosong.',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: series.length,
                itemBuilder: (context, index) {
                  final item = series[index];
                  return SeriesCard(
                    series: item,
                    onOpen: () => onOpenSeries(item.id),
                  );
                },
              ),
      ),
    );
  }
}

/// Satu seksi Beranda: header + "Tonton Semua" + deretan kartu horizontal.
class HomeSection extends StatelessWidget {
  const HomeSection({
    required this.title,
    required this.series,
    required this.onSeeAll,
    required this.onOpenSeries,
    super.key,
  });

  final String title;
  final List<Series> series;
  final VoidCallback onSeeAll;
  final void Function(int seriesId) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: const Text('Tonton Semua'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: series.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = series[index];
              return SizedBox(
                width: 170,
                child: SeriesCard(
                  series: item,
                  onOpen: () => onOpenSeries(item.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Mendengarkan daftar series + genre untuk seksi Beranda.
class HomeSections extends StatelessWidget {
  const HomeSections({
    required this.onOpenSeries,
    required this.onSeeAll,
    super.key,
  });

  final void Function(int seriesId) onOpenSeries;

  /// (judul seksi, daftar series) → halaman "Tonton Semua".
  final void Function(String title, List<Series> series) onSeeAll;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SeriesListBloc, SeriesListState>(
      builder: (context, state) {
        if (state.isLoading && state.series.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = state.series;
        final trending = List<Series>.from(all)
          ..sort((a, b) => b.rating.compareTo(a.rating));
        final sections = <(String, List<Series>)>[
          ('Trending', trending),
          ('Rekomendasi Untuk Anda', all),
        ];
        for (final genre in state.genres) {
          final byGenre = all
              .where(
                (series) =>
                    series.genres.any((item) => item.slug == genre.slug),
              )
              .toList();
          if (byGenre.isNotEmpty) {
            sections.add((genre.name, byGenre));
          }
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final section = sections[index];
            return HomeSection(
              title: section.$1,
              series: section.$2,
              onSeeAll: () => onSeeAll(section.$1, section.$2),
              onOpenSeries: onOpenSeries,
            );
          },
        );
      },
    );
  }
}
