import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Status sesi pengguna.
enum SessionStatus { initial, loading, authenticated, guest, failure }

/// State sesi: token + data pengguna dari JWT/login API.
/// Role menentukan hak: `admin` melihat Panel Admin, `viewer` tidak.
class SessionState {
  const SessionState({
    this.status = SessionStatus.initial,
    this.token,
    this.userId,
    this.name,
    this.email,
    this.role,
    this.errorMessage,
  });

  final SessionStatus status;
  final String? token;
  final int? userId;
  final String? name;
  final String? email;
  final String? role;
  final String? errorMessage;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isAdmin => isAuthenticated && role == 'admin';

  SessionState copyWith({
    SessionStatus? status,
    String? token,
    int? userId,
    String? name,
    String? email,
    String? role,
    String? errorMessage,
  }) {
    return SessionState(
      status: status ?? this.status,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      errorMessage: errorMessage,
    );
  }
}

/// Cubit sesi: login JWT beneran ke API, simpan token di perangkat,
/// dan pulihkan sesi saat aplikasi dibuka lagi.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._api) : super(const SessionState());

  static const _keyToken = 'session_token';
  static const _keyUserId = 'session_user_id';
  static const _keyName = 'session_name';
  static const _keyEmail = 'session_email';
  static const _keyRole = 'session_role';

  final ApiClient _api;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null || token.isEmpty) {
      emit(state.copyWith(status: SessionStatus.guest));
      return;
    }
    _api.setToken(token);
    emit(
      state.copyWith(
        status: SessionStatus.authenticated,
        token: token,
        userId: prefs.getInt(_keyUserId),
        name: prefs.getString(_keyName),
        email: prefs.getString(_keyEmail),
        role: prefs.getString(_keyRole),
      ),
    );
  }

  Future<bool> login(String email, String password) async {
    emit(state.copyWith(status: SessionStatus.loading));
    try {
      final data = await _api.postJson('/auth/login', <String, dynamic>{
        'email': email,
        'password': password,
      });
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Respons login tidak dikenali.');
      }
      final token = data['token'];
      final user = data['user'];
      if (token is! String || user is! Map<String, dynamic>) {
        throw const ApiException('Respons login tidak dikenali.');
      }
      _api.setToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      final userId = user['id'];
      if (userId is int) {
        await prefs.setInt(_keyUserId, userId);
      }
      final name = user['name'];
      if (name is String) {
        await prefs.setString(_keyName, name);
      }
      await prefs.setString(_keyEmail, email);
      final role = user['role'];
      if (role is String) {
        await prefs.setString(_keyRole, role);
      }
      emit(
        SessionState(
          status: SessionStatus.authenticated,
          token: token,
          userId: userId is int ? userId : null,
          name: name is String ? name : null,
          email: email,
          role: role is String ? role : null,
        ),
      );
      return true;
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: error.message,
        ),
      );
      return false;
    }
  }

  Future<void> logout() async {
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
    emit(const SessionState(status: SessionStatus.guest));
  }
}
