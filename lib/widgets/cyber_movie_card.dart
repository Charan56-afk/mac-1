import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CyberMovieCard extends StatelessWidget {
  final Map item;
  final Color statusColor;
  final double scaleValue;

  const CyberMovieCard({
    super.key,
    required this.item,
    required this.statusColor,
    required this.scaleValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Holographic Base (Trapezoid)
          Positioned(
            bottom: 0,
            left: 20,
            right: 20,
            height: 60,
            child: CustomPaint(painter: _HoloBasePainter(color: statusColor)) ),

          // 2. Poster Image (Floating)
          Positioned(
            top: 0,
            bottom: 25, // Leave room for base
            left: 0,
            right: 0,
            child: Transform.scale(
              scale: scaleValue,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3 * scaleValue),
                      blurRadius: 20,
                      spreadRadius: 2 ),
                  ],
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.5),
                    width: 1.5 ) ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item['imageUrl'],
                        fit: BoxFit.cover ),
                      // Cyber Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.6, 1.0] ) ) ),
                      // Tech Lines
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Icon(Icons.nfc, color: Colors.white38, size: 20) ),
                      // Title & Status
                      Positioned(
                        bottom: 15,
                        left: 15,
                        right: 15,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'],
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2 ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(4) ),
                              child: Text(
                                item['status'].toString().toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10 ) ) ),
                          ] ) ),
                    ] ) ) ) ) ),
        ] ) );
  }
}

class _HoloBasePainter extends CustomPainter {
  final Color color;
  _HoloBasePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    // Trapezoid shape
    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width * 0.85, 0);
    path.lineTo(size.width * 0.15, 0);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Scanlines on base
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

