import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/design/widgets.dart';
import '../../domain/entities/admin_panel.dart';
import '../../domain/repositories/admin_panel_repository.dart';
import '../bloc/admin_panel_bloc.dart';

/// Kelola Pengguna: daftar + cari (GET /admin/users?q=) + detail +
/// ubah role/status (PUT /admin/users/{id}). Lazy (20/halaman).
/// Error PUT (mis. ubah akun sendiri → 400) tampil apa adanya di
/// dialog, bukan ditutup-tutupi. Tanpa tombol hapus pengguna: backend
/// tidak menyediakan endpoint hapus — nonaktif adalah off-switch.
class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminUsersCubit(
        context.read<AdminPanelRepository>(),
      )..load(),
      child: const _AdminUsersView(),
    );
  }
}

class _AdminUsersView extends StatefulWidget {
  const _AdminUsersView();

  @override
  State<_AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<_AdminUsersView> {
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
      context.read<AdminUsersCubit>().loadMore();
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

  Future<void> _editUser(BuildContext context, AdminUser user) async {
    var role = user.role;
    var isActive = user.isActive;
    String? errorMessage;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(user.email),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Nama: ${user.name}'),
                  Text('Koin: ${user.coinBalance}'),
                  Text('VIP aktif: ${user.vipActive ? 'Ya' : 'Tidak'}'),
                  const SizedBox(height: 16),
                  const Text('Role'),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      DracinChip(
                        label: 'viewer',
                        selected: role == 'viewer',
                        onTap: () => setDialogState(() => role = 'viewer'),
                      ),
                      const SizedBox(width: 8),
                      DracinChip(
                        label: 'admin',
                        selected: role == 'admin',
                        onTap: () => setDialogState(() => role = 'admin'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      const Text('Akun aktif'),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                  if (errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await context.read<AdminUsersCubit>().saveUser(
                            user.copyWith(role: role, isActive: isActive),
                          );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } on ApiException catch (error) {
                      setDialogState(() => errorMessage = error.message);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengguna diperbarui.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DracinAppBar(title: 'Kelola Pengguna'),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => context
                        .read<AdminUsersCubit>()
                        .load(query: _searchController.text.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama atau email...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DracinButton(
                  label: 'Cari',
                  onPressed: () => context
                      .read<AdminUsersCubit>()
                      .load(query: _searchController.text.trim()),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<AdminUsersCubit, AdminUsersState>(
              builder: (context, state) {
                if (state.errorMessage != null) {
                  return DracinErrorState(
                    message: state.errorMessage!,
                    onRetry: () =>
                        context.read<AdminUsersCubit>().load(),
                  );
                }
                if (state.isLoading && state.users.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: DracinRowSkeleton(),
                    ),
                  );
                }
                if (state.users.isEmpty) {
                  return const DracinEmptyState(
                    icon: Icons.people_outline,
                    message: 'Belum ada pengguna yang cocok.',
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.users.length +
                      (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.users.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final user = state.users[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DracinCard(
                        onTap: () => _editUser(context, user),
                        child: Row(
                          children: <Widget>[
                            DracinAvatar(name: user.name),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${user.role} • '
                                    '${user.isActive ? 'Aktif' : 'Nonaktif'} • '
                                    '${user.coinBalance} koin'
                                    '${user.vipActive ? ' • VIP' : ''}',
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20),
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
      ),
    );
  }
}
