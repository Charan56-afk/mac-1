import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/utils.dart';

/// Global singleton that monitors network connectivity.
///
/// Strategy:
///  - Trust [connectivity_plus] for WiFi/ethernet/mobile detection.
///  - Only report offline when connectivity_plus explicitly says "none".
///  - Separately track server reachability via a lightweight TCP ping.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  /// true = has a network interface (WiFi / ethernet / mobile)
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  /// true = CineSocial backend is reachable
  final ValueNotifier<bool> serverReachable = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pingTimer;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Check current connectivity state immediately (don't block startup)
    _updateFromResults(await Connectivity().checkConnectivity());

    // Listen for changes
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen(_updateFromResults);

    // Ping server every 20s (non-blocking, only affects serverReachable)
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (isOnline.value) _pingServer();
    });
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    final hasInterface = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);

    isOnline.value = hasInterface;

    if (!hasInterface) {
      serverReachable.value = false;
    } else {
      // If we just came back online, re-ping the server
      _pingServer();
    }
  }

  /// Pings the CineSocial server to detect server-down state.
  /// Does NOT affect [isOnline] — only [serverReachable].
  Future<void> _pingServer() async {
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host.isEmpty ? 'localhost' : uri.host;
      final port = uri.port > 0 ? uri.port : 5200;
      final socket = await Socket.connect(
        host, port,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      serverReachable.value = true;
    } catch (_) {
      serverReachable.value = false;
    }
  }

  /// Manually recheck (called from "Try Again" button).
  Future<void> recheck() async {
    _updateFromResults(await Connectivity().checkConnectivity());
  }

  void dispose() {
    _subscription?.cancel();
    _pingTimer?.cancel();
    isOnline.dispose();
    serverReachable.dispose();
  }
}

