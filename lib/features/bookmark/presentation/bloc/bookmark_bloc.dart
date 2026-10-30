import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/entities/episode.dart';
import '../../../feed/domain/repositories/episode_repository.dart';

abstract class BookmarkEvent {
  const BookmarkEvent();
}

class BookmarkStarted extends BookmarkEvent {
  const BookmarkStarted();
}

class BookmarkRemoved extends BookmarkEvent {
  const BookmarkRemoved(this.id);

  final String id;
}

class BookmarkState {
  const BookmarkState({this.episodes = const <Episode>[]});

  final List<Episode> episodes;

  BookmarkState copyWith({List<Episode>? episodes}) {
    return BookmarkState(episodes: episodes ?? this.episodes);
  }
}

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  BookmarkBloc(this._repository) : super(const BookmarkState()) {
    on<BookmarkStarted>(_onStarted);
    on<BookmarkRemoved>(_onRemoved);
  }

  final EpisodeRepository _repository;

  List<Episode> _bookmarked() {
    return _repository
        .getEpisodes()
        .where((episode) => episode.isBookmarked)
        .toList();
  }

  void _onStarted(BookmarkStarted event, Emitter<BookmarkState> emit) {
    emit(state.copyWith(episodes: _bookmarked()));
  }

  void _onRemoved(BookmarkRemoved event, Emitter<BookmarkState> emit) {
    _repository.toggleBookmark(event.id);
    emit(state.copyWith(episodes: _bookmarked()));
  }
}
