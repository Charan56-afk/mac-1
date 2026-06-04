import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'error_screen.dart';

enum ScreenState { loading, success, error, empty }

/// A mixin that provides standardized screen state management, caching,
/// and error handling for CineSocial screens.
mixin ScreenStateMixin<T extends StatefulWidget> on State<T> {
  ScreenState screenState = ScreenState.loading;
  ErrorType currentErrorType = ErrorType.unknown;
  String errorMessage = '';
  String errorTitle = 'Oops! Something went wrong';

  // Server-down banner state — shown when cached data exists but server fails
  bool _showServerBanner = false;
  String _serverBannerMessage = '';
  Timer? _serverBannerTimer;

  /// Wraps an API call with standard state management, caching, and error handling.
  ///
  /// Cache-first: if cached data exists the UI shows it immediately (no spinner).
  /// A background network fetch then silently updates the UI with fresh data.
  Future<void> handleApiState({
    required String cacheKey,
    required Future<dynamic> Function() fetchData,
    required void Function(dynamic decodedData) onDataParsed,
    bool showLoadingIndicator = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    bool hasCachedData = false;

    // 1. Load from cache FIRST — show instantly, no spinner
    try {
      final String? cachedString = prefs.getString(cacheKey);
      if (cachedString != null) {
        final decodedData = json.decode(cachedString);
        if (!(decodedData is List && decodedData.isEmpty)) {
          onDataParsed(decodedData);
          hasCachedData = true;
          if (mounted) {
            setState(() {
              screenState = ScreenState.success;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Cache read error for $cacheKey: $e");
    }

    // 2. Show loading spinner only if no cache exists
    if (!hasCachedData && showLoadingIndicator && mounted) {
      setState(() {
        screenState = ScreenState.loading;
      });
    }

    // 3. Fetch fresh data in background (silently if already showing cache)
    dynamic result;
    try {
      result = await fetchData().timeout(const Duration(seconds: 6));
    } on TimeoutException {
      if (hasCachedData) {
        _showBanner('Server is slow — showing cached content');
      } else {
        _setErrorState(
          ErrorType.timeout,
          "Connection Timed Out",
          "The server took too long to respond.",
        );
      }
      return;
    } catch (e) {
      debugPrint("Network fetch failed: $e");
      if (hasCachedData) {
        _showBanner('Couldn\'t reach server — showing cached content');
      } else {
        _setErrorState(
          ErrorType.network,
          "No Connection",
          "Check your internet and try again.",
        );
      }
      return;
    }

    try {
      dynamic decodedData;
      String? bodyToCache;

      if (result is http.Response) {
        if (result.statusCode >= 200 && result.statusCode < 300) {
          decodedData = json.decode(result.body);
          bodyToCache = result.body;
          // Server responded successfully — hide any banner
          _hideBanner();
        } else {
          if (hasCachedData) {
            _showBanner(_serverMessageForStatus(result.statusCode));
          } else {
            _handleHttpError(result.statusCode, result.body);
          }
          return;
        }
      } else {
        decodedData = result;
        bodyToCache = json.encode(result);
        _hideBanner();
      }

      if (decodedData != null) {
        await prefs.setString(cacheKey, bodyToCache);
        onDataParsed(decodedData);

        if (mounted) {
          setState(() {
            if (decodedData is List && decodedData.isEmpty && !hasCachedData) {
              screenState = ScreenState.empty;
              currentErrorType = ErrorType.empty;
              errorTitle = "Nothing to see here";
              errorMessage = "Looks like this list is completely empty right now.";
            } else {
              screenState = ScreenState.success;
            }
          });
        }
      }
    } catch (e, stack) {
      debugPrint("Data processing error: $e");
      debugPrint(stack.toString());
      if (!hasCachedData) {
        _setErrorState(
          ErrorType.unknown,
          "Data Error",
          "Something went wrong while processing the data.",
        );
      }
    }
  }

  String _serverMessageForStatus(int code) {
    if (code >= 500) return '🔴 Server is down — showing cached content';
    if (code == 404) return 'Content not found — showing cached content';
    return 'Server error ($code) — showing cached content';
  }

  void _handleHttpError(int statusCode, String body) {
    if (statusCode == 404) {
      _setErrorState(ErrorType.notFound, "Not Found",
          "We couldn't find what you were looking for.");
    } else if (statusCode >= 500) {
      _setErrorState(ErrorType.server, "Server Down",
          "Our cinematic servers are taking a break. Please try again soon.");
    } else {
      _setErrorState(ErrorType.unknown, "Error $statusCode",
          "Failed to load content. Please try again.");
    }
  }

  void _setErrorState(ErrorType type, String title, String message) {
    if (mounted && screenState != ScreenState.success) {
      setState(() {
        screenState = ScreenState.error;
        currentErrorType = type;
        errorTitle = title;
        errorMessage = message;
      });
    }
  }

  // ── Server-Down Banner ───────────────────────────────────────────────────────

  void _showBanner(String message) {
    _serverBannerTimer?.cancel();
    if (mounted) {
      setState(() {
        _showServerBanner = true;
        _serverBannerMessage = message;
      });
    }
    // Auto-dismiss after 6 seconds
    _serverBannerTimer = Timer(const Duration(seconds: 6), _hideBanner);
  }

  void _hideBanner() {
    _serverBannerTimer?.cancel();
    if (mounted && _showServerBanner) {
      setState(() => _showServerBanner = false);
    }
  }

  // ── Build Helper ─────────────────────────────────────────────────────────────

  /// Build the screen body, injecting the server-down banner when needed.
  Widget buildScreenState({
    required Widget Function() buildSuccess,
    required VoidCallback onRetry,
    Widget? buildLoading,
  }) {
    Widget body;
    switch (screenState) {
      case ScreenState.success:
        body = buildSuccess();
        break;
      case ScreenState.loading:
        body = buildLoading ??
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            );
        break;
      case ScreenState.empty:
      case ScreenState.error:
        body = AppErrorWidget(
          errorType: currentErrorType,
          title: errorTitle,
          message: errorMessage,
          onRetry: onRetry,
        );
        break;
    }

    return Stack(
      children: [
        body,
        // Server-down banner slides in from top
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          top: _showServerBanner ? 0 : -200,
          left: 0,
          right: 0,
          child: _ServerDownBanner(
            message: _serverBannerMessage,
            onDismiss: _hideBanner,
          ),
        ),
      ],
    );
  }
}

// ── Server Down Banner Widget ────────────────────────────────────────────────

class _ServerDownBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ServerDownBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 12,
          left: 16,
          right: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A0A),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFFF3333), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3333).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3333),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

