import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin/presentation/pages/login_page.dart';
import '../../../series/domain/entities/series.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../bloc/bookmark_bloc.dart';

class BookmarkPage extends StatelessWidget {
  const BookmarkPage({required this.onOpenSeries, super.key});

  /// Ketuk series → buka halaman detail series itu.
  final void Function(int seriesId) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookmarkBloc(
        context.read<WalletRepository>(),
      )..add(const BookmarkStarted()),
      child: BookmarkView(onOpenSeries: onOpenSeries),
    );
  }
}

class BookmarkView extends StatelessWidget {
  const BookmarkView({required this.onOpenSeries, super.key});

  final void Function(int seriesId) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmark')),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state.errorMessage != null) {
            final bool needsLogin =
                state.errorMessage!.contains('Masuk dulu');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.cloud_off, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (needsLogin)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text('Masuk'),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => context
                            .read<BookmarkBloc>()
                            .add(const BookmarkStarted()),
                        child: const Text('Coba Lagi'),
                      ),
                  ],
                ),
              ),
            );
          }
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.series.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.bookmark_outline, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Belum ada series tersimpan.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ketuk Simpan di feed untuk menambahkannya ke sini.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: state.series.length,
            itemBuilder: (context, index) {
              final series = state.series[index];
              return _BookmarkTile(
                series: series,
                onOpen: () => onOpenSeries(series.id),
                onRemove: () => context.read<BookmarkBloc>().add(
                      BookmarkRemoved(series.id),
                    ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({
    required this.series,
    required this.onRemove,
    required this.onOpen,
  });

  final Series series;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white),
      ),
      title: Text(
        series.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        series.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextButton(onPressed: onRemove, child: const Text('Hapus')),
          TextButton(onPressed: onOpen, child: const Text('Buka')),
        ],
      ),
    );
  }
}
