import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Highly advanced network response caching layer to eliminate latency and lag.
/// Implements the Stale-While-Revalidate (SWR) design pattern for instant loading.
class HttpCacheService {
  static final Map<String, String> _memoryCache = {};
  static bool _initialized = false;

  /// Preload cache from persistent local storage during app startup
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int loadedCount = 0;
      for (final key in keys) {
        if (key.startsWith('http_cache_')) {
          final cachedValue = prefs.getString(key);
          if (cachedValue != null) {
            final originalUrl = key.substring('http_cache_'.length);
            _memoryCache[originalUrl] = cachedValue;
            loadedCount++;
          }
        }
      }
      debugPrint('⚡ [HttpCacheService] Preloaded $loadedCount API responses from local persistence.');
    } catch (e) {
      debugPrint('❌ [HttpCacheService] Failed to initialize persistent cache: $e');
    }
  }

  /// Get resource from cache instantly, then refresh cache in the background (Stale-While-Revalidate)
  static Future<http.Response> get(Uri uri, {Map<String, String>? headers, bool forceRefresh = false}) async {
    final url = uri.toString();
    
    // Check memory cache
    final cachedData = _memoryCache[url];

    if (cachedData != null && !forceRefresh) {
      // Async revalidation in the background to ensure fresh cache for next time
      _backgroundRevalidate(uri, headers);

      // Return memory cache immediately - 0ms latency, zero lag!
      return http.Response(cachedData, 200, headers: {
        'content-type': 'application/json; charset=utf-8',
        'x-cache': 'HIT',
      });
    }

    // Direct network call if no cache exists or refresh is explicitly requested
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        await _saveToCache(url, response.body);
      }
      return response;
    } catch (e) {
      // If network fails (offline or poor connection), try fallback to cache
      if (cachedData != null) {
        debugPrint('🔌 [HttpCacheService] Network failed. Using offline cached fallback for $url');
        return http.Response(cachedData, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
          'x-cache': 'OFFLINE_FALLBACK',
        });
      }
      rethrow;
    }
  }

  /// Perform asynchronous revalidation without blocking UI
  static void _backgroundRevalidate(Uri uri, Map<String, String>? headers) {
    Future.microtask(() async {
      try {
        final response = await http.get(uri, headers: headers);
        if (response.statusCode == 200) {
          final url = uri.toString();
          if (_memoryCache[url] != response.body) {
            await _saveToCache(url, response.body);
            debugPrint('🔄 [HttpCacheService] Cache updated silently in background for $url');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [HttpCacheService] Silent cache revalidation failed for ${uri.toString()}: $e');
      }
    });
  }

  /// Save response body to memory and SharedPreferences persistence
  static Future<void> _saveToCache(String url, String body) async {
    _memoryCache[url] = body;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('http_cache_$url', body);
    } catch (e) {
      debugPrint('❌ [HttpCacheService] Persistence write failed: $e');
    }
  }

  /// Clear cache (e.g. on manual logout or clean state)
  static Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('http_cache_')) {
          await prefs.remove(key);
        }
      }
      debugPrint('🧹 [HttpCacheService] Cache successfully cleared.');
    } catch (e) {
      debugPrint('❌ [HttpCacheService] Failed to clear persistent cache: $e');
    }
  }
}
