import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/session/session_cubit.dart';
import 'features/admin/data/repositories/admin_repository_impl.dart';
import 'features/feed/data/datasources/sample_episode_datasource.dart';
import 'features/feed/data/repositories/episode_repository_impl.dart';
import 'features/feed/domain/repositories/episode_repository.dart';
import 'features/series/data/repositories/series_repository_impl.dart';
import 'features/wallet/data/repositories/wallet_repository_impl.dart';
import 'features/wallet/presentation/bloc/wallet_bloc.dart';

void main() {
  final apiClient = ApiClient();
  final sessionCubit = SessionCubit(apiClient)..initialize();
  final walletRepository = WalletRepositoryImpl(
    apiClient,
    tokenProvider: () => sessionCubit.state.token,
  );
  final walletBloc = WalletBloc(walletRepository)
    ..add(const WalletStarted());
  final EpisodeRepository repository =
      EpisodeRepositoryImpl(SampleEpisodeDataSource());
  runApp(
    DracinApp(
      repository: repository,
      apiClient: apiClient,
      sessionCubit: sessionCubit,
      walletBloc: walletBloc,
      walletRepository: walletRepository,
      seriesRepository: SeriesRepositoryImpl(apiClient),
      adminRepository: AdminRepositoryImpl(apiClient),
    ),
  );
}
