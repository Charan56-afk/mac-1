import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ErrorType { network, server, timeout, notFound, empty, unknown }

class AppErrorWidget extends StatelessWidget {
  final ErrorType errorType;
  final String title;
  final String message;
  final VoidCallback onRetry;

  const AppErrorWidget({
    super.key,
    required this.errorType,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  // Helper to get configuration based on error type
  Map<String, dynamic> _getErrorConfig() {
    switch (errorType) {
      case ErrorType.network:
        return {
          'icon': Icons.wifi_off_rounded,
          'color': const Color(0xFF00E5FF),
        }; // Cyan
      case ErrorType.server:
        return {
          'icon': Icons.movie_creation_outlined,
          'color': const Color(0xFFFF6B35),
        }; // Orange
      case ErrorType.empty:
        return {
          'icon': Icons.local_movies_outlined,
          'color': const Color(0xFFFFD700),
        }; // Gold
      case ErrorType.timeout:
        return {
          'icon': Icons.hourglass_empty_rounded,
          'color': const Color(0xFFFFAA00),
        }; // Amber
      case ErrorType.notFound:
        return {
          'icon': Icons.theater_comedy_rounded,
          'color': const Color(0xFFFF2D78),
        }; // Pink
      case ErrorType.unknown:
        return {
          'icon': Icons.error_outline_rounded,
          'color': const Color(0xFFFF3333),
        }; // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getErrorConfig();
    final Color mainColor = config['color'];
    final IconData iconData = config['icon'];

    return Container(
      color: const Color(0xFF0A0A0F), // Dark background matching request
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated Icon Container
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF12121A), // Card background
                shape: BoxShape.circle,
                border: Border.all(color: mainColor.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(iconData, size: 64, color: mainColor),
            ),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Message
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: const Color(0xFF888899), // Dim text color
              height: 1.5,
            ),
          ),

          const SizedBox(height: 48),

          // Retry Button
          if (errorType != ErrorType.empty)
            Container(
              height: 54,
              width: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                gradient: LinearGradient(
                  colors: [mainColor, mainColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(27),
                  onTap: onRetry,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Try Again",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

