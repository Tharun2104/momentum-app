import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../domain/auth_user.dart';
import 'token_storage.dart';

class AuthRepository {
  AuthRepository({required this._tokenStorage, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: const {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
            ),
          );

  final TokenStorage _tokenStorage;
  final Dio _dio;

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(response.data!);
    await _tokenStorage.saveToken(session.accessToken);
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(response.data!);
    await _tokenStorage.saveToken(session.accessToken);
    return session;
  }

  Future<AuthUser> me() async {
    final token = await _tokenStorage.readToken();
    if (token == null) {
      throw const AuthException('No saved session.');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AuthUser.fromJson(response.data!);
  }

  Future<void> logout() {
    return _tokenStorage.clearToken();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
