import 'package:flutter/material.dart';

import 'colors.dart';

/// Pustaka komponen custom Dracin Reels (rombak total).
///
/// Bukan widget Material mentah: tombol, chip, kartu, app bar, navigasi
/// bawah, skeleton, dan rating dirancang khusus di sini agar semua layar
/// berbagi satu bahasa visual. Widget Material dasar (Text, Icon,
/// GestureDetector) tetap dipakai sebagai bahan bangunan — yang custom
/// adalah KOMPOSISInya, bukan klaim tanpa widget Material sama sekali.

/// Tombol utama: pil oranye, tinggi 48, teks tebal. Varian ghost =
/// permukaan gelap + border; danger = merah (aksi merusak saja).
class DracinButton extends StatelessWidget {
  const DracinButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = DracinButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final DracinButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final BorderSide side;
    switch (variant) {
      case DracinButtonVariant.primary:
        background = DracinColors.accent;
        foreground = Colors.white;
        side = BorderSide.none;
      case DracinButtonVariant.ghost:
        background = DracinColors.surface;
        foreground = Colors.white;
        side = const BorderSide(color: DracinColors.border);
      case DracinButtonVariant.danger:
        background = DracinColors.danger;
        foreground = Colors.white;
        side = BorderSide.none;
    }
    final effectivePressed = isLoading ? null : onPressed;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: effectivePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: DracinColors.surface,
          disabledForegroundColor: DracinColors.textHint,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(DracinSpacing.radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 20),
                    const SizedBox(width: DracinSpacing.sm),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

enum DracinButtonVariant { primary, ghost, danger }

/// Chip pil custom: terpilih = oranye + teks putih tebal; tidak terpilih
/// = permukaan gelap + border halus. Satu baris geser, tanpa wrap yatim.
class DracinChip extends StatelessWidget {
  const DracinChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DracinSpacing.lg,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? DracinColors.accent : DracinColors.surface,
          border: Border.all(
            color: selected ? DracinColors.accent : DracinColors.border,
          ),
          borderRadius:
              BorderRadius.circular(DracinSpacing.radiusChip),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : DracinColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Kartu custom: permukaan kartu + radius 16 + border halus.
class DracinCard extends StatelessWidget {
  const DracinCard({
    required this.child,
    this.padding = const EdgeInsets.all(DracinSpacing.lg),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: DracinColors.card,
        border: Border.all(color: DracinColors.border),
        borderRadius:
            BorderRadius.circular(DracinSpacing.radiusCard),
      ),
      child: child,
    );
    if (onTap == null) {
      return card;
    }
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Header seksi: judul tebal + aksi teks di kanan (opsional).
class DracinSectionHeader extends StatelessWidget {
  const DracinSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DracinSpacing.sm,
                vertical: DracinSpacing.xs,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DracinColors.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Keadaan kosong yang jujur: ikon + pesan + aksi opsional.
/// Bukan data contoh — hanya menyatakan tidak ada data.
class DracinEmptyState extends StatelessWidget {
  const DracinEmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DracinSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: DracinColors.textHint),
            const SizedBox(height: DracinSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: DracinSpacing.lg),
              DracinButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keadaan gagal yang jujur: pesan ASLI server + tombol Coba Lagi.
/// Dipakai untuk gagal muat/jaringan — BUKAN untuk error validasi
/// (validasi memakai teks merah tanpa tombol, lihat CommentsSheet).
class DracinErrorState extends StatelessWidget {
  const DracinErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DracinSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off,
              size: 56,
              color: DracinColors.textHint,
            ),
            const SizedBox(height: DracinSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DracinSpacing.lg),
            DracinButton(label: 'Coba Lagi', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

/// Gagang tarik sheet bawah custom.
class DracinSheetHandle extends StatelessWidget {
  const DracinSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: DracinColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// App bar custom (bukan AppBar Material): tombol kembali + judul +
/// aksi. Latar = latar layar, tanpa bayangan.
class DracinAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DracinAppBar({
    required this.title,
    this.actions = const <Widget>[],
    this.showBack = true,
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        color: DracinColors.background,
        padding: const EdgeInsets.symmetric(horizontal: DracinSpacing.sm),
        child: Row(
          children: <Widget>[
            if (showBack)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Avatar lingkaran: inisial nama atau ikon orang bila tanpa nama.
class DracinAvatar extends StatelessWidget {
  const DracinAvatar({required this.name, this.radius = 16, super.key});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? ''
        : name.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: DracinColors.card,
      child: initial.isEmpty
          ? Icon(Icons.person, size: radius, color: Colors.white)
          : Text(
              initial,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: radius,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }
}

/// Navigasi bawah custom: 5 item, tombol + tengah menonjol (lingkaran
/// oranye). Dipakai MainShell sebagai pengganti BottomNavigationBar
/// mentah — perilaku tab sama, tampilannya milik Dracin.
class DracinBottomNav extends StatelessWidget {
  const DracinBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Beranda', 'Jelajahi', '+', 'Notifikasi', 'Profil'];
    const icons = <IconData>[
      Icons.home_outlined,
      Icons.explore_outlined,
      Icons.add,
      Icons.notifications_outlined,
      Icons.person_outline,
    ];
    const activeIcons = <IconData>[
      Icons.home,
      Icons.explore,
      Icons.add,
      Icons.notifications,
      Icons.person,
    ];
    return Container(
      color: DracinColors.surface,
      padding: const EdgeInsets.only(top: DracinSpacing.sm, bottom: 4),
      child: Row(
        children: List<Widget>.generate(5, (index) {
          final selected = index == currentIndex;
          final isCenter = index == 2;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (isCenter)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: DracinColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                  else
                    Icon(
                      selected ? activeIcons[index] : icons[index],
                      color: selected
                          ? Colors.white
                          : DracinColors.textHint,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : DracinColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Animasi kilau skeleton: gradasi yang bergeser di atas bentuk kosong.
/// Skeleton HANYA bentuk (bukan judul/angka/gambar karangan).
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final slide = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1 + slide, 0),
              end: Alignment(1 + slide, 0),
              colors: const <Color>[
                DracinColors.skeletonBase,
                DracinColors.skeletonHighlight,
                DracinColors.skeletonBase,
              ],
              stops: const <double>[0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Satu balok skeleton (kotak abu-abu berdenyut).
class DracinSkeletonBox extends StatelessWidget {
  const DracinSkeletonBox({
    required this.width,
    required this.height,
    this.radius = DracinSpacing.radiusThumb,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: DracinColors.skeletonBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton kartu reels (area video + judul + tombol) untuk muat awal
/// feed. Bentuknya mengikuti kartu asli, tanpa teks/angka contoh.
class DracinReelSkeleton extends StatelessWidget {
  const DracinReelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DracinSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: DracinSkeletonBox(
              width: double.infinity,
              height: double.infinity,
              radius: DracinSpacing.radiusCard,
            ),
          ),
          const SizedBox(height: DracinSpacing.lg),
          const DracinSkeletonBox(width: 180, height: 18),
          const SizedBox(height: DracinSpacing.sm),
          const DracinSkeletonBox(width: 120, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton baris daftar (avatar + 2 baris teks) untuk komentar,
/// riwayat, bookmark, dan tabel admin.
class DracinRowSkeleton extends StatelessWidget {
  const DracinRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DracinSkeletonBox(width: 40, height: 40, radius: 20),
        SizedBox(width: DracinSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DracinSkeletonBox(width: 120, height: 14),
              SizedBox(height: DracinSpacing.sm),
              DracinSkeletonBox(width: double.infinity, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton kartu grid (poster + judul) untuk Jelajahi/Beranda.
class DracinGridSkeleton extends StatelessWidget {
  const DracinGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DracinSkeletonBox(
          width: double.infinity,
          height: 180,
          radius: DracinSpacing.radiusCard,
        ),
        SizedBox(height: DracinSpacing.sm),
        DracinSkeletonBox(width: double.infinity, height: 14),
        SizedBox(height: DracinSpacing.xs),
        DracinSkeletonBox(width: 90, height: 12),
      ],
    );
  }
}

/// Skeleton grid COMPACT 3 kolom (pasangan grid Jelajahi baru):
/// kotak poster 3:4 + 2 garis kecil per sel, tanpa data karangan.
class DracinCompactGridSkeleton extends StatelessWidget {
  const DracinCompactGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 12,
      childAspectRatio: 0.52,
      padding: const EdgeInsets.only(bottom: 8),
      children: List<Widget>.generate(
        12,
        (_) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 3 / 4,
              child: DracinSkeletonBox(
                width: double.infinity,
                height: double.infinity,
                radius: 12,
              ),
            ),
            SizedBox(height: 6),
            DracinSkeletonBox(width: double.infinity, height: 12),
            SizedBox(height: 4),
            DracinSkeletonBox(width: 60, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Bintang rating: tampil (rata-rata + jumlah) atau input (ketuk).
/// Rata-rata null = belum ada yang menilai: tampil teks jujur, bukan
/// bintang kosong yang dikira nilai 0.
class DracinStarRating extends StatelessWidget {
  const DracinStarRating({
    this.average,
    this.count = 0,
    this.userStars,
    this.onRate,
    this.size = 28,
    super.key,
  });

  /// Rata-rata dari API (null = belum ada data rating).
  final double? average;

  /// Jumlah pemberi rating (0 bila belum ada).
  final int count;

  /// Bintang pengguna yang sedang masuk (null = belum menilai).
  final int? userStars;

  /// Bila diisi, bintang bisa diketuk (1-5). Null = tampil saja.
  final ValueChanged<int>? onRate;

  final double size;

  @override
  Widget build(BuildContext context) {
    if (average == null && userStars == null) {
      return const Row(
        children: <Widget>[
          Icon(Icons.star_border, color: DracinColors.textHint),
          SizedBox(width: DracinSpacing.sm),
          Text(
            'Belum ada rating',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: DracinColors.textSecondary,
            ),
          ),
        ],
      );
    }
    final display = userStars ?? average ?? 0;
    final full = display.floor();
    final hasHalf = display - full >= 0.5;
    return Row(
      children: <Widget>[
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onRate == null ? null : () => onRate!(i),
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                i <= full
                    ? Icons.star
                    : (i == full + 1 && hasHalf
                        ? Icons.star_half
                        : Icons.star_border),
                size: size,
                color: i <= full || (i == full + 1 && hasHalf)
                    ? DracinColors.gold
                    : DracinColors.textHint,
              ),
            ),
          ),
        const SizedBox(width: DracinSpacing.sm),
        Text(
          average == null
              ? 'Rating Anda: $userStars'
              : '${average!.toStringAsFixed(1)} ($count)',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DracinColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
