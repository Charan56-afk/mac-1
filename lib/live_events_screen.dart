import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui'; // For ImageFilter
import 'dart:math' as math;
import 'widgets/glass_event_card.dart';

/// A screen that displays upcoming live movies, concerts, and events.
///
/// Features a deep space themed background with a starfield animation effect.
/// Users can view featured and upcoming events and book tickets via an external link.
class LiveEventsScreen extends StatelessWidget {
  final List events;

  const LiveEventsScreen({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    // Featured Event Mock Data (Ideally this comes from the list or API)
    final featuredEvent = events.isNotEmpty ? events[0] : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).iconTheme.color ?? Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          "LIVE EVENTS",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color:
                Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
            fontSize: 20,
            shadows: Theme.of(context).brightness == Brightness.dark
                ? [const Shadow(color: Color(0xFF00F0FF), blurRadius: 10)]
                : null,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 15),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00F0FF), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF00F0FF),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  "HYD",
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // Deep Space Background
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    const Color(0xFF0A0A15), // Deep Space
                    const Color(0xFF050510), // Almost Black
                    const Color(0xFF0F0F1E), // Dark Purple
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF0F4F8),
                    const Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Starfield Pattern
            Positioned.fill(child: CustomPaint(painter: StarfieldPainter())),

            // Ambient Corner Glows (Softer)
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00F0FF).withValues(alpha: 0.15),
                      const Color(0xFF00F0FF).withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF0055).withValues(alpha: 0.12),
                      const Color(0xFFFF0055).withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 80, color: Colors.white10),
                        const SizedBox(height: 20),
                        Text(
                          "No live events scheduled.",
                          style: GoogleFonts.outfit(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                    children: [
                      // Featured Section
                      if (featuredEvent != null) ...[
                        Text(
                          "FEATURED",
                          style: GoogleFonts.spaceMono(
                            color: const Color(0xFF00F0FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Featured uses the same card but could be larger if needed
                        GlassEventCard(
                          title: featuredEvent['title'] ?? 'Unknown',
                          subtitle: featuredEvent['event'] ?? 'Special',
                          dateLocation: featuredEvent['dateLocation'] ?? 'TBA',
                          imageUrl: featuredEvent['imageUrl'] ?? '',
                          accentColor: const Color(
                            0xFF00F0FF,
                          ), // Cyan for Featured
                        ),
                        const SizedBox(height: 30),
                      ],

                      // Upcoming List
                      Text(
                        "UPCOMING EVENTS",
                        style: GoogleFonts.spaceMono(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Rest of the events (skipping first if featured)
                      ...events.skip(1).map((event) {
                        return GlassEventCard(
                          title: event['title'] ?? 'Unknown',
                          subtitle: event['event'] ?? 'Special',
                          dateLocation: event['dateLocation'] ?? 'TBA',
                          imageUrl: event['imageUrl'] ?? '',
                          accentColor: _parseColor(event['color']),
                        );
                      }),
                    ],
                  ),
          ],
        ),
      ),
      bottomNavigationBar: events.isEmpty
          ? null
          : Container(
              margin: const EdgeInsets.all(20),
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? [
                                const Color(0xFF1A1A2E).withValues(alpha: 0.8),
                                const Color(0xFF0F0F1E).withValues(alpha: 0.9),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.8),
                                Colors.white.withValues(alpha: 0.9),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final Uri url = Uri.parse(
                            'https://www.shreyasgroup.net/event',
                          );
                          try {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (e) {
                            debugPrint('Could not open URL: $e');
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00F0FF,
                                  ).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00F0FF,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.confirmation_number_rounded,
                                  color: Color(0xFF00F0FF),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'BOOK TICKETS',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: const Color(
                                        0xFF00F0FF,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                color: const Color(0xFF00F0FF),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Color _parseColor(String? colorStr) {
    // Enhanced themed colors for different events
    if (colorStr == null) return const Color(0xFFFF0055); // Default Pink

    // Predefined vibrant themes
    final Map<String, Color> themeColors = {
      'cyan': const Color(0xFF00F0FF), // Cyan
      'pink': const Color(0xFFFF0055), // Hot Pink
      'purple': const Color(0xFF9D00FF), // Vivid Purple
      'gold': const Color(0xFFFFD700), // Gold
      'green': const Color(0xFF00FF88), // Neon Green
      'orange': const Color(0xFFFF6B00), // Bright Orange
      'blue': const Color(0xFF0080FF), // Electric Blue
      'magenta': const Color(0xFFFF00FF), // Magenta
    };

    // Check if it's a named theme
    if (themeColors.containsKey(colorStr.toLowerCase())) {
      return themeColors[colorStr.toLowerCase()]!;
    }

    // Try parsing as hex color
    try {
      return Color(int.parse(colorStr));
    } catch (e) {
      return const Color(0xFFFF0055); // Fallback to pink
    }
  }
}

// Starfield Background Painter
/// A custom painter that draws a randomized starfield background.
///
/// Uses a fixed seed to ensure the star pattern remains consistent across repaints.
class StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    // Generate random stars
    final random = math.Random(42); // Fixed seed for consistency
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.5 + 0.2;
      final starSize = random.nextDouble() * 2 + 0.5;

      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

