import 'package:flutter/material.dart';
import '../../../../core/design/widgets.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      appBar: DracinAppBar(title: title),
      body: SafeArea(
        child: series.isEmpty
            ? const DracinEmptyState(
                icon: Icons.tv_outlined,
                message: 'Belum ada series.\nSeksi ini masih kosong.',
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
        if (state.errorMessage != null) {
          return DracinErrorState(
            message: state.errorMessage!,
            onRetry: () => context
                .read<SeriesListBloc>()
                .add(const SeriesListStarted()),
          );
        }
        if (state.isLoading && state.series.isEmpty) {
          return const DracinGridSkeleton();
        }
        if (state.series.isEmpty) {
          return const DracinEmptyState(
            icon: Icons.tv_outlined,
            message: 'Belum ada series.',
          );
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
