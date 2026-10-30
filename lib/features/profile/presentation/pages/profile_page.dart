import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bookmark/presentation/pages/bookmark_page.dart';
import '../../feed/domain/repositories/episode_repository.dart';
import '../bloc/profile_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileBloc(
        context.read<EpisodeRepository>(),
      )..add(const ProfileStarted()),
      child: ProfileView(onOpenEpisode: onOpenEpisode),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({required this.onOpenEpisode, super.key});

  final void Function(String episodeId) onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final continueEpisode = state.continueEpisode;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 36,
                      child: Text(
                        'U',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Pengguna Dracin',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Profil contoh (UI saja)',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _Stat(label: 'Koin', value: '${state.coins}'),
                    _Stat(
                      label: 'Bookmark',
                      value: '${state.bookmarkCount}',
                    ),
                    _Stat(label: 'Disukai', value: '${state.likedCount}'),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Lanjutkan Nonton', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                if (continueEpisode != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: continueEpisode.gradient
                            .map(Color.new)
                            .toList(),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Episode ${continueEpisode.number} - '
                                '${continueEpisode.title}',
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                continueEpisode.description,
                                style: theme.textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () =>
                              onOpenEpisode(continueEpisode.id),
                          child: const Text('Tonton'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BookmarkPage(
                            onOpenEpisode: (episodeId) {
                              Navigator.of(context).pop();
                              onOpenEpisode(episodeId);
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text('Bookmark Saya'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
