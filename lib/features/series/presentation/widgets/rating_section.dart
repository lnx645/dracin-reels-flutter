import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets.dart';
import '../../../../core/session/session_cubit.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';

/// Bagian rating series di halaman detail.
///
/// - Rata-rata + jumlah pemberi rating dihitung SERVER (GET
///   /series/{id}/ratings) — tidak pernah dikarang di klien.
/// - Rata-rata null = belum ada yang menilai → teks jujur.
/// - Ketuk bintang = beri/ubah rating 1-5 (POST {stars}, butuh login;
///   belum masuk → dialog ajakan masuk, bukan kirim palsu).
/// - Endpoint belum ter-deploy (404) → tampil "Belum ada rating"
///   (keadaan data yang benar saat ini), bukan layar error; begitu
///   backend mendarat, widget ini langsung hidup tanpa build baru.
/// - Gagal jaringan/server lain → pesan asli + tombol Coba Lagi.
class RatingSection extends StatefulWidget {
  const RatingSection({required this.seriesId, super.key});

  final int seriesId;

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  SeriesRatingSummary? _summary;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await context
          .read<SeriesRepository>()
          .getRating(widget.seriesId);
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      // 404 = endpoint rating tidak tersedia di server (keadaan lama
      // sebelum backend 5bc71fe ter-deploy): keadaan data saat ini
      // sama dengan "belum ada rating", bukan error yang harus
      // menakuti pengguna. Saat endpoint hidup, cabang ini tidak
      // terpakai karena GET /series/{id}/ratings mengembalikan
      // average_rating null + rating_count 0 untuk series yang belum
      // dinilai.
      if (error.statusCode == 404) {
        setState(() {
          _summary = const SeriesRatingSummary(
            average: null,
            count: 0,
          );
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _rate(int stars) async {
    final session = context.read<SessionCubit>().state;
    if (!session.isAuthenticated) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Masuk dulu'),
          content: const Text(
            'Masuk untuk memberi rating pada series ini.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Masuk'),
            ),
          ],
        ),
      );
      if (goLogin == true && mounted) {
        await Navigator.of(context).pushNamed('/login');
      }
      return;
    }
    setState(() => _submitting = true);
    try {
      final summary = await context
          .read<SeriesRepository>()
          .rateSeries(widget.seriesId, stars);
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating tersimpan.')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DracinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Rating Series',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: DracinSpacing.md),
          if (_loading)
            const DracinSkeletonBox(width: 220, height: 28)
          else if (_error != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text('Coba Lagi'),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: DracinStarRating(
                    average: _summary?.average,
                    count: _summary?.count ?? 0,
                    userStars: _summary?.userStars,
                    onRate: _submitting ? null : _rate,
                  ),
                ),
                if (_submitting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          if (!_loading && _error == null) ...<Widget>[
            const SizedBox(height: DracinSpacing.sm),
            const Text(
              'Ketuk bintang untuk memberi rating.',
              style: TextStyle(
                fontSize: 12,
                color: DracinColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
