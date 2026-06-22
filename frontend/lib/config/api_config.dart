import 'dart:io';

import 'package:flutter/foundation.dart';

/// Base URL of the Node/Express backend.
///
/// Production builds must pass `--dart-define=API_BASE_URL=https://your-api.onrender.com`
/// (done automatically by vercel.json). Falls back to LAN dev defaults otherwise:
/// - Web / desktop / iOS simulator: `localhost` reaches the host machine directly.
/// - Android emulator: `10.0.2.2` is the special alias for the host machine's `localhost`.
/// - Physical Android/iOS device on the same WiFi: replace with the host machine's LAN IP,
///   e.g. `http://10.56.101.232:4000` (find it via `ipconfig` on the backend host).
class ApiConfig {
  static const String _port = '4000';
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:$_port';
    // Physical device: use host machine's LAN IP. Emulator: use 10.0.2.2
    if (Platform.isAndroid) return 'http://172.20.10.6:$_port';
    return 'http://localhost:$_port';
  }

  static const String apiPrefix = '/api';

  /// Matches the backend's `deviceContextSchema.deviceType` enum.
  static String get deviceType {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'UNKNOWN';
  }
}
