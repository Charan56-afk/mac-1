import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CyberEventCard extends StatelessWidget {
  final String title, event, date, imageUrl;
  final Color color;

  const CyberEventCard({
    super.key,
    required this.title,
    required this.event,
    required this.date,
    required this.color,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220, // Wider for impact
      margin: const EdgeInsets.only(right: 15),
      child: Stack(
        children: [
          // 1. Ticket Shape Background
          Positioned.fill(
            child: ClipPath(
              clipper: _TicketClipper(),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  border: Border(
                    left: BorderSide(color: color, width: 4), // Color coding
                  ) ),
                child: CustomPaint(
                  painter: _TechPatternPainter(
                    color: Colors.white.withValues(alpha: 0.02) ) ) ) ) ),

          // 2. Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Top
              Expanded(
                flex: 3,
                child: ClipPath(
                  clipper: _TicketTopClipper(),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover, 
                    color: Colors.black.withValues(alpha: 0.2),
                    colorBlendMode: BlendMode.darken ) ) ),
              // Dashed Line Separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: _DashedLinePainter() ) ),
              // Details Bottom
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2 ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4) ),
                        child: Text(
                          event.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold ) ) ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold ) ),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontFamily: GoogleFonts.spaceMono().fontFamily ) ) ),
                        ] ),
                    ] ) ) ),
            ] ),
        ] ) );
  }
}

// --- CLIPPERS & PAINTERS ---

class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double notchRadius = 8.0;
    final double notchY = size.height * 0.6; // Divider position

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    // Right Notch
    path.lineTo(size.width, notchY - notchRadius);
    path.arcToPoint(
      Offset(size.width, notchY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    // Left Notch
    path.lineTo(0, notchY + notchRadius);
    path.arcToPoint(
      Offset(0, notchY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false );
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _TicketTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    // Just a rectangle that respects the top corners,
    // but we can add a subtle diagonal cut if we want.
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final double dashWidth = 5;
    final double dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _TechPatternPainter extends CustomPainter {
  final Color color;
  _TechPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw subtle circuitry like lines
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.8), 20, paint);
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.8),
      Offset(size.width, size.height * 0.6),
      paint );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

