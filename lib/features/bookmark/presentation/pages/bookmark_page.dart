import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin/presentation/pages/login_page.dart';
import '../../../series/domain/entities/series.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../../core/design/widgets.dart';
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
      appBar: const DracinAppBar(title: 'Bookmark'),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state.errorMessage != null) {
            final bool needsLogin =
                state.errorMessage!.contains('Masuk dulu');
            if (needsLogin) {
              return DracinEmptyState(
                icon: Icons.login,
                message: state.errorMessage!,
                actionLabel: 'Masuk',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginPage(),
                    ),
                  );
                },
              );
            }
            return DracinErrorState(
              message: state.errorMessage!,
              onRetry: () => context.read<BookmarkBloc>().add(
                    const BookmarkStarted(),
                  ),
            );
          }
          if (state.isLoading) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: DracinRowSkeleton(),
              ),
            );
          }
          if (state.series.isEmpty) {
            return const DracinEmptyState(
              icon: Icons.bookmark_outline,
              message: 'Belum ada series tersimpan.\n'
                  'Ketuk Simpan di feed untuk menambahkannya ke sini.',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DracinCard(
        onTap: onOpen,
        child: Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    series.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    series.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRemove, child: const Text('Hapus')),
            TextButton(onPressed: onOpen, child: const Text('Buka')),
          ],
        ),
      ),
    );
  }
}
