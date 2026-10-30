import 'dart:io';

import '../../../../core/api/api_client.dart';
import '../../domain/entities/admin_content.dart';
import '../../domain/repositories/admin_repository.dart';

/// Repository admin via API. Semua error diteruskan apa adanya
/// (401 tanpa token, 403 viewer) agar UI menampilkan pesan jelas.
class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> getAdminSeries() async {
    final data = await _api.getJson('/admin/series');
    if (data is! List) {
      return <Map<String, dynamic>>[];
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<String, dynamic>> createSeries(AdminSeriesForm form) async {
    final data = await _api.postJson('/admin/series', form.toJson());
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const ApiException('Respons pembuatan series tidak dikenali.');
  }

  @override
  Future<void> updateSeries(int id, AdminSeriesForm form) async {
    await _api.putJson('/admin/series/$id', form.toJson());
  }

  @override
  Future<void> deleteSeries(int id) async {
    await _api.delete('/admin/series/$id');
  }

  @override
  Future<Map<String, dynamic>> createEpisode(AdminEpisodeForm form) async {
    final data = await _api.postJson('/admin/episodes', form.toJson());
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const ApiException('Respons pembuatan episode tidak dikenali.');
  }

  @override
  Future<void> updateEpisode(int id, AdminEpisodeForm form) async {
    await _api.putJson('/admin/episodes/$id', form.toJson());
  }

  @override
  Future<void> deleteEpisode(int id) async {
    await _api.delete('/admin/episodes/$id');
  }

  @override
  Future<void> uploadSeriesCover(
    int seriesId,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    await _api.uploadFile(
      '/admin/series/$seriesId/cover',
      file,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> uploadEpisodeVideo(
    int episodeId,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    await _api.uploadFile(
      '/admin/episodes/$episodeId/video',
      file,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> uploadEpisodeSubtitle(
    int episodeId,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    await _api.uploadFile(
      '/admin/episodes/$episodeId/subtitle',
      file,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> uploadEpisodeThumbnail(
    int episodeId,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    await _api.uploadFile(
      '/admin/episodes/$episodeId/thumbnail',
      file,
      onProgress: onProgress,
    );
  }
}
