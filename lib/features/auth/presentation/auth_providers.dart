import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/token_storage.dart';
import '../domain/auth_user.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(tokenStorage: ref.watch(tokenStorageProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.watch(authRepositoryProvider));
  },
);

class AuthState {
  const AuthState({
    required this.isLoading,
    required this.user,
    this.errorMessage,
  });

  const AuthState.loading() : this(isLoading: true, user: null);

  const AuthState.signedOut({String? errorMessage})
    : this(isLoading: false, user: null, errorMessage: errorMessage);

  const AuthState.signedIn(AuthUser user) : this(isLoading: false, user: user);

  final bool isLoading;
  final AuthUser? user;
  final String? errorMessage;

  bool get isAuthenticated => user != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.loading()) {
    _restoreSession();
  }

  final AuthRepository _repository;

  Future<void> _restoreSession() async {
    try {
      final user = await _repository.me();
      state = AuthState.signedIn(user);
    } catch (_) {
      await _repository.logout();
      state = const AuthState.signedOut();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final session = await _repository.register(
        name: name,
        email: email,
        password: password,
      );
      state = AuthState.signedIn(session.user);
    } catch (error) {
      final message = _authErrorMessage(error);
      state = AuthState.signedOut(errorMessage: message);
      throw AuthException(message);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.loading();
    try {
      final session = await _repository.login(email: email, password: password);
      state = AuthState.signedIn(session.user);
    } catch (error) {
      final message = _authErrorMessage(error);
      state = AuthState.signedOut(errorMessage: message);
      throw AuthException(message);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState.signedOut();
  }

  String _authErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
      return error.message ?? 'Authentication failed.';
    }
    return error.toString();
  }
}
