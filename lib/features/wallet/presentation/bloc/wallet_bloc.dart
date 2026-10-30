import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../data/repositories/wallet_repository_impl.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';

abstract class WalletEvent {
  const WalletEvent();
}

class WalletStarted extends WalletEvent {
  const WalletStarted();
}

class WalletRefreshed extends WalletEvent {
  const WalletRefreshed();
}

class WalletCheckinRequested extends WalletEvent {
  const WalletCheckinRequested();
}

class WalletUnlockRequested extends WalletEvent {
  const WalletUnlockRequested({required this.episodeId, required this.price});

  final int episodeId;
  final int price;
}

class WalletVipClaimRequested extends WalletEvent {
  const WalletVipClaimRequested(this.plan);

  final String plan;
}

class WalletContinueSaved extends WalletEvent {
  const WalletContinueSaved({
    required this.episodeId,
    required this.title,
    required this.number,
    this.seriesId = 1,
    this.seriesTitle = 'CINTA SANG PENGUASA QIN',
  });

  final int episodeId;
  final String title;
  final int number;
  final int seriesId;
  final String seriesTitle;
}

class WalletState {
  const WalletState({
    this.balance = 100,
    this.isApiMode = false,
    this.isLoading = false,
    this.vip = const VipInfo(isActive: false),
    this.packages = const <CoinPackage>[],
    this.tasks = const <RewardTask>[],
    this.continueItems = const <ContinueItem>[],
    this.historyItems = const <HistoryEntry>[],
    this.errorMessage,
    this.infoMessage,
    this.lastUnlockedId,
  });

  final int balance;
  final bool isApiMode;
  final bool isLoading;
  final VipInfo vip;
  final List<CoinPackage> packages;
  final List<RewardTask> tasks;

  /// Lanjutkan Nonton — diturunkan dari riwayat (sumber yang sama).
  final List<ContinueItem> continueItems;

  /// Riwayat tonton lengkap, terbaru di atas.
  final List<HistoryEntry> historyItems;
  final String? errorMessage;
  final String? infoMessage;
  final int? lastUnlockedId;

  WalletState copyWith({
    int? balance,
    bool? isApiMode,
    bool? isLoading,
    VipInfo? vip,
    List<CoinPackage>? packages,
    List<RewardTask>? tasks,
    List<ContinueItem>? continueItems,
    List<HistoryEntry>? historyItems,
    String? errorMessage,
    String? infoMessage,
    int? lastUnlockedId,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      isApiMode: isApiMode ?? this.isApiMode,
      isLoading: isLoading ?? this.isLoading,
      vip: vip ?? this.vip,
      packages: packages ?? this.packages,
      tasks: tasks ?? this.tasks,
      continueItems: continueItems ?? this.continueItems,
      historyItems: historyItems ?? this.historyItems,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      lastUnlockedId: lastUnlockedId,
    );
  }
}

/// Bloc dompet: saldo, check-in, unlock, VIP, paket, tugas, lanjutan.
/// Semua aksi yang gagal menampilkan pesan jelas — tidak pernah diam-diam.
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc(this._repository) : super(const WalletState()) {
    on<WalletStarted>(_onStarted);
    on<WalletRefreshed>(_onRefresh);
    on<WalletCheckinRequested>(_onCheckin);
    on<WalletUnlockRequested>(_onUnlock);
    on<WalletVipClaimRequested>(_onVipClaim);
    on<WalletContinueSaved>(_onContinueSaved);
  }

  final WalletRepository _repository;

  Future<void> _loadAll(Emitter<WalletState> emit) async {
    final wallet = await _repository.getBalance();
    final vip = await _repository.getVip();
    final packages = await _repository.getPackages();
    final tasks = await _repository.getTasks();
    final history = await _repository.getHistory();
    final continueItems = history
        .map(
          (entry) => ContinueItem(
            episodeId: entry.episodeId,
            title: entry.title,
            number: entry.number,
            positionSeconds: entry.positionSeconds,
            finished: entry.finished,
          ),
        )
        .toList();
    emit(
      state.copyWith(
        balance: wallet.balance,
        isApiMode: wallet.isApiMode,
        vip: vip,
        packages: packages,
        tasks: tasks,
        historyItems: history,
        continueItems: continueItems,
      ),
    );
  }

  Future<void> _onStarted(
    WalletStarted event,
    Emitter<WalletState> emit,
  ) async {
    await _loadAll(emit);
  }

  Future<void> _onRefresh(
    WalletRefreshed event,
    Emitter<WalletState> emit,
  ) async {
    await _loadAll(emit);
  }

  Future<void> _onCheckin(
    WalletCheckinRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final balance = await _repository.checkin();
      emit(
        state.copyWith(
          isLoading: false,
          balance: balance,
          infoMessage: 'Check-in berhasil! Koin bertambah.',
        ),
      );
      await _loadAll(emit);
    } on ApiException catch (error) {
      emit(
        state.copyWith(isLoading: false, errorMessage: error.message),
      );
    }
  }

  Future<void> _onUnlock(
    WalletUnlockRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.unlockEpisode(event.episodeId);
      if (!state.isApiMode && _repository is WalletRepositoryImpl) {
        await _repository.deductLocal(event.price);
      }
      final wallet = await _repository.getBalance();
      emit(
        state.copyWith(
          isLoading: false,
          balance: wallet.balance,
          isApiMode: wallet.isApiMode,
          infoMessage: 'Episode terbuka! Selamat menonton.',
          lastUnlockedId: event.episodeId,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(isLoading: false, errorMessage: error.message),
      );
    }
  }

  Future<void> _onVipClaim(
    WalletVipClaimRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.claimVip(event.plan);
      final vip = await _repository.getVip();
      emit(
        state.copyWith(
          isLoading: false,
          vip: vip,
          infoMessage:
              'VIP (sampel) berhasil diklaim. Pembayaran beneran menyusul.',
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(isLoading: false, errorMessage: error.message),
      );
    }
  }

  Future<void> _onContinueSaved(
    WalletContinueSaved event,
    Emitter<WalletState> emit,
  ) async {
    await _repository.recordWatch(
      HistoryEntry(
        episodeId: event.episodeId,
        seriesId: event.seriesId,
        seriesTitle: event.seriesTitle,
        title: event.title,
        number: event.number,
        positionSeconds: 0,
        finished: false,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final history = await _repository.getHistory();
    final continueItems = history
        .map(
          (entry) => ContinueItem(
            episodeId: entry.episodeId,
            title: entry.title,
            number: entry.number,
            positionSeconds: entry.positionSeconds,
            finished: entry.finished,
          ),
        )
        .toList();
    emit(
      state.copyWith(
        historyItems: history,
        continueItems: continueItems,
      ),
    );
  }
}
