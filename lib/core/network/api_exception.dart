/// A failure from the Panergo API.
///
/// The backend renders every error as `{"error": "...", "code": "..."}`, so
/// [code] is the machine-readable half worth switching on and [message] is
/// already French prose in most cases.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  /// The request never reached the server.
  const ApiException.offline()
      : code = offlineCode,
        message = 'Vous êtes hors ligne',
        statusCode = null;

  /// The server was reached but answered with something unparseable.
  const ApiException.unexpected([this.statusCode])
      : code = 'UNEXPECTED',
        message = 'Une erreur inattendue est survenue';

  static const offlineCode = 'OFFLINE';

  /// The token is missing, expired or rejected. There is no refresh endpoint,
  /// so this always means "send them back to the OTP screen".
  bool get isUnauthenticated => code == 'UNAUTHENTICATED' || statusCode == 401;

  /// No network — the caller should fall back to cache or queue the send
  /// rather than showing an error.
  bool get isOffline => code == offlineCode;

  /// Validation failures come back as 422, not 400.
  bool get isValidation => statusCode == 422;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
