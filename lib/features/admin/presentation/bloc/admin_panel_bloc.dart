import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../domain/entities/admin_panel.dart';
import '../../domain/repositories/admin_panel_repository.dart';

// ─── Dasbor ────────────────────────────────────────────────────────

class AdminDashboardState {
  const AdminDashboardState({
    this.stats,
    this.isLoading = false,
    this.errorMessage,
  });

  final AdminStats? stats;
  final bool isLoading;
  final String? errorMessage;

  AdminDashboardState copyWith({
    AdminStats? stats,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminDashboardState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  AdminDashboardCubit(this._repository)
      : super(const AdminDashboardState());

  final AdminPanelRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final stats = await _repository.getStats();
      emit(state.copyWith(stats: stats, isLoading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }
}

// ─── Pengguna ──────────────────────────────────────────────────────

class AdminUsersState {
  const AdminUsersState({
    this.users = const <AdminUser>[],
    this.query = '',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.page = 1,
    this.total = 0,
    this.errorMessage,
  });

  final List<AdminUser> users;
  final String query;
  final bool isLoading;
  final bool isLoadingMore;
  final int page;
  final int total;
  final String? errorMessage;

  bool get hasMore => total > 0 && page * _pageSize < total;

  static const int _pageSize = 20;

  AdminUsersState copyWith({
    List<AdminUser>? users,
    String? query,
    bool? isLoading,
    bool? isLoadingMore,
    int? page,
    int? total,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      total: total ?? this.total,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AdminUsersCubit extends Cubit<AdminUsersState> {
  AdminUsersCubit(this._repository) : super(const AdminUsersState());

  final AdminPanelRepository _repository;

  Future<void> load({String? query}) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      query: query ?? state.query,
    ));
    try {
      final result = await _repository.getUsers(
        page: 1,
        limit: AdminUsersState._pageSize,
        query: state.query.isEmpty ? null : state.query,
      );
      emit(state.copyWith(
        users: result.items,
        page: 1,
        total: result.total,
        isLoading: false,
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getUsers(
        page: state.page + 1,
        limit: AdminUsersState._pageSize,
        query: state.query.isEmpty ? null : state.query,
      );
      final seen = state.users.map((u) => u.id).toSet();
      emit(state.copyWith(
        users: <AdminUser>[
          ...state.users,
          ...result.items.where((u) => seen.add(u.id)),
        ],
        page: state.page + 1,
        total: result.total,
        isLoadingMore: false,
      ));
    } on ApiException {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Simpan perubahan role/status satu pengguna. Gagal (mis. ubah
  /// akun sendiri → 400) dilempar sebagai pesan asli untuk dialog.
  Future<void> saveUser(AdminUser edited) async {
    final updated = await _repository.updateUser(
      edited.id,
      role: edited.role,
      isActive: edited.isActive,
    );
    final users = state.users
        .map((u) => u.id == updated.id ? updated : u)
        .toList();
    emit(state.copyWith(users: users));
  }
}

// ─── Member VIP ────────────────────────────────────────────────────

class AdminMembersState {
  const AdminMembersState({
    this.members = const <AdminVipSubscription>[],
    this.statusFilter,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.page = 1,
    this.total = 0,
    this.errorMessage,
  });

  final List<AdminVipSubscription> members;
  final String? statusFilter;
  final bool isLoading;
  final bool isLoadingMore;
  final int page;
  final int total;
  final String? errorMessage;

  bool get hasMore => total > 0 && page * _pageSize < total;

  static const int _pageSize = 20;

  AdminMembersState copyWith({
    List<AdminVipSubscription>? members,
    String? statusFilter,
    bool clearFilter = false,
    bool? isLoading,
    bool? isLoadingMore,
    int? page,
    int? total,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminMembersState(
      members: members ?? this.members,
      statusFilter:
          clearFilter ? null : statusFilter ?? this.statusFilter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      total: total ?? this.total,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AdminMembersCubit extends Cubit<AdminMembersState> {
  AdminMembersCubit(this._repository) : super(const AdminMembersState());

  final AdminPanelRepository _repository;

  Future<void> load({String? statusFilter, bool clearFilter = false}) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      statusFilter: statusFilter,
      clearFilter: clearFilter,
    ));
    try {
      final result = await _repository.getVipSubscriptions(
        page: 1,
        limit: AdminMembersState._pageSize,
        status: state.statusFilter,
      );
      emit(state.copyWith(
        members: result.items,
        page: 1,
        total: result.total,
        isLoading: false,
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getVipSubscriptions(
        page: state.page + 1,
        limit: AdminMembersState._pageSize,
        status: state.statusFilter,
      );
      final seen = state.members.map((m) => m.id).toSet();
      emit(state.copyWith(
        members: <AdminVipSubscription>[
          ...state.members,
          ...result.items.where((m) => seen.add(m.id)),
        ],
        page: state.page + 1,
        total: result.total,
        isLoadingMore: false,
      ));
    } on ApiException {
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}

// ─── Transaksi koin ────────────────────────────────────────────────

class AdminTransactionsState {
  const AdminTransactionsState({
    this.transactions = const <AdminTransaction>[],
    this.typeFilter,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.page = 1,
    this.total = 0,
    this.errorMessage,
  });

  final List<AdminTransaction> transactions;
  final String? typeFilter;
  final bool isLoading;
  final bool isLoadingMore;
  final int page;
  final int total;
  final String? errorMessage;

  bool get hasMore => total > 0 && page * _pageSize < total;

  static const int _pageSize = 20;

  AdminTransactionsState copyWith({
    List<AdminTransaction>? transactions,
    String? typeFilter,
    bool clearFilter = false,
    bool? isLoading,
    bool? isLoadingMore,
    int? page,
    int? total,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminTransactionsState(
      transactions: transactions ?? this.transactions,
      typeFilter: clearFilter ? null : typeFilter ?? this.typeFilter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      total: total ?? this.total,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AdminTransactionsCubit extends Cubit<AdminTransactionsState> {
  AdminTransactionsCubit(this._repository)
      : super(const AdminTransactionsState());

  final AdminPanelRepository _repository;

  Future<void> load({String? typeFilter, bool clearFilter = false}) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      typeFilter: typeFilter,
      clearFilter: clearFilter,
    ));
    try {
      final result = await _repository.getTransactions(
        page: 1,
        limit: AdminTransactionsState._pageSize,
        type: state.typeFilter,
      );
      emit(state.copyWith(
        transactions: result.items,
        page: 1,
        total: result.total,
        isLoading: false,
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getTransactions(
        page: state.page + 1,
        limit: AdminTransactionsState._pageSize,
        type: state.typeFilter,
      );
      final seen = state.transactions.map((t) => t.id).toSet();
      emit(state.copyWith(
        transactions: <AdminTransaction>[
          ...state.transactions,
          ...result.items.where((t) => seen.add(t.id)),
        ],
        page: state.page + 1,
        total: result.total,
        isLoadingMore: false,
      ));
    } on ApiException {
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
