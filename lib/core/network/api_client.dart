import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Where the backend lives.
///
/// Supplied at build time so the same binary can point at a laptop or a real
/// deployment:
/// `flutter build ios --dart-define=PANERGO_API_BASE_URL=https://api.panergo.cm`
///
/// There is no useful default, so there isn't one: an empty base URL fails
/// loudly at startup rather than quietly at every request.
///
/// Two earlier defaults each produced an app that installed cleanly and then
/// failed everything. `10.0.2.2` is the Android emulator's alias for its host
/// and means nothing on a handset. A `.local` Bonjour name resolves only once
/// iOS grants the local-network permission, and when that prompt never appears
/// the failure is silent and indistinguishable from a dead server.
///
/// So the host is passed in, and `scripts/dev_run.sh` resolves the developer
/// Mac's current address at build time — the laptop can still move, the lookup
/// just happens on the Mac, where it works, instead of on the phone, where it
/// is gated.
///
/// Emulators: `http://10.0.2.2:8080` on Android, `http://localhost:8080` on an
/// iOS simulator.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment('PANERGO_API_BASE_URL');

  /// Whether the build was told where the backend is.
  static bool get isConfigured => baseUrl.isNotEmpty;

  /// The STOMP endpoint. The backend registers `/ws` with SockJS enabled.
  static String get webSocketUrl => '$baseUrl/ws';

  /// Where the shared pages live.
  ///
  /// Not the API host: a link is read in WhatsApp by somebody who has never
  /// heard of Panergo, and `panergo.cm/b/garage-ndokotti` is what makes it look
  /// sent by the shopkeeper rather than forwarded by accident. Overridable so a
  /// dev build can point at a staging host instead of promising a domain that
  /// is not serving yet.
  static const shareBaseUrl = String.fromEnvironment(
    'PANERGO_SHARE_BASE_URL',
    defaultValue: 'https://panergo.cm',
  );

  /// Turns a stored path into something [Image.network] can fetch.
  ///
  /// Uploads come back as `/uploads/…` — a path, not a URL — because the server
  /// has no idea which host the app reached it on. Anything already absolute is
  /// handed straight back.
  static String absolute(String pathOrUrl) =>
      pathOrUrl.startsWith('http') ? pathOrUrl : '$baseUrl$pathOrUrl';
}

/// Called when the API rejects our token, so the app can drop to the login
/// screen. There is no refresh token — the JWT simply lasts 24h.
typedef OnUnauthenticated = void Function();

/// Reads the stored JWT, or null when signed out.
typedef TokenReader = Future<String?> Function();

class ApiClient {
  /// The longest any single request may take, whatever the cause.
  ///
  /// Above receiveTimeout so a slow-but-working response is not cut short, and
  /// far below a person's patience: a spinner past this point is a bug, not a
  /// slow network.
  static const _deadline = Duration(seconds: 25);

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
          // Bounded, because this runs *before* Dio starts its own timers: a
          // Keychain read that never returns — which happens on iOS when the
          // keychain is not yet unlocked after a cold launch — would otherwise
          // hang the request with no connectTimeout and no receiveTimeout ever
          // firing. That is what « Recherche en cours… » forever looked like.
          //
          // Failing open rather than closed: a request without the header comes
          // back 401 and the app signs in again, which is recoverable. A
          // request that never leaves is not.
          String? token;
          try {
            token = await readToken().timeout(const Duration(seconds: 5));
          } on TimeoutException {
            token = null;
          }
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

  /// Uploads one file as multipart.
  ///
  /// Routed through the same [_send] as everything else so an expired session
  /// and a mapped error behave here exactly as they do on any other call.
  Future<T> upload<T>(String path, {required File file, String field = 'file'}) async {
    final form = FormData.fromMap({
      field: await MultipartFile.fromFile(file.path),
    });
    return _send(() => _dio.post<T>(path, data: form));
  }

  Future<T> put<T>(String path, {Object? body}) =>
      _send(() => _dio.put<T>(path, data: body));

  Future<T> patch<T>(String path, {Object? body}) =>
      _send(() => _dio.patch<T>(path, data: body));

  /// The backend's logout endpoint expects a body on DELETE, which is unusual
  /// but legal — Dio supports it.
  Future<T> delete<T>(String path, {Object? body}) =>
      _send(() => _dio.delete<T>(path, data: body));

  Future<T> _send<T>(Future<Response<T>> Function() send) async {
    try {
      // A ceiling over the whole call, interceptors included. Dio's
      // connectTimeout and receiveTimeout only cover the socket, so anything
      // that stalls on either side of it — a blocked keychain read, a local
      // network permission never granted — would hang without either firing.
      // Nothing in this app is worth waiting longer than this for.
      final response = await send().timeout(_deadline);
      return response.data as T;
    } on TimeoutException {
      throw const ApiException.offline();
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
