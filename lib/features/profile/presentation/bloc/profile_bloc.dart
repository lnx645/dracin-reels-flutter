import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/entities/episode.dart';
import '../../../feed/domain/repositories/episode_repository.dart';

abstract class ProfileEvent {
  const ProfileEvent();
}

class ProfileStarted extends ProfileEvent {
  const ProfileStarted();
}

class ProfileState {
  const ProfileState({
    this.coins = 100,
    this.bookmarkCount = 0,
    this.likedCount = 0,
    this.continueEpisode,
  });

  final int coins;
  final int bookmarkCount;
  final int likedCount;
  final Episode? continueEpisode;

  ProfileState copyWith({
    int? coins,
    int? bookmarkCount,
    int? likedCount,
    Episode? continueEpisode,
  }) {
    return ProfileState(
      coins: coins ?? this.coins,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      likedCount: likedCount ?? this.likedCount,
      continueEpisode: continueEpisode ?? this.continueEpisode,
    );
  }
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._repository) : super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
  }

  final EpisodeRepository _repository;

  void _onStarted(ProfileStarted event, Emitter<ProfileState> emit) {
    final episodes = _repository.getEpisodes();
    emit(
      state.copyWith(
        bookmarkCount:
            episodes.where((episode) => episode.isBookmarked).length,
        likedCount: episodes.where((episode) => episode.isLiked).length,
        continueEpisode: episodes.isEmpty ? null : episodes.first,
      ),
    );
  }
}
