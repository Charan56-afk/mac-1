import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrendingCollabCard extends StatelessWidget {
  final String person1Name;
  final String person1Image;
  final String person2Name;
  final String person2Image;
  final String collabName; // e.g. "The Raja Saab"
  final int hypeScore;

  const TrendingCollabCard({
    super.key,
    required this.person1Name,
    required this.person1Image,
    required this.person2Name,
    required this.person2Image,
    required this.collabName,
    required this.hypeScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1014),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatars Row
          SizedBox(
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Person 1 (Left)
                Positioned(left: 10, child: _buildAvatar(person1Image)),
                // Person 2 (Right)
                Positioned(right: 10, child: _buildAvatar(person2Image)),
                // 'X' Badge
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Color(0xFF00F0FF),
                    child: Text(
                      "X",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Names
          Text(
            "$person1Name x $person2Name",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Collab Name
          Text(
            collabName,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Hype Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0055).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF0055).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFFF0055),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  "$hypeScore% HYPE",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFF0055),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(url),
      ),
    );
  }
}

