import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Default dev host (override by setting 'server_host' in SharedPreferences or env)
  static const String _defaultHost = '192.168.29.252';

  static String _cachedHost = _defaultHost;
  static bool _loaded = false;

  static String get serverHost => _cachedHost;

  /// Initializes host from SharedPreferences (non-blocking).
  /// Call once on app startup; falls back to default.
  static Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedHost = prefs.getString('server_host') ?? _defaultHost;
    } catch (_) {
      _cachedHost = _defaultHost;
    }
  }

  /// Updates host at runtime and persists it (for settings screen).
  static Future<void> setHost(String host) async {
    _cachedHost = host;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_host', host);
    } catch (_) {}
  }
}
