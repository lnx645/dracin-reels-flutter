import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/admin_content.dart';
import '../../domain/repositories/admin_repository.dart';

/// Formulir tambah/edit series + upload cover (admin).
/// Gagal simpan/upload menampilkan pesan jelas — tidak pernah sukses palsu.
class SeriesFormPage extends StatefulWidget {
  const SeriesFormPage({this.existing, super.key});

  /// Data series lama (edit) atau null (tambah baru).
  final Map<String, dynamic>? existing;

  @override
  State<SeriesFormPage> createState() => _SeriesFormPageState();
}

class _SeriesFormPageState extends State<SeriesFormPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverController;
  late final TextEditingController _freeController;
  String _status = 'draft';
  PlatformFile? _coverFile;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(
      text: existing?['title'] is String ? existing!['title'] as String : '',
    );
    _descriptionController = TextEditingController(
      text: existing?['description'] is String
          ? existing!['description'] as String
          : '',
    );
    _coverController = TextEditingController(
      text: existing?['cover_url'] is String
          ? existing!['cover_url'] as String
          : '',
    );
    final free = existing?['free_episode_count'];
    _freeController = TextEditingController(
      text: free is int ? '$free' : '2',
    );
    final status = existing?['status'];
    if (status is String && (status == 'published' || status == 'draft')) {
      _status = status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coverController.dispose();
    _freeController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _coverFile = result.files.first);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Judul series wajib diisi.');
      return;
    }
    final free = int.tryParse(_freeController.text.trim());
    if (free == null || free < 0) {
      setState(
        () => _error = 'Jumlah episode gratis harus angka 0 atau lebih.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = context.read<AdminRepository>();
      final form = AdminSeriesForm(
        title: title,
        description: _descriptionController.text.trim(),
        coverUrl: _coverController.text.trim(),
        genreIds: const <int>[],
        freeEpisodeCount: free,
        status: _status,
      );
      int seriesId;
      final existing = widget.existing;
      final existingId = existing?['id'];
      if (_isEdit && existingId is int) {
        await repository.updateSeries(existingId, form);
        seriesId = existingId;
      } else {
        final created = await repository.createSeries(form);
        final createdId = created['id'];
        seriesId = createdId is int ? createdId : 0;
      }
      final coverFile = _coverFile;
      if (coverFile != null && coverFile.path != null) {
        await repository.uploadSeriesCover(
          seriesId,
          File(coverFile.path!),
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Series tersimpan.')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Series' : 'Tambah Series'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Judul series'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Deskripsi'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coverController,
              decoration: const InputDecoration(
                hintText: 'URL cover (opsional, bila tanpa upload)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _coverFile == null
                        ? 'Belum ada file cover dipilih.'
                        : 'Cover: ${_coverFile!.name}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _pickCover,
                  child: const Text('Pilih Cover'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _freeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Jumlah episode gratis',
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
                child: Text(_saving ? 'Menyimpan...' : 'Simpan Series'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Genre diatur lewat web admin untuk saat ini; aplikasi '
              'mobile mengirim daftar genre kosong.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
