import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets.dart';
import '../../domain/repositories/admin_panel_repository.dart';
import '../bloc/admin_panel_bloc.dart';

/// Kelola Member VIP: daftar dari GET /admin/vip-subscriptions
/// + filter status (Semua/Aktif/Kedaluwarsa — status EFEKTIF dari
/// server: 'active' yang sudah lewat ends_at dihitung kedaluwarsa).
/// Lazy (20/halaman). Hanya baca: backend tidak menyediakan ubah
/// langganan — itu dilaporkan jujur, bukan dibuatkan tombol palsu.
class AdminMembersPage extends StatefulWidget {
  const AdminMembersPage({super.key});

  @override
  State<AdminMembersPage> createState() => _AdminMembersPageState();
}

class _AdminMembersPageState extends State<AdminMembersPage> {
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
      context.read<AdminMembersCubit>().loadMore();
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
      create: (_) => AdminMembersCubit(
        context.read<AdminPanelRepository>(),
      )..load(),
      child: Scaffold(
        appBar: const DracinAppBar(title: 'Kelola Member VIP'),
        body: BlocBuilder<AdminMembersCubit, AdminMembersState>(
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
                          selected: state.statusFilter == null,
                          onTap: () => context
                              .read<AdminMembersCubit>()
                              .load(clearFilter: true),
                        ),
                        const SizedBox(width: 8),
                        DracinChip(
                          label: 'Aktif',
                          selected: state.statusFilter == 'active',
                          onTap: () => context
                              .read<AdminMembersCubit>()
                              .load(statusFilter: 'active'),
                        ),
                        const SizedBox(width: 8),
                        DracinChip(
                          label: 'Kedaluwarsa',
                          selected: state.statusFilter == 'expired',
                          onTap: () => context
                              .read<AdminMembersCubit>()
                              .load(statusFilter: 'expired'),
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
                              .read<AdminMembersCubit>()
                              .load(),
                        );
                      }
                      if (state.isLoading && state.members.isEmpty) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 5,
                          itemBuilder: (context, index) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: DracinRowSkeleton(),
                          ),
                        );
                      }
                      if (state.members.isEmpty) {
                        return const DracinEmptyState(
                          icon: Icons.star_outline,
                          message: 'Belum ada member VIP pada filter ini.',
                        );
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.members.length +
                            (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= state.members.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final member = state.members[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DracinCard(
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.star, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          member.userEmail,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Paket ${member.plan} • '
                                          '${member.status}',
                                        ),
                                        Text(
                                          'Berakhir: ${_shortDate(member.endsAt)}',
                                        ),
                                      ],
                                    ),
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
