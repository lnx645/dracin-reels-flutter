import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api/api_client.dart';
import 'core/design/widgets.dart';
import 'core/navigation/route_observer.dart';
import 'core/session/session_cubit.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/data/repositories/admin_panel_repository_impl.dart';
import 'features/admin/domain/repositories/admin_panel_repository.dart';
import 'features/admin/domain/repositories/admin_repository.dart';
import 'features/admin/presentation/pages/login_page.dart';
import 'features/create/presentation/pages/create_page.dart';
import 'features/explore/presentation/pages/explore_page.dart';
import 'features/feed/domain/repositories/episode_repository.dart';
import 'features/feed/presentation/bloc/feed_bloc.dart';
import 'features/feed/presentation/bloc/feed_event.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/player/presentation/pages/player_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/series/domain/repositories/series_repository.dart';
import 'features/update/presentation/widgets/update_gate.dart';
import 'features/wallet/domain/repositories/wallet_repository.dart';
import 'features/wallet/presentation/bloc/wallet_bloc.dart';
import 'features/wallet/presentation/pages/rewards_page.dart';

class DracinApp extends StatelessWidget {
  const DracinApp({
    required this.repository,
    required this.apiClient,
    required this.sessionCubit,
    required this.walletBloc,
    required this.walletRepository,
    required this.seriesRepository,
    required this.adminRepository,
    super.key,
  });

  final EpisodeRepository repository;
  final ApiClient apiClient;
  final SessionCubit sessionCubit;
  final WalletBloc walletBloc;
  final WalletRepository walletRepository;
  final SeriesRepository seriesRepository;
  final AdminRepository adminRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<EpisodeRepository>.value(value: repository),
        RepositoryProvider<ApiClient>.value(value: apiClient),
        RepositoryProvider<WalletRepository>.value(value: walletRepository),
        RepositoryProvider<SeriesRepository>.value(value: seriesRepository),
        RepositoryProvider<AdminRepository>.value(value: adminRepository),
        RepositoryProvider<AdminPanelRepository>.value(
          value: AdminPanelRepositoryImpl(apiClient),
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<SessionCubit>.value(value: sessionCubit),
          BlocProvider<WalletBloc>.value(value: walletBloc),
          BlocProvider<FeedBloc>(
            create: (_) => FeedBloc(repository)..add(const FeedStarted()),
          ),
        ],
        child: BlocListener<SessionCubit, SessionState>(
          listenWhen: (previous, current) =>
              previous.status != current.status,
          listener: (context, state) {
            // Sesi berubah (masuk/keluar) → muat ulang dompet dari sumber
            // yang benar (API bila masuk, lokal bila keluar).
            context.read<WalletBloc>().add(const WalletRefreshed());
          },
          child: MaterialApp(
            title: 'Dracin Reels',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            navigatorObservers: <NavigatorObserver>[appRouteObserver],
            home: const UpdateGate(child: MainShell()),
            routes: <String, WidgetBuilder>{
              '/login': (_) => const LoginPage(),
              '/rewards': (_) => const RewardsPage(),
            },
          ),
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

  /// Satu halaman Player untuk semua jalur: feed, detail series,
  /// "Tonton Semua", Riwayat/Lanjutkan Nonton — ketuk episode di mana
  /// pun membuka PlayerPage yang sama (bukan putar inline di kartu).
  void _openEpisode(String episodeId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(episodeId: episodeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(onOpenEpisode: _openEpisode),
      ExplorePage(onOpenEpisode: _openEpisode),
      const CreatePage(),
      const NotificationsPage(),
      ProfilePage(onOpenEpisode: _openEpisode),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: DracinBottomNav(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }
}
