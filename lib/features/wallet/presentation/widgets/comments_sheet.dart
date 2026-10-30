import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';

/// Lembar komentar episode (rombak total).
///
/// - Daftar dipaginasi (lazy): halaman berikut dimuat saat scroll
///   mendekati bawah; berhenti tepat saat total tercapai.
/// - Muat awal = skeleton baris (bentuk, bukan teks contoh).
/// - Kirim via API field `body` (kontrak backend AddComment).
/// - Error VALIDASI (400, mis. "wajib diisi") tampil teks merah TANPA
///   tombol "Coba Lagi" dan HILANG begitu pengguna mengetik lagi.
///   Error muat/jaringan tampil + tombol "Coba Lagi".
/// - Like komentar via API nyata (POST/DELETE /comments/{id}/like);
///   gagal → batal optimistis + pesan asli. Komentar tanpa id tidak
///   menampilkan tombol like (tidak bisa di-like).
/// - Belum masuk = pesan jelas, bukan kirim palsu.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({required this.episodeId, super.key});

  final int episodeId;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  static const int _pageSize = 20;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<EpisodeComment> _comments = <EpisodeComment>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;
  String? _loadError;
  String? _sendError;
  bool _sendErrorIsValidation = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTyping);
    _scroll.addListener(_onScroll);
    _loadPage(1);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTyping);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Error validasi lama hilang begitu pengguna mengetik lagi.
  void _onTyping() {
    if (_sendError != null && mounted) {
      setState(() => _sendError = null);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) {
      return;
    }
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _loadPage(_page + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (page == 1) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await context.read<WalletRepository>().getCommentsPage(
            widget.episodeId,
            page: page,
            limit: _pageSize,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        if (page == 1) {
          _comments = result.comments;
        } else {
          _comments = <EpisodeComment>[..._comments, ...result.comments];
        }
        _page = page;
        _total = result.total;
        _hasMore = _comments.length < _total;
        _loading = false;
        _loadingMore = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (page == 1) {
          _loadError = error.toString();
        }
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _sendError = 'Isi komentar wajib diisi.';
        _sendErrorIsValidation = true;
      });
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await context
          .read<WalletRepository>()
          .postComment(widget.episodeId, text);
      _controller.clear();
      await _loadPage(1);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sendError = error.message;
        _sendErrorIsValidation = error.statusCode == 400;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sendError = error.toString();
        _sendErrorIsValidation = false;
      });
    }
    if (mounted) {
      setState(() => _sending = false);
    }
  }

  Future<void> _toggleCommentLike(EpisodeComment comment) async {
    final index =
        _comments.indexWhere((item) => item.id == comment.id);
    if (index == -1 || comment.id == 0) {
      return;
    }
    final wasLiked = comment.likedByMe;
    setState(() {
      _comments[index] = comment.copyWith(
        likedByMe: !wasLiked,
        likeCount: (comment.likeCount + (wasLiked ? -1 : 1)).clamp(
          0,
          1 << 30,
        ),
      );
    });
    try {
      await context
          .read<WalletRepository>()
          .toggleCommentLike(comment.id, !wasLiked);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _comments[index] = comment);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _dateLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return '';
    }
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    final height = MediaQuery.of(context).size.height * 0.78;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: DracinSpacing.lg,
          right: DracinSpacing.lg,
          top: DracinSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + DracinSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DracinSheetHandle(),
            const SizedBox(height: DracinSpacing.md),
            Text(
              'Komentar${_total > 0 ? ' ($_total)' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: DracinSpacing.md),
            Expanded(child: _body()),
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.only(top: DracinSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _sendError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    // Tombol retry HANYA untuk gagal jaringan/server,
                    // bukan untuk error validasi.
                    if (!_sendErrorIsValidation)
                      TextButton(
                        onPressed: _send,
                        child: const Text('Coba Lagi'),
                      ),
                  ],
                ),
              ),
            if (!session.isAuthenticated)
              const Padding(
                padding: EdgeInsets.only(top: DracinSpacing.sm),
                child: Text(
                  'Masuk dulu untuk menulis komentar.',
                  style: TextStyle(color: DracinColors.textSecondary),
                ),
              ),
            const SizedBox(height: DracinSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Tulis komentar...',
                    ),
                  ),
                ),
                const SizedBox(width: DracinSpacing.md),
                Container(
                  decoration: const BoxDecoration(
                    color: DracinColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: !session.isAuthenticated || _sending
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView.separated(
        itemCount: 6,
        separatorBuilder: (_, __) =>
            const SizedBox(height: DracinSpacing.lg),
        itemBuilder: (_, __) => const DracinRowSkeleton(),
      );
    }
    if (_loadError != null) {
      return DracinErrorState(
        message: _loadError!,
        onRetry: () => _loadPage(1),
      );
    }
    if (_comments.isEmpty) {
      return const DracinEmptyState(
        icon: Icons.chat_bubble_outline,
        message: 'Belum ada komentar. Jadilah yang pertama.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: _comments.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _comments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: DracinSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final comment = _comments[index];
        final date = _dateLabel(comment.createdAt);
        return Padding(
          padding: const EdgeInsets.only(bottom: DracinSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DracinAvatar(name: comment.userName),
              const SizedBox(width: DracinSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            comment.userName,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: DracinColors.textHint,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (comment.id != 0)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        comment.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 20,
                        color: comment.likedByMe
                            ? DracinColors.accent
                            : DracinColors.textSecondary,
                      ),
                      onPressed: () => _toggleCommentLike(comment),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${comment.likeCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: DracinColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
