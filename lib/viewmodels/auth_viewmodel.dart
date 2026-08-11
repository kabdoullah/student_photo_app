import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/auth_repository.dart';

part 'auth_viewmodel.g.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://102.211.209.196:8189/',
);

const _accessTokenKey = 'access_token';

@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage();

class AuthSession {
  const AuthSession._({required this.isLoading, this.token});

  const AuthSession.loading() : this._(isLoading: true);
  const AuthSession.unauthenticated() : this._(isLoading: false);
  const AuthSession.authenticated(String token)
    : this._(isLoading: false, token: token);

  final bool isLoading;
  final String? token;
}

@Riverpod(keepAlive: true)
class AuthTokenNotifier extends _$AuthTokenNotifier {
  @override
  AuthSession build() {
    unawaited(_restoreSession());
    return const AuthSession.loading();
  }

  Future<void> _restoreSession() async {
    final storage = ref.read(secureStorageProvider);
    try {
      final token = await storage.read(key: _accessTokenKey);
      if (token != null && !_isTokenExpired(token)) {
        state = AuthSession.authenticated(token);
      } else {
        if (token != null) await storage.delete(key: _accessTokenKey);
        state = const AuthSession.unauthenticated();
      }
    } catch (_) {
      state = const AuthSession.unauthenticated();
    }
  }

  Future<void> setToken(String token) async {
    if (_isTokenExpired(token)) {
      throw const FormatException('Le jeton de session est invalide ou expiré.');
    }
    await ref.read(secureStorageProvider).write(key: _accessTokenKey, value: token);
    state = AuthSession.authenticated(token);
  }

  Future<void> clear() async {
    state = const AuthSession.unauthenticated();
    await ref.read(secureStorageProvider).delete(key: _accessTokenKey);
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final expiresAt = claims['exp'];
      if (expiresAt is! num) return true;
      return DateTime.now().isAfter(
        DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt() * 1000),
      );
    } catch (_) {
      return true;
    }
  }
}

@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final dio = Dio(BaseOptions(baseUrl: _apiBaseUrl));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider).token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          unawaited(ref.read(authTokenProvider.notifier).clear());
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepository(ref.watch(apiClientProvider));

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

@riverpod
class LoginViewModel extends _$LoginViewModel {
  @override
  FutureOr<void> build() {}

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final token = await ref
            .read(authRepositoryProvider)
            .login(username: username, password: password);
        await ref.read(authTokenProvider.notifier).setToken(token);
      } on DioException catch (error) {
        throw AuthException(switch (error.response?.statusCode) {
          401 || 403 => 'Identifiant ou mot de passe incorrect.',
          404 => 'Le service de connexion est introuvable.',
          _ => 'Impossible de joindre le service de connexion.',
        });
      } on SocketException {
        throw const AuthException(
          'Impossible de joindre le service de connexion.',
        );
      } on FormatException catch (error) {
        throw AuthException(error.message);
      } catch (_) {
        throw const AuthException(
          'Connexion impossible. Réessayez dans un instant.',
        );
      }
    });
  }
}
