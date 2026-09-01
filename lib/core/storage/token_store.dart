import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Keeps the JWT and the signed-in user on the device.
///
/// The token goes to the platform keystore; the user summary rides along with
/// it so the app can restore a session without a round-trip on launch.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'panergo.jwt';
  static const _userKey = 'panergo.user';

  final FlutterSecureStorage _storage;

  /// Cached so the Dio interceptor does not hit the keystore on every request.
  String? _cachedToken;

  Future<String?> readToken() async {
    return _cachedToken ??= await _storage.read(key: _tokenKey);
  }

  Future<AppUser?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // A stored payload from an older build is not worth crashing over.
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    _cachedToken = session.token;
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _userKey,
      value: jsonEncode({
        'id': session.user.id,
        'name': session.user.name,
        'phone_number': session.user.phoneNumber,
        'neighborhood': session.user.neighborhood,
        'role': session.user.role.wire,
      }),
    );
  }

  Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
