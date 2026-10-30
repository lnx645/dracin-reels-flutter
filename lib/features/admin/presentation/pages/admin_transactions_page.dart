import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets.dart';
import '../../domain/repositories/admin_panel_repository.dart';
import '../bloc/admin_panel_bloc.dart';

/// Transaksi Koin: daftar dari GET /admin/transactions + filter
/// tipe (Semua / Check-in — hanya checkin yang dikirim sebagai
/// filter karena hanya itu yang terverifikasi; tipe lain tetap
/// tampil di 'Semua'). Lazy (20/halaman). Jumlah bertanda: positif
/// = koin masuk, negatif = koin keluar (apa adanya dari API).
class AdminTransactionsPage extends StatefulWidget {
  const AdminTransactionsPage({super.key});

  @override
  State<AdminTransactionsPage> createState() =>
      _AdminTransactionsPageState();
}

class _AdminTransactionsPageState extends State<AdminTransactionsPage> {
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
      context.read<AdminTransactionsCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminTransactionsCubit(
        context.read<AdminPanelRepository>(),
      )..load(),
      child: Scaffold(
        appBar: const DracinAppBar(title: 'Transaksi Koin'),
        body: BlocBuilder<AdminTransactionsCubit, AdminTransactionsState>(
          builder: (context, state) {
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        DracinChip(
                          label: 'Semua',
                          selected: state.typeFilter == null,
                          onTap: () => context
                              .read<AdminTransactionsCubit>()
                              .load(clearFilter: true),
                        ),
                        const SizedBox(width: 8),
                        DracinChip(
                          label: 'Check-in',
                          selected: state.typeFilter == 'checkin',
                          onTap: () => context
                              .read<AdminTransactionsCubit>()
                              .load(typeFilter: 'checkin'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state.errorMessage != null) {
                        return DracinErrorState(
                          message: state.errorMessage!,
                          onRetry: () => context
                              .read<AdminTransactionsCubit>()
                              .load(),
                        );
                      }
                      if (state.isLoading && state.transactions.isEmpty) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 5,
                          itemBuilder: (context, index) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: DracinRowSkeleton(),
                          ),
                        );
                      }
                      if (state.transactions.isEmpty) {
                        return const DracinEmptyState(
                          icon: Icons.monetization_on_outlined,
                          message: 'Belum ada transaksi pada filter ini.',
                        );
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.transactions.length +
                            (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= state.transactions.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final tx = state.transactions[index];
                          final signed = tx.amount >= 0
                              ? '+${tx.amount}'
                              : '${tx.amount}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DracinCard(
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.monetization_on,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          tx.userEmail,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${tx.type} • '
                                          '${_shortDate(tx.createdAt)}',
                                        ),
                                        Text(
                                          'Saldo sesudah: ${tx.balanceAfter} koin',
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    signed,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
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
              ],
            );
          },
        ),
      ),
    );
  }

  static String _shortDate(String iso) {
    if (iso.length < 10) {
      return iso.isEmpty ? '-' : iso;
    }
    return iso.substring(0, 10);
  }
}
