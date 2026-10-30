import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/pages/rewards_page.dart';
import '../bloc/feed_event.dart';

/// Bilah atas feed: judul aplikasi, pil koin, tab Untuk Anda/Mengikuti.
/// Pil koin menampilkan saldo dompet (API bila masuk, lokal bila belum)
/// dan membuka halaman Dompet & Hadiah saat diketuk.
class FeedTopBar extends StatelessWidget {
  const FeedTopBar({
    required this.tab,
    required this.onTabChanged,
    super.key,
  });

  final FeedTab tab;
  final ValueChanged<FeedTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Dracin',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'Reels',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                BlocBuilder<WalletBloc, WalletState>(
                  builder: (context, wallet) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RewardsPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.monetization_on,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${wallet.balance} Koin',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _TabPill(
                  label: 'Untuk Anda',
                  active: tab == FeedTab.forYou,
                  onTap: () => onTabChanged(FeedTab.forYou),
                ),
                const SizedBox(width: 12),
                _TabPill(
                  label: 'Mengikuti',
                  active: tab == FeedTab.following,
                  onTap: () => onTabChanged(FeedTab.following),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
