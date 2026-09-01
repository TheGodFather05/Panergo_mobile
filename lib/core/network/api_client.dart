import 'dart:io';

import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Where the backend lives.
///
/// Supplied at build time so the same binary can point at a laptop, an emulator
/// host or a real deployment:
/// `flutter run --dart-define=PANERGO_API_BASE_URL=http://10.0.2.2:8080`
///
/// The default suits the Android emulator, where `10.0.2.2` is the host machine.
/// An iOS simulator shares the host's network, so it wants `localhost` instead.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'PANERGO_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// The STOMP endpoint. The backend registers `/ws` with SockJS enabled.
  static String get webSocketUrl => '$baseUrl/ws';
}

/// Called when the API rejects our token, so the app can drop to the login
/// screen. There is no refresh token — the JWT simply lasts 24h.
typedef OnUnauthenticated = void Function();

/// Reads the stored JWT, or null when signed out.
typedef TokenReader = Future<String?> Function();

class ApiClient {
  ApiClient({
    required TokenReader readToken,
    OnUnauthenticated? onUnauthenticated,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = ApiConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 20)
      ..contentType = Headers.jsonContentType
      // Let every status through to the error mapper rather than having Dio
      // throw its own opaque exception for 4xx.
      ..validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final status = response.statusCode ?? 0;
          if (status >= 400) {
            final failure = _asApiException(response);
            if (failure.isUnauthenticated) onUnauthenticated?.call();
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: failure,
              ),
            );
            return;
          }
          handler.next(response);
        },
      ),
    );
  }

  final Dio _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send(() => _dio.post<T>(
            path,
            data: body,
            options: headers == null ? null : Options(headers: headers),
          ));

  Future<T> put<T>(String path, {Object? body}) =>
      _send(() => _dio.put<T>(path, data: body));

  /// The backend's logout endpoint expects a body on DELETE, which is unusual
  /// but legal — Dio supports it.
  Future<T> delete<T>(String path, {Object? body}) =>
      _send(() => _dio.delete<T>(path, data: body));

  Future<T> _send<T>(Future<Response<T>> Function() send) async {
    try {
      final response = await send();
      return response.data as T;
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  ApiException _fromDio(DioException e) {
    final mapped = e.error;
    if (mapped is ApiException) return mapped;

    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const ApiException.offline(),
      _ when e.error is SocketException => const ApiException.offline(),
      _ => ApiException.unexpected(e.response?.statusCode),
    };
  }

  static ApiException _asApiException(Response<dynamic> response) {
    final data = response.data;
    if (data is Map) {
      final code = data['code'];
      final message = data['error'];
      if (code is String && message is String) {
        return ApiException(
          code: code,
          message: message,
          statusCode: response.statusCode,
        );
      }
    }
    return ApiException.unexpected(response.statusCode);
  }
}
