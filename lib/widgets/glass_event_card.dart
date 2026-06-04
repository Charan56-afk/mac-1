import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GlassEventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String dateLocation;
  final String imageUrl;
  final Color accentColor;

  const GlassEventCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dateLocation,
    required this.imageUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Stack(
        children: [
          // Slanted Rectangle Background
          ClipPath(
            clipper: SlantedRectangleClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [
                          const Color(0xFF1A1A2E).withValues(alpha: 0.9),
                          const Color(0xFF0F0F1E).withValues(alpha: 0.95),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.grey[100]!.withValues(alpha: 0.95),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 25,
                    spreadRadius: -3,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),

          // Neon Border
          Positioned.fill(
            child: ClipPath(
              clipper: SlantedRectangleClipper(),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      Colors.transparent,
                      accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 20, 20),
            child: Row(
              children: [
                // Left: Event Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl.isEmpty
                          ? 'https://picsum.photos/seed/event_default/400/600'
                          : imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: CircularProgressIndicator(
                            color: accentColor,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: Icon(
                          Icons.event,
                          color: accentColor.withValues(alpha: 0.4),
                          size: 35,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Right: Event Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LIVE Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentColor, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor,
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE NOW',
                              style: GoogleFonts.robotoMono(
                                color: accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Event Type
                      Text(
                        subtitle.toUpperCase(),
                        style: GoogleFonts.robotoMono(
                          color: accentColor.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Title
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color:
                              Theme.of(context).textTheme.titleLarge?.color ??
                              Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Date & Location
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 11,
                            color:
                                Theme.of(context).textTheme.bodySmall?.color ??
                                Colors.white54,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              dateLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color ??
                                    Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Book Button
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: GestureDetector(
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withValues(alpha: 0.25),
                            accentColor.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            color: accentColor,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BOOK',
                            style: GoogleFonts.robotoMono(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Glow Effect on Edge
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accentColor.withValues(alpha: 0.8),
                    accentColor,
                    accentColor.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor,
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Slanted Rectangle Clipper
class SlantedRectangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Create a parallelogram (slanted rectangle)
    final slant = 15.0; // Slant amount

    path.moveTo(slant, 0); // Top-left (shifted right)
    path.lineTo(size.width, 0); // Top-right
    path.lineTo(size.width - slant, size.height); // Bottom-right (shifted left)
    path.lineTo(0, size.height); // Bottom-left
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

