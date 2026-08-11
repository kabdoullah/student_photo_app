import 'package:dio/dio.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/login',
      data: {
        'username': username,
        'password': password,
        'grant_type': 'password',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final body = response.data ?? const <String, dynamic>{};
    final token = body['access_token'] ?? body['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Le serveur n’a pas retourné de jeton JWT.');
    }
    return token;
  }
}
