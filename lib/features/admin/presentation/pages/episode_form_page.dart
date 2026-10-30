import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../player/presentation/widgets/video_player_area.dart';
import '../../domain/entities/admin_content.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/upload_progress_dialog.dart';

enum VideoSource { upload, link }

/// Formulir tambah/edit episode (admin).
/// Video punya DUA pilihan (wajib satu terisi untuk episode baru):
/// upload file dari HP, ATAU tempel link eksternal http(s).
/// Upload tidak wajib bila link sudah diisi — dan sebaliknya.
class EpisodeFormPage extends StatefulWidget {
  const EpisodeFormPage({
    required this.seriesId,
    required this.seriesTitle,
    this.existing,
    super.key,
  });

  final int seriesId;
  final String seriesTitle;

  /// Data episode lama (edit) atau null (tambah baru).
  final Map<String, dynamic>? existing;

  @override
  State<EpisodeFormPage> createState() => _EpisodeFormPageState();
}

class _EpisodeFormPageState extends State<EpisodeFormPage> {
  late final TextEditingController _numberController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _videoUrlController;
  late final TextEditingController _priceController;
  String _status = 'draft';
  VideoSource _source = VideoSource.link;
  PlatformFile? _videoFile;
  PlatformFile? _subtitleFile;
  PlatformFile? _thumbnailFile;
  bool _saving = false;
  String? _error;

  /// Path upload yang sedang dipakai episode ini (dari `video_url` lama
  /// yang BUKAN link http — mis. `media/episodes/xxx.mp4`). Hanya info
  /// tampilan; nilai simpan tetap dibaca dari data lama saat _save.
  String _savedUploadPath = '';

  /// Pratinjau video: file lokal yang baru dipilih, atau URL tersimpan.
  /// Diperbarui tombol "Perbarui Pratinjau" (bukan tiap ketikan, supaya
  /// pemutar tidak init ulang terus-menerus).
  File? _previewFile;
  String? _previewUrl;
  final ValueNotifier<bool> _previewPlayRequest = ValueNotifier<bool>(false);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final number = existing?['number'];
    _numberController = TextEditingController(
      text: number is int ? '$number' : '',
    );
    _titleController = TextEditingController(
      text: existing?['title'] is String ? existing!['title'] as String : '',
    );
    _descriptionController = TextEditingController(
      text: existing?['description'] is String
          ? existing!['description'] as String
          : '',
    );
    final videoUrl = existing?['video_url'];
    // Toggle HARUS diturunkan dari video_url yang sebenarnya — inilah
    // cacat lama: semua video_url non-kosong dipaksa jadi "Link", padahal
    // path upload (media/...) bukan link dan tidak boleh tampil di kolom
    // link eksternal.
    if (videoUrl is String && videoUrl.isNotEmpty) {
      if (_isHttpUrl(videoUrl)) {
        _source = VideoSource.link;
        _videoUrlController = TextEditingController(text: videoUrl);
      } else {
        _source = VideoSource.upload;
        _videoUrlController = TextEditingController(text: '');
        _savedUploadPath = videoUrl;
      }
      _previewUrl = videoUrl;
    } else {
      _videoUrlController = TextEditingController(text: '');
    }
    final price = existing?['coin_price'];
    _priceController = TextEditingController(
      text: price is int ? '$price' : '0',
    );
    final status = existing?['status'];
    if (status is String && (status == 'published' || status == 'draft')) {
      _status = status;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    _priceController.dispose();
    _previewPlayRequest.dispose();
    super.dispose();
  }

  Future<void> _pickFile(
    ValueChanged<PlatformFile?> setter,
    FileType type,
  ) async {
    final file = await FilePicker.pickFile(type: type);
    if (file != null) {
      setter(file);
    }
  }

  bool _isHttpUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// Pratinjau dihitung dari input saat ini (file baru > link ketikan >
  /// video tersimpan). Dipanggil tombol "Perbarui Pratinjau" — bukan
  /// tiap ketikan, supaya pemutar tidak init ulang terus-menerus.
  void _refreshPreview() {
    setState(() {
      if (_videoFile != null && _videoFile!.path != null) {
        _previewFile = File(_videoFile!.path!);
        _previewUrl = null;
      } else if (_source == VideoSource.link) {
        _previewFile = null;
        final link = _videoUrlController.text.trim();
        _previewUrl = link.isEmpty ? null : link;
      } else {
        _previewFile = null;
        final saved = widget.existing?['video_url'];
        _previewUrl = saved is String && saved.isNotEmpty ? saved : null;
      }
      _previewPlayRequest.value = false;
    });
  }

  /// Satu upload dengan dialog progress nyata ("X / Y MB" + persen +
  /// bar). Dialog selalu ditutup (finally) sebelum sukses/error
  /// dilaporkan lewat jalur normal formulir.
  Future<void> _uploadWithProgress(
    String title,
    Future<void> Function(void Function(int sent, int total) onProgress)
        task,
  ) async {
    final progress = UploadProgress();
    final dialog = UploadProgressDialog(progress);
    dialog.show(context, title);
    try {
      await task(progress.update);
    } finally {
      if (mounted) {
        dialog.close(context);
      }
    }
  }

  Future<void> _save() async {
    final number = int.tryParse(_numberController.text.trim());
    if (number == null || number <= 0) {
      setState(() => _error = 'Nomor episode harus angka lebih dari 0.');
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Judul episode wajib diisi.');
      return;
    }
    final price = int.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      setState(() => _error = 'Harga koin harus angka 0 atau lebih.');
      return;
    }
    final link = _videoUrlController.text.trim();
    if (_source == VideoSource.link) {
      if (link.isEmpty) {
        setState(
          () => _error = 'Tempel link video eksternal (http/https).',
        );
        return;
      }
      if (!_isHttpUrl(link)) {
        setState(
          () => _error = 'Link video harus diawali http:// atau https://.',
        );
        return;
      }
    } else if (!_isEdit && _videoFile == null) {
      setState(
        () => _error =
            'Pilih file video untuk diupload, atau pakai link eksternal.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = context.read<AdminRepository>();
      // JANGAN hapus link video lama saat edit: bila sumber dialihkan ke
      // Upload lalu disimpan TANPA file baru, video_url lama harus tetap
      // terkirim (bukan ''). Hanya kirim '' untuk episode BARU tanpa file.
      final existingVideoUrl = widget.existing?['video_url'];
      final oldVideoUrl = existingVideoUrl is String ? existingVideoUrl : '';
      final formVideoUrl = _source == VideoSource.link
          ? link
          : (_isEdit ? oldVideoUrl : '');
      final form = AdminEpisodeForm(
        seriesId: widget.seriesId,
        number: number,
        title: title,
        description: _descriptionController.text.trim(),
        videoUrl: formVideoUrl,
        coinPrice: price,
        status: _status,
      );
      int episodeId;
      final existing = widget.existing;
      final existingId = existing?['id'];
      if (_isEdit && existingId is int) {
        await repository.updateEpisode(existingId, form);
        episodeId = existingId;
      } else {
        final created = await repository.createEpisode(form);
        final createdId = created['id'];
        episodeId = createdId is int ? createdId : 0;
      }
      final videoFile = _videoFile;
      if (_source == VideoSource.upload &&
          videoFile != null &&
          videoFile.path != null) {
        await _uploadWithProgress(
          'Mengunggah video…',
          (onProgress) => repository.uploadEpisodeVideo(
            episodeId,
            File(videoFile.path!),
            onProgress: onProgress,
          ),
        );
      }
      final subtitleFile = _subtitleFile;
      if (subtitleFile != null && subtitleFile.path != null) {
        await _uploadWithProgress(
          'Mengunggah subtitle…',
          (onProgress) => repository.uploadEpisodeSubtitle(
            episodeId,
            File(subtitleFile.path!),
            onProgress: onProgress,
          ),
        );
      }
      final thumbnailFile = _thumbnailFile;
      if (thumbnailFile != null && thumbnailFile.path != null) {
        await _uploadWithProgress(
          'Mengunggah thumbnail…',
          (onProgress) => repository.uploadEpisodeThumbnail(
            episodeId,
            File(thumbnailFile.path!),
            onProgress: onProgress,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Episode tersimpan.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'Gagal menyimpan. Periksa koneksi internet.',
        );
      }
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Widget _fileRow(String label, PlatformFile? file, VoidCallback onPick) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            file == null ? 'Belum dipilih.' : file.name,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: onPick, child: Text('Pilih $label')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_isEdit ? 'Edit' : 'Tambah'} Episode — ${widget.seriesTitle}',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Nomor episode'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Judul episode'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Deskripsi'),
            ),
            const SizedBox(height: 16),
            Text('Sumber Video', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<VideoSource>(
              segments: const <ButtonSegment<VideoSource>>[
                ButtonSegment(
                  value: VideoSource.upload,
                  label: Text('Upload File'),
                ),
                ButtonSegment(
                  value: VideoSource.link,
                  label: Text('Link Eksternal'),
                ),
              ],
              selected: <VideoSource>{_source},
              onSelectionChanged: (selection) {
                setState(() => _source = selection.first);
              },
            ),
            const SizedBox(height: 12),
            if (_source == VideoSource.link)
              TextField(
                controller: _videoUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://storage-anda/episode-1.mp4',
                ),
              )
            else ...<Widget>[
              _fileRow(
                'Video',
                _videoFile,
                () => _pickFile(
                  (file) => setState(() {
                    _videoFile = file;
                    _previewFile = file != null && file.path != null
                        ? File(file.path!)
                        : null;
                    if (file != null) {
                      _previewUrl = null;
                    }
                  }),
                  FileType.video,
                ),
              ),
              if (_isEdit) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Video lama tetap dipakai bila tidak memilih file baru.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (_savedUploadPath.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'File saat ini: $_savedUploadPath',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            const SizedBox(height: 16),
            Text('Pratinjau Video', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_previewFile != null ||
                (_previewUrl != null && _previewUrl!.isNotEmpty))
              AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPlayerArea(
                  key: ValueKey<String>(
                    'preview-${_previewFile?.path ?? _previewUrl}',
                  ),
                  videoUrl: _previewUrl ?? '',
                  localFile: _previewFile,
                  playRequest: _previewPlayRequest,
                  onPlayingChanged: (_) {},
                ),
              )
            else
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Belum ada video untuk dipratinjau.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _refreshPreview,
              child: const Text('Perbarui Pratinjau'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pratinjau memakai pemutar yang sama dengan halaman Player. '
              'Pastikan video berputar sebelum menekan Simpan.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _fileRow(
              'Subtitle',
              _subtitleFile,
              () => _pickFile(
                (file) => setState(() => _subtitleFile = file),
                FileType.any,
              ),
            ),
            const SizedBox(height: 12),
            _fileRow(
              'Thumbnail',
              _thumbnailFile,
              () => _pickFile(
                (file) => setState(() => _thumbnailFile = file),
                FileType.image,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Harga koin (0 = gratis)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(hintText: 'Status'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'draft', child: Text('Draf')),
                DropdownMenuItem(
                  value: 'published',
                  child: Text('Terbit'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Simpan Episode'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
