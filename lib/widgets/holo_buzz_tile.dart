import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HoloBuzzTile extends StatelessWidget {
  final String text;
  const HoloBuzzTile(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    // Deterministic pseudo-random selections to keep ListView stable
    final int index = text.length;
    final int imageIndex = index % 5;

    // Cyberpunk Color Palette for Borders
    final List<Color> accentColors = [
      const Color(0xFF00F0FF), // Cyan
      const Color(0xFFFF0055), // Pink
      const Color(0xFFbc13fe), // Purple
      const Color(0xFF00ff9d), // Green
    ];
    final Color accentColor = accentColors[index % accentColors.length];

    final List<String> newsImages = [
      "https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=500&q=60",
      "https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=500&q=60",
      "https://images.unsplash.com/photo-1478720568477-152d9b164e63?auto=format&fit=crop&w=500&q=60",
      "https://images.unsplash.com/photo-1598899134739-24c46f58b8c0?auto=format&fit=crop&w=500&q=60",
      "https://images.unsplash.com/photo-1517604931442-71053e6e2360?auto=format&fit=crop&w=500&q=60",
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1014), // Deep background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          // Neon Glow Effect
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4) ),
        ] ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Section (Left)
              SizedBox(
                width: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: newsImages[imageIndex],
                      fit: BoxFit.cover ),
                    // Image Overlay
                    Container(color: accentColor.withValues(alpha: 0.2)),
                  ] ) ),

              // 2. Content Section (Right)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF0F1014),
                        const Color(0xFF1A1A2E),
                      ] ) ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2 ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 0.5 ) ),
                        child: Text(
                          "INDUSTRY INTEL",
                          style: GoogleFonts.outfit(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0 ) ) ),
                      const SizedBox(height: 8),
                      // Main Text
                      Text(
                        text,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3 ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis ),
                    ] ) ) ),

              // 3. Right Edge Accent
              Container(width: 4, color: accentColor.withValues(alpha: 0.8)),
            ] ) ) ) );
  }
}

