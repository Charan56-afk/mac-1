import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import '../buzz_details_screen.dart';
import 'package:flutter_application_1/constants.dart';

const _kTileUserId = 'Mobile_User_1';

class HolographicGlassCaseTile extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onReturnFromDetail;

  const HolographicGlassCaseTile({super.key, required this.post, this.onReturnFromDetail});

  @override
  State<HolographicGlassCaseTile> createState() => _HolographicGlassCaseTileState();
}

class _HolographicGlassCaseTileState extends State<HolographicGlassCaseTile> with SingleTickerProviderStateMixin {
  late int _likes;
  bool _hasLiked = false;
  late AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _likes = ((widget.post['likes'] ?? 0) as num).toInt();
    final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
    _hasLiked = likedBy.contains(_kTileUserId);
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3) )..repeat();
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HolographicGlassCaseTile oldWidget) {
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
      if (diff.inMinutes < 1) return 'LOCKED';
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
        height: 130,
        margin: const EdgeInsets.only(right: 18),
        child: Stack(
          children: [
            // 1. THE GLASS BLOCK (CONTAINER)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5 ) ) ) ) ),

            // 2. GLASS HIGHLIGHTS (Top & Side Light)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: _GlassCasePainter(accent) ) ) ),

            // 3. INTERNAL MODULES
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // FLOATING IMAGE CASE
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.1),
                          blurRadius: 15,
                          spreadRadius: 2 ),
                      ] ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl != null)
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover )
                          else
                            Container(color: Colors.white10),
                          
                          // Glass Overlay on Image
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.transparent,
                                ] ) ) ),
                        ] ) ) ),
                  const SizedBox(width: 16),
                  // DATA MODULE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'CASE_REF: ${text.length.toRadixString(16).toUpperCase()}',
                              style: GoogleFonts.firaCode(
                                color: accent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5 ) ),
                            const Spacer(),
                            Text(
                              timeAgo,
                              style: GoogleFonts.firaCode(
                                color: Colors.white24,
                                fontSize: 8 ) ),
                          ] ),
                        const SizedBox(height: 8),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.1 ) ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _InfoPill(label: 'SECURE', color: accent),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Row(
                                children: [
                                  Icon(
                                    _hasLiked ? Icons.favorite : Icons.favorite_border,
                                    color: _hasLiked ? accent : Colors.white24,
                                    size: 16 ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_likes',
                                    style: GoogleFonts.firaCode(
                                      color: Colors.white24,
                                      fontSize: 10 ) ),
                                ] ) ),
                          ] ),
                      ] ) ),
                ] ) ),

            // 4. MOVING SHEEN (Glass Reflection)
            AnimatedBuilder(
              animation: _sheenController,
              builder: (context, child) {
                return Positioned(
                  left: -150 + (_sheenController.value * 500),
                  top: -50,
                  bottom: -50,
                  child: Transform.rotate(
                    angle: 0.5,
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                          ] ) ) ) ) );
              } ),
          ] ) ) );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        borderRadius: BorderRadius.circular(4) ),
      child: Text(
        label,
        style: GoogleFonts.firaCode(color: color, fontSize: 7, fontWeight: FontWeight.bold) ) );
  }
}

class _GlassCasePainter extends CustomPainter {
  final Color accent;
  _GlassCasePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Top Edge Highlight (White-ish)
    paint.color = Colors.white.withValues(alpha: 0.15);
    canvas.drawLine(const Offset(20, 2), Offset(size.width - 20, 2), paint);

    // Bottom Edge Highlight (Accent-ish)
    paint.color = accent.withValues(alpha: 0.2);
    canvas.drawLine(Offset(20, size.height - 2), Offset(size.width - 20, size.height - 2), paint);

    // Corner Accents
    paint.color = accent.withValues(alpha: 0.5);
    paint.strokeWidth = 2.5;
    
    // Top-Left corner bit
    canvas.drawLine(const Offset(0, 20), const Offset(0, 30), paint);
    // Bottom-Right corner bit
    canvas.drawLine(Offset(size.width, size.height - 20), Offset(size.width, size.height - 30), paint);
  }

  @override
  bool shouldRepaint(_GlassCasePainter old) => false;
}

