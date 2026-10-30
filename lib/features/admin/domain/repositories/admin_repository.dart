import 'dart:io';

import '../entities/admin_content.dart';

/// Kontrak repository admin: hanya dipanggil dengan JWT role=admin.
/// Viewer mendapat 403 dari API (bukan dari klien yang menyembunyikan).
abstract class AdminRepository {
  Future<List<Map<String, dynamic>>> getAdminSeries();
  Future<Map<String, dynamic>> createSeries(AdminSeriesForm form);
  Future<void> updateSeries(int id, AdminSeriesForm form);
  Future<void> deleteSeries(int id);
  Future<Map<String, dynamic>> createEpisode(AdminEpisodeForm form);
  Future<void> updateEpisode(int id, AdminEpisodeForm form);
  Future<void> deleteEpisode(int id);
  Future<void> uploadSeriesCover(
    int seriesId,
    File file, {
    void Function(int sent, int total)? onProgress,
  });
  Future<void> uploadEpisodeVideo(
    int episodeId,
    File file, {
    void Function(int sent, int total)? onProgress,
  });
  Future<void> uploadEpisodeSubtitle(
    int episodeId,
    File file, {
    void Function(int sent, int total)? onProgress,
  });
  Future<void> uploadEpisodeThumbnail(
    int episodeId,
    File file, {
    void Function(int sent, int total)? onProgress,
  });
}
