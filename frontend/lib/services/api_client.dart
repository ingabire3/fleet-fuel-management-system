import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Thrown for any non-2xx response. [message] mirrors the backend's
/// `ErrorResponse.error.message`; [details] carries zod field errors, if any.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiException(this.statusCode, this.message, [this.details]);

  @override
  String toString() => message;
}

/// Thin REST client for the Fleet Fuel backend.
///
/// Persists the JWT access/refresh tokens (and the last-known user profile)
/// in [SharedPreferences], attaches the `Authorization` header automatically,
/// and transparently refreshes the access token once on a 401 before retrying.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _kAccessToken = 'auth.accessToken';
  static const _kRefreshToken = 'auth.refreshToken';
  static const _kUser = 'auth.user';
  static const _kDeviceId = 'auth.deviceId';

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  String? _deviceId;

  bool get isLoggedIn => _refreshToken != null;
  Map<String, dynamic>? get cachedUser => _user;
  String get deviceId => _deviceId!;
  String? get refreshToken => _refreshToken;

  /// Loads any persisted session. Call once at app startup before reading
  /// [isLoggedIn] / [cachedUser].
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessToken);
    _refreshToken = prefs.getString(_kRefreshToken);
    final userJson = prefs.getString(_kUser);
    _user = userJson != null ? jsonDecode(userJson) as Map<String, dynamic> : null;

    _deviceId = prefs.getString(_kDeviceId);
    if (_deviceId == null) {
      _deviceId = _generateDeviceId();
      await prefs.setString(_kDeviceId, _deviceId!);
    }
  }

  String _generateDeviceId() {
    final rand = Random();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Persists tokens + user profile after a successful login/OTP verify/refresh.
  Future<void> setSession({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (user != null) _user = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kRefreshToken, refreshToken);
    if (user != null) await prefs.setString(_kUser, jsonEncode(user));
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUser);
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanQuery = query?.map((k, v) => MapEntry(k, v.toString()));
    return Uri.parse('${ApiConfig.baseUrl}${ApiConfig.apiPrefix}$path')
        .replace(queryParameters: cleanQuery?.isEmpty ?? true ? null : cleanQuery);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) => _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool isRetry = false,
  }) async {
    final uri = _uri(path, query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_accessToken != null) headers['Authorization'] = 'Bearer $_accessToken';

    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await _dispatch(method, uri, headers, encodedBody);

    if (response.statusCode == 401 && !isRetry && _refreshToken != null && path != '/auth/refresh') {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path, body: body, query: query, isRetry: true);
      }
    }

    return _decode(response);
  }

  static const _timeout = Duration(seconds: 12);

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    final Future<http.Response> req;
    switch (method) {
      case 'GET':
        req = http.get(uri, headers: headers);
        break;
      case 'POST':
        req = http.post(uri, headers: headers, body: body);
        break;
      case 'PATCH':
        req = http.patch(uri, headers: headers, body: body);
        break;
      case 'DELETE':
        req = http.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported method: $method');
    }
    return req.timeout(_timeout, onTimeout: () {
      throw ApiException(0, 'Network timeout — check your connection and try again.');
    });
  }

  Future<bool> _tryRefresh() async {
    try {
      final response = await http.post(
        _uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': _refreshToken,
          'deviceId': _deviceId,
          'deviceType': 'UNKNOWN',
        }),
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        await clearSession();
        return false;
      }
      final data = _decode(response) as Map<String, dynamic>;
      final tokens = data['data'] as Map<String, dynamic>;
      await setSession(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await clearSession();
      return false;
    }
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final error = (body is Map<String, dynamic>) ? body['error'] as Map<String, dynamic>? : null;
    throw ApiException(
      response.statusCode,
      error?['message'] as String? ?? 'Request failed (${response.statusCode})',
      error?['details'] as Map<String, dynamic>?,
    );
  }
}
