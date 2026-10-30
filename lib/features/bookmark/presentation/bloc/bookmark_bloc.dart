import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../series/domain/entities/series.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';

abstract class BookmarkEvent {
  const BookmarkEvent();
}

class BookmarkStarted extends BookmarkEvent {
  const BookmarkStarted();
}

class BookmarkRemoved extends BookmarkEvent {
  const BookmarkRemoved(this.seriesId);

  final int seriesId;
}

class BookmarkState {
  const BookmarkState({
    this.series = const <Series>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Series> series;
  final bool isLoading;

  /// Pesan error ASLI dari request API terakhir.
  final String? errorMessage;

  BookmarkState copyWith({
    List<Series>? series,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookmarkState(
      series: series ?? this.series,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// Bookmark dari API (butuh login). Belum masuk → error 'Masuk dulu...'
/// dari repository (UI menampilkan ajakan masuk, bukan daftar kosong
/// yang menyesatkan). Gagal API → error asli + Coba Lagi.
class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  BookmarkBloc(this._repository) : super(const BookmarkState()) {
    on<BookmarkStarted>(_onStarted);
    on<BookmarkRemoved>(_onRemoved);
  }

  final WalletRepository _repository;

  Future<void> _onStarted(
    BookmarkStarted event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final list = await _repository.getBookmarks();
      emit(state.copyWith(series: list, isLoading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    }
  }

  Future<void> _onRemoved(
    BookmarkRemoved event,
    Emitter<BookmarkState> emit,
  ) async {
    try {
      await _repository.removeBookmark(event.seriesId);
      add(const BookmarkStarted());
    } on ApiException catch (error) {
      emit(state.copyWith(errorMessage: error.message));
    }
  }
}
