import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_client.dart';
import '../domain/repositories/admin_repository.dart';

abstract class AdminEvent {
  const AdminEvent();
}

class AdminSeriesStarted extends AdminEvent {
  const AdminSeriesStarted();
}

class AdminSeriesDeleted extends AdminEvent {
  const AdminSeriesDeleted(this.id);

  final int id;
}

class AdminState {
  const AdminState({
    this.series = const <Map<String, dynamic>>[],
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  final List<Map<String, dynamic>> series;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  AdminState copyWith({
    List<Map<String, dynamic>>? series,
    bool? isLoading,
    String? errorMessage,
    String? infoMessage,
  }) {
    return AdminState(
      series: series ?? this.series,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }
}

/// Bloc daftar series admin (muat + hapus). Simpan/edit ditangani
/// halaman formulir (agar pesan sukses/gagal tampil di tempat).
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc(this._repository) : super(const AdminState()) {
    on<AdminSeriesStarted>(_onStarted);
    on<AdminSeriesDeleted>(_onDeleted);
  }

  final AdminRepository _repository;

  Future<void> _onStarted(
    AdminSeriesStarted event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final series = await _repository.getAdminSeries();
      emit(state.copyWith(series: series, isLoading: false));
    } on ApiException catch (error) {
      emit(
        state.copyWith(isLoading: false, errorMessage: error.message),
      );
    }
  }

  Future<void> _onDeleted(
    AdminSeriesDeleted event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await _repository.deleteSeries(event.id);
      final series = await _repository.getAdminSeries();
      emit(
        state.copyWith(
          series: series,
          infoMessage: 'Series dihapus.',
        ),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(errorMessage: error.message));
    }
  }
}
