import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import '../buzz_details_screen.dart';
import 'package:flutter_application_1/constants.dart';

const _kTileUserId = 'Mobile_User_1';

class IndustrialGlassBuzzTile extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onReturnFromDetail;

  const IndustrialGlassBuzzTile({super.key, required this.post, this.onReturnFromDetail});

  @override
  State<IndustrialGlassBuzzTile> createState() => _IndustrialGlassBuzzTileState();
}

class _IndustrialGlassBuzzTileState extends State<IndustrialGlassBuzzTile> with SingleTickerProviderStateMixin {
  late int _likes;
  bool _hasLiked = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _likes = ((widget.post['likes'] ?? 0) as num).toInt();
    final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
    _hasLiked = likedBy.contains(_kTileUserId);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3) )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant IndustrialGlassBuzzTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post || 
        widget.post['likes'] != oldWidget.post['likes'] || 
        widget.post['likedBy'] != oldWidget.post['likedBy']) {
      setState(() {
        _likes = ((widget.post['likes'] ?? 0) as num).toInt();
        final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
        _hasLiked = likedBy.contains(_kTileUserId);
      });
    }
  }

  String _relativeTime(dynamic rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'CONTAINED';
      if (diff.inMinutes < 60) return '${diff.inMinutes}M';
      if (diff.inHours < 24) return '${diff.inHours}H';
      return '${diff.inDays}D';
    } catch (_) {
      return '';
    }
  }

  Future<void> _toggleLike() async {
    final postId = widget.post['_id'];
    final prevLikes = _likes;
    final prevHasLiked = _hasLiked;

    setState(() {
      if (_hasLiked) {
        _likes = (_likes - 1).clamp(0, 999999999);
        _hasLiked = false;
      } else {
        _likes++;
        _hasLiked = true;
      }
      widget.post['likes'] = _likes;
      final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
      if (_hasLiked) {
        if (!likedBy.contains(_kTileUserId)) likedBy.add(_kTileUserId);
      } else {
        likedBy.remove(_kTileUserId);
      }
      widget.post['likedBy'] = likedBy;
    });

    if (postId == null) return;

    try {
      final res = await http.post(
        Uri.parse('${AppConstants.industryBuzz}/$postId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': _kTileUserId}) ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (res.statusCode != 200) {
        _rollbackLike(prevLikes, prevHasLiked);
      }
    } catch (_) {
      _rollbackLike(prevLikes, prevHasLiked);
    }
  }

  void _rollbackLike(int prevLikes, bool prevHasLiked) {
    if (!mounted) return;
    setState(() {
      _likes = prevLikes;
      _hasLiked = prevHasLiked;
      widget.post['likes'] = _likes;
      final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
      if (_hasLiked) {
        if (!likedBy.contains(_kTileUserId)) likedBy.add(_kTileUserId);
      } else {
        likedBy.remove(_kTileUserId);
      }
      widget.post['likedBy'] = likedBy;
    });
  }

  void _openDetails(Color accent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuzzDetailsScreen(
          post: widget.post,
          accentColor: accent ) ) ).then((_) {
      if (mounted) {
        setState(() {
          _likes = ((widget.post['likes'] ?? 0) as num).toInt();
          final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
          _hasLiked = likedBy.contains(_kTileUserId);
        });
      }
      if (widget.onReturnFromDetail != null) {
        widget.onReturnFromDetail!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.post['content'] ?? 'Intel Update';
    final List<dynamic> images = widget.post['images'] as List<dynamic>? ?? [];
    final String? imageUrl = images.isNotEmpty ? images[0] as String : null;
    final String timeAgo = _relativeTime(widget.post['createdAt']);
    
    final Color accent = const [
      Color(0xFF00F0FF),
      Color(0xFFFF0055),
      Color(0xFF00FF9D),
      Color(0xFFFFD700),
    ][text.length % 4];

    return GestureDetector(
      onTap: () => _openDetails(accent),
      child: Container(
        width: 320,
        height: 120,
        margin: const EdgeInsets.only(right: 18),
        child: Stack(
          children: [
            // 1. REAR GLASS CASE
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10 ),
                ] ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.01),
                        ] ) ) ) ) ) ),

            // 2. INDUSTRIAL FRAME & BOLTS
            Positioned.fill(
              child: CustomPaint(
                painter: _IndustrialFramePainter(accent) ) ),

            // 3. INTERNAL CONTENT (CONTAINED)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // INTERNAL IMAGE MODULE
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
                      boxShadow: [
                        BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 10),
                      ] ),
                    child: Stack(
                      children: [
                        if (imageUrl != null)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover, 
                            width: 90,
                            height: 90 )
                        else
                          Container(color: Colors.white10),
                        
                        // "Contained" Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent] ) ) ),
                      ] ) ),
                  const SizedBox(width: 14),
                  // TEXT MODULE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                border: Border.all(color: accent, width: 0.5) ),
                              child: Text(
                                'CASE_ID: ${text.length}',
                                style: GoogleFonts.firaCode(
                                  color: accent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold ) ) ),
                            const Spacer(),
                            Text(
                              timeAgo,
                              style: GoogleFonts.firaCode(
                                color: Colors.white38,
                                fontSize: 8 ) ),
                          ] ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.1 ) ) ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _glowController,
                              builder: (context, child) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent.withValues(alpha: 0.3 + (_glowController.value * 0.7)),
                                    boxShadow: [
                                      BoxShadow(color: accent, blurRadius: 4 * _glowController.value),
                                    ] ) );
                              } ),
                            const SizedBox(width: 6),
                            Text(
                              'MODULE_ACTIVE',
                              style: GoogleFonts.firaCode(color: Colors.white24, fontSize: 8) ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Icon(
                                _hasLiked ? Icons.favorite : Icons.favorite_border,
                                color: _hasLiked ? accent : Colors.white24,
                                size: 16 ) ),
                          ] ),
                      ] ) ),
                ] ) ),
          ] ) ) );
  }
}

class _IndustrialFramePainter extends CustomPainter {
  final Color accent;
  _IndustrialFramePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerLen = 15.0;
    const padding = 2.0;

    // Corner brackets (L-shapes)
    canvas.drawPath(Path()
      ..moveTo(padding + cornerLen, padding)
      ..lineTo(padding, padding)
      ..lineTo(padding, padding + cornerLen), paint);

    canvas.drawPath(Path()
      ..moveTo(size.width - padding - cornerLen, padding)
      ..lineTo(size.width - padding, padding)
      ..lineTo(size.width - padding, padding + cornerLen), paint);

    canvas.drawPath(Path()
      ..moveTo(padding + cornerLen, size.height - padding)
      ..lineTo(padding, size.height - padding)
      ..lineTo(padding, size.height - padding - cornerLen), paint);

    canvas.drawPath(Path()
      ..moveTo(size.width - padding - cornerLen, size.height - padding)
      ..lineTo(size.width - padding, size.height - padding)
      ..lineTo(size.width - padding, size.height - padding - cornerLen), paint);
    
    // Draw "Bolts" in corners
    final boltPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(6, 6), 2, boltPaint);
    canvas.drawCircle(Offset(size.width - 6, 6), 2, boltPaint);
    canvas.drawCircle(Offset(6, size.height - 6), 2, boltPaint);
    canvas.drawCircle(Offset(size.width - 6, size.height - 6), 2, boltPaint);
  }

  @override
  bool shouldRepaint(_IndustrialFramePainter old) => false;
}

