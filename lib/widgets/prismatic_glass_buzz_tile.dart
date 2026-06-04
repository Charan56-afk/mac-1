import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../buzz_details_screen.dart';
import 'package:flutter_application_1/constants.dart';

const _kPrismUserId = 'Mobile_User_1';

// ---------------------------------------------------------------------------
// PRISMATIC GLASS BUZZ TILE
// Design: Rotating Rainbow SweepGradient capsule border + deep glass core
// + circular image anchor + pulsing crystal link icon
// ---------------------------------------------------------------------------
class PrismaticGlassBuzzTile extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onReturnFromDetail;

  const PrismaticGlassBuzzTile({
    super.key,
    required this.post,
    this.onReturnFromDetail,
  });

  @override
  State<PrismaticGlassBuzzTile> createState() => _PrismaticGlassBuzzTileState();
}

class _PrismaticGlassBuzzTileState extends State<PrismaticGlassBuzzTile>
    with TickerProviderStateMixin {
  late int _likes;
  bool _hasLiked = false;

  // Drives the rotating SweepGradient border (continuous 0→1 loop)
  late AnimationController _sweepController;

  // Drives the pulsing crystal link icon (reverse loop for breathe effect)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Hover / press scale
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _likes = ((widget.post['likes'] ?? 0) as num).toInt();
    final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
    _hasLiked = likedBy.contains(_kPrismUserId);

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4) )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600) )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut) );
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PrismaticGlassBuzzTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post || 
        widget.post['likes'] != oldWidget.post['likes'] || 
        widget.post['likedBy'] != oldWidget.post['likedBy']) {
      setState(() {
        _likes = ((widget.post['likes'] ?? 0) as num).toInt();
        final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
        _hasLiked = likedBy.contains(_kPrismUserId);
      });
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _relativeTime(dynamic rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'PRISM_OK';
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
         if (!likedBy.contains(_kPrismUserId)) likedBy.add(_kPrismUserId);
      } else {
         likedBy.remove(_kPrismUserId);
      }
      widget.post['likedBy'] = likedBy;
    });

    if (postId == null) return;

    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.industryBuzz}/$postId/like'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _kPrismUserId}) )
          .timeout(const Duration(seconds: 8));

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
         if (!likedBy.contains(_kPrismUserId)) likedBy.add(_kPrismUserId);
      } else {
         likedBy.remove(_kPrismUserId);
      }
      widget.post['likedBy'] = likedBy;
    });
  }

  void _openDetails(Color accent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuzzDetailsScreen(
          post: widget.post,
          accentColor: accent ) ) ).then((_) {
      if (mounted) {
        setState(() {
          _likes = ((widget.post['likes'] ?? 0) as num).toInt();
          final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
          _hasLiked = likedBy.contains(_kPrismUserId);
        });
      }
      widget.onReturnFromDetail?.call();
    });
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String text = widget.post['content'] ?? 'Intel Update';
    final List<dynamic> images =
        widget.post['images'] as List<dynamic>? ?? [];
    final String? imageUrl = images.isNotEmpty ? images[0] as String : null;
    final String timeAgo = _relativeTime(widget.post['createdAt']);

    // Per-tile accent cycling through four vibrant neons
    final Color accent = const [
      Color(0xFF00F0FF), // cyan
      Color(0xFFBF00FF), // violet
      Color(0xFF00FF9D), // mint
      Color(0xFFFFD700), // gold
    ][text.length % 4];

    // The full rainbow prism palette
    const List<Color> prismColors = [
      Color(0xFF00F0FF), // cyan
      Color(0xFF7B2FFF), // violet
      Color(0xFFFF0055), // red
      Color(0xFFFF8C00), // amber
      Color(0xFF00FF9D), // mint
      Color(0xFF00F0FF), // back to cyan (seamless loop)
    ];

    return GestureDetector(
      onTap: () => _openDetails(accent),
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 360,
          height: 178,
          margin: const EdgeInsets.only(right: 18),
          child: AnimatedBuilder(
            animation: _sweepController,
            builder: (context, child) {
              // Outer rotating rainbow gradient shell
              return CustomPaint(
                painter: _PrismaticBorderPainter(
                  progress: _sweepController.value,
                  colors: prismColors,
                  borderWidth: 2.5,
                  radius: 54 ),
                child: child );
            },
            child: _buildInnerCard(
              imageUrl: imageUrl,
              text: text,
              timeAgo: timeAgo,
              accent: accent ) ) ) ) );
  }

  Widget _buildInnerCard({
    required String? imageUrl,
    required String text,
    required String timeAgo,
    required Color accent,
  }) {
    return Padding(
      // Inset by 2.5px to sit just inside the painted border
      padding: const EdgeInsets.all(2.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(52),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              // Deep, near-black glass core
              color: const Color(0xFF080B12).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(52) ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  // ── CIRCULAR IMAGE NODE ──────────────────────────────────
                  _CircularImageNode(
                    imageUrl: imageUrl,
                    accent: accent,
                    sweepController: _sweepController ),

                  const SizedBox(width: 14),

                  // ── METADATA ─────────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // PRISM_NODE label + timestamp
                        Row(
                          children: [
                            Text(
                              'PRISM_NODE',
                              style: GoogleFonts.sourceCodePro(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4 ) ),
                            const Spacer(),
                            if (timeAgo.isNotEmpty)
                              Text(
                                timeAgo,
                                style: GoogleFonts.sourceCodePro(
                                  color: Colors.white30,
                                  fontSize: 10 ) ),
                          ] ),

                        const SizedBox(height: 5),

                        // Main content text
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.25 ) ),

                        const SizedBox(height: 6),

                        // CRYSTAL_LINK row
                        Row(
                          children: [
                            // Pulsing crystal icon
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (_, _) => Icon(
                                Icons.auto_awesome,
                                color: accent.withValues(
                                  alpha: _pulseAnim.value ),
                                size: 13,
                                shadows: [
                                  Shadow(
                                    color: accent.withValues(
                                      alpha: _pulseAnim.value * 0.8 ),
                                    blurRadius: 8 ),
                                ] ) ),
                            const SizedBox(width: 5),
                            Text(
                              'CineSocial',
                              style: GoogleFonts.sourceCodePro(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8 ) ),
                            const Spacer(),
                            // Like button
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _hasLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: _hasLiked ? accent : Colors.white30,
                                    size: 18 ),
                                  if (_likes > 0) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '$_likes',
                                      style: GoogleFonts.sourceCodePro(
                                        color: _hasLiked
                                            ? accent
                                            : Colors.white30,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600 ) ),
                                  ],
                                ] ) ),
                          ] ),
                      ] ) ),

                  const SizedBox(width: 8),
                ] ) ) ) ) ) );
  }
}

// ---------------------------------------------------------------------------
// CIRCULAR IMAGE NODE
// Renders the circular image with a secondary prismatic ring
// ---------------------------------------------------------------------------
class _CircularImageNode extends StatelessWidget {
  final String? imageUrl;
  final Color accent;
  final AnimationController sweepController;

  const _CircularImageNode({
    required this.imageUrl,
    required this.accent,
    required this.sweepController,
  });

  @override
  Widget build(BuildContext context) {
    const double imgWidth = 118;
    const double imgHeight = 138;
    const double squircleRadius = 24.0;

    return AnimatedBuilder(
      animation: sweepController,
      builder: (_, _) {
        return CustomPaint(
          painter: _PrismaticBorderPainter(
            progress: sweepController.value,
            colors: const [
              Color(0xFF00F0FF),
              Color(0xFF7B2FFF),
              Color(0xFFFF0055),
              Color(0xFFFF8C00),
              Color(0xFF00FF9D),
              Color(0xFF00F0FF),
            ],
            borderWidth: 2.0,
            radius: squircleRadius ),
          size: Size(imgWidth, imgHeight),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(squircleRadius),
              child: SizedBox(
                width: imgWidth - 4,
                height: imgHeight - 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image or placeholder
                    imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover, 
                            placeholder: (_, _) => Container(
                              color: const Color(0xFF0A0D17) ),
                            errorWidget: (_, _, _) => Container(
                              color: const Color(0xFF0A0D17),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white24,
                                size: 22 ) ) )
                        : Container(
                            color: const Color(0xFF0A0D17),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white24,
                              size: 22 ) ),

                    // Thin prismatic shimmer overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.transparent,
                            accent.withValues(alpha: 0.08),
                          ] ) ) ),
                  ] ) ) ) ) );
      } );
  }
}

// ---------------------------------------------------------------------------
// PRISMATIC BORDER PAINTER
// Draws a rotating SweepGradient ring around a given radius, simulating
// light refracting through a crystal prism. Works for both the capsule
// outer border AND the circular image ring.
// ---------------------------------------------------------------------------
class _PrismaticBorderPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, drives rotation
  final List<Color> colors;
  final double borderWidth;
  final double radius;

  const _PrismaticBorderPainter({
    required this.progress,
    required this.colors,
    required this.borderWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Build the rotating sweep gradient shader
    final rotationAngle = progress * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = SweepGradient(
        colors: colors,
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(rotationAngle) ).createShader(rect);

    // Determine shape: if radius is large relative to height, it's a stadium
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(radius) );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_PrismaticBorderPainter old) =>
      old.progress != progress ||
      old.borderWidth != borderWidth ||
      old.radius != radius;
}
