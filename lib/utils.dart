import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; // For PointerDeviceKind
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_application_1/app_config.dart';

// --- CACHING UTILITY ---
class CacheUtility {
  static final Map<String, String> _ytUrlCache = {};

  static Future<void> saveToCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }

  static Future<dynamic> getFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString(key);
    if (cachedData != null) {
      return json.decode(cachedData);
    }
    return null;
  }

  static void cacheYtUrl(String originalUrl, String resolvedUrl) {
    _ytUrlCache[originalUrl] = resolvedUrl;
  }

  static String? getCachedYtUrl(String originalUrl) {
    return _ytUrlCache[originalUrl];
  }

  // --- PROFILE DATA ---
  static Future<void> saveProfileData(Map<String, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      await prefs.setString('profile_${entry.key}', entry.value);
    }
  }

  static Future<String?> getProfileValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_$key');
  }

  // --- VERIFICATION STATE ---
  static Future<bool> isUserVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_verified') ?? false;
  }

  static Future<void> setUserVerified(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_verified', status);
  }

  // --- AVATAR RESOLVER ---
  static ImageProvider getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) {
      return const NetworkImage('https://i.pravatar.cc/150?img=12');
    }

    if (url.startsWith('http') || (kIsWeb && url.startsWith('blob:'))) {
      return NetworkImage(url);
    }

    // Support Base64 Data URI
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint('Error decoding base64 avatar: $e');
      }
    }

    // Handle local file path for Mobile/Desktop
    if (!kIsWeb) {
      try {
        final file = File(url);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (e) {
        debugPrint('Error loading local avatar: $e');
      }
    }

    // Fallback if file doesn't exist or we're on web with a non-matching URL
    return const NetworkImage('https://i.pravatar.cc/150?img=12');
  }
}

// --- GLOBAL SERVER URL HELPER ---
String get serverIp {
  return AppConfig.serverHost;
}

String get baseUrl {
  return 'http://$serverIp:5000';
}

// --- TIME UTILITY ---
class TimeUtility {
  static String getTimeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'unknown';

    try {
      final DateTime date = DateTime.parse(dateString);
      final Duration diff = DateTime.now().difference(date);

      if (diff.inSeconds < 60) {
        return 'just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${(diff.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      // Fallback if parsing fails (e.g., if backend sends an old format string)
      return dateString;
    }
  }
}

// --- GLOBAL FRIENDS LIST ---
final List<Map<String, String>> globalFriendsList = [
  {"name": "Mahesh Babu", "avatar": "https://i.pravatar.cc/150?img=1"},
  {"name": "NTR", "avatar": "https://i.pravatar.cc/150?img=2"},
  {"name": "Allu Arjun", "avatar": "https://i.pravatar.cc/150?img=3"},
  {"name": "Ram Charan", "avatar": "https://i.pravatar.cc/150?img=4"},
  {"name": "Prabhas", "avatar": "https://i.pravatar.cc/150?img=5"},
];

// --- CUSTOM SCROLL BEHAVIOR ---
// Ensures mouse drag works on web/desktop (prevents "stuck" carousels)
class AppScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}
