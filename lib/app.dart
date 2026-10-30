import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/create/presentation/pages/create_page.dart';
import 'features/explore/presentation/pages/explore_page.dart';
import 'features/feed/domain/repositories/episode_repository.dart';
import 'features/feed/presentation/bloc/feed_bloc.dart';
import 'features/feed/presentation/bloc/feed_event.dart';
import 'features/feed/presentation/pages/feed_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';

class DracinApp extends StatelessWidget {
  const DracinApp({required this.repository, super.key});

  final EpisodeRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<EpisodeRepository>.value(
      value: repository,
      child: BlocProvider(
        create: (_) => FeedBloc(repository)..add(const FeedStarted()),
        child: MaterialApp(
          title: 'Dracin Reels',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const MainShell(),
        ),
      ),
    );
  }
}

/// Kerangka utama: 5 tab bawah dalam SATU daftar (mudah diubah uwa).
/// Urutan: Beranda, Jelajahi, +, Notifikasi, Profil.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _openEpisode(String episodeId) {
    context.read<FeedBloc>().add(FeedEpisodeJumped(episodeId));
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const FeedPage(),
      ExplorePage(onOpenEpisode: _openEpisode),
      const CreatePage(),
      const NotificationsPage(),
      ProfilePage(onOpenEpisode: _openEpisode),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (index) => setState(() => _index = index),
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Jelajahi',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              label: '+',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Notifikasi',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
