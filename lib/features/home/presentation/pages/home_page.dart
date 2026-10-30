import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../feed/presentation/pages/feed_page.dart';
import '../../../series/domain/entities/series.dart';
import '../../../series/domain/repositories/series_repository.dart';
import '../../../series/presentation/bloc/series_bloc.dart';
import '../../../series/presentation/pages/series_detail_page.dart';
import 'series_list_page.dart';

enum HomeMode { series, reels }

/// Beranda: TIDAK hanya feed vertikal. Mode Series menampilkan seksi
/// (Trending, Rekomendasi, per genre) dengan tombol "Tonton Semua";
/// mode Reels menampilkan feed vertikal.
class HomePage extends StatefulWidget {
  const HomePage({
    required this.onOpenEpisode,
    super.key,
  });

  final void Function(String episodeId) onOpenEpisode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeMode _mode = HomeMode.series;

  void _openSeries(BuildContext context, int seriesId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeriesDetailPage(
          seriesId: seriesId,
          onOpenEpisode: widget.onOpenEpisode,
        ),
      ),
    );
  }

  void _openSeeAll(
    BuildContext context,
    String title,
    List<Series> series,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeriesListPage(
          title: title,
          series: series,
          onOpenSeries: (seriesId) => _openSeries(context, seriesId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SeriesListBloc(context.read<SeriesRepository>())
        ..add(const SeriesListStarted()),
      child: Column(
        children: <Widget>[
          // Header Beranda HANYA di mode Series. Di mode Reels header ini
          // disembunyikan — switch mode pindah ke dalam FeedTopBar — agar
          // tidak ada branding ganda (DracinReels dua kali).
          if (_mode == HomeMode.series)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: <Widget>[
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Dracin',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Reels',
                            style: TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SegmentedButton<HomeMode>(
                      segments: const <ButtonSegment<HomeMode>>[
                        ButtonSegment(
                          value: HomeMode.series,
                          label: Text('Series'),
                        ),
                        ButtonSegment(
                          value: HomeMode.reels,
                          label: Text('Reels'),
                        ),
                      ],
                      selected: <HomeMode>{_mode},
                      onSelectionChanged: (selection) {
                        setState(() => _mode = selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _mode == HomeMode.series
                ? HomeSections(
                    onOpenSeries: (seriesId) => _openSeries(context, seriesId),
                    onSeeAll: (title, series) =>
                        _openSeeAll(context, title, series),
                  )
                : FeedPage(
                    showModeSwitch: true,
                    isSeriesMode: false,
                    onModeChanged: (toSeries) {
                      if (toSeries) {
                        setState(() => _mode = HomeMode.series);
                      }
                    },
                    onOpenEpisode: widget.onOpenEpisode,
                  ),
          ),
        ],
      ),
    );
  }
}
