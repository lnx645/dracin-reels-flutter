import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Konfigurasi API. Base URL publik lewat proxy nginx VPS (HTTP, belum
/// HTTPS — sesuai kondisi backend saat ini, dicatat di README).
class ApiConfig {
  static const String baseUrl =
      'http://103.147.33.11:8095/dracin-api/api/v1';
  static const String mediaBase =
      'http://103.147.33.11:8095/dracin-api';
}

/// Error API dengan pesan Bahasa Indonesia dari server (bila ada).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Klien HTTP tipis untuk API Dracin Reels. Semua respons mengikuti
/// amplop backend: sukses `{success:true, data}`, gagal
/// `{success:false, error:{message}}`.
class ApiClient {
  ApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Pesan error dari body JSON, atau null bila body bukan JSON.
  String? _errorMessageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> &&
            error['message'] is String) {
          return error['message'] as String;
        }
      }
    } on Exception {
      return null;
    }
    return null;
  }

  Never _throwFrom(http.Response response) {
    var message = 'Terjadi kesalahan jaringan (${response.statusCode}).';
    final parsed = _errorMessageFromBody(response.body);
    if (parsed != null) {
      message = parsed;
    }
    if (response.statusCode == 401) {
      message = 'Sesi berakhir atau belum masuk. Silakan masuk kembali.';
    } else if (response.statusCode == 403) {
      message = 'Akun ini tidak punya hak untuk aksi tersebut.';
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwFrom(response);
    }
    if (response.body.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['success'] == false) {
        final error = decoded['error'];
        final message = error is Map<String, dynamic> &&
                error['message'] is String
            ? error['message'] as String
            : 'Terjadi kesalahan.';
        throw ApiException(message, statusCode: response.statusCode);
      }
      return decoded['data'];
    }
    return decoded;
  }

  Future<dynamic> getJson(String path) async {
    try {
      final response = await _http
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      return _decode(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _decode(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  Future<dynamic> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _http
          .put(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _decode(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  Future<void> delete(String path) async {
    try {
      final response = await _http
          .delete(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      _decode(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  /// Upload multipart khusus admin (field `file`, sesuai kontrak backend).
  /// Mengembalikan data JSON (mis. path media yang tersimpan).
  Future<dynamic> uploadFile(String path, File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$path'),
      );
      request.headers.addAll(_headers);
      request.headers.remove('Content-Type');
      final token = _token;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );
      final streamed = await request.send().timeout(
            const Duration(minutes: 5),
          );
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(
        'Upload gagal. Periksa koneksi internet dan ukuran file.',
      );
    }
  }
}
