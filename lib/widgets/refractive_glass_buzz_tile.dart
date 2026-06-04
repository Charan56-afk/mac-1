import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import '../buzz_details_screen.dart';
import 'package:flutter_application_1/constants.dart';

const _kTileUserId = 'Mobile_User_1';

class RefractiveGlassBuzzTile extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onReturnFromDetail;

  const RefractiveGlassBuzzTile({super.key, required this.post, this.onReturnFromDetail});

  @override
  State<RefractiveGlassBuzzTile> createState() => _RefractiveGlassBuzzTileState();
}

class _RefractiveGlassBuzzTileState extends State<RefractiveGlassBuzzTile> with SingleTickerProviderStateMixin {
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
      duration: const Duration(seconds: 4) )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RefractiveGlassBuzzTile oldWidget) {
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
      if (diff.inMinutes < 1) return 'REFRACT_OK';
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
    const accents = [
      Color(0xFF00F0FF),
      Color(0xFFFF0055),
      Color(0xFF00FF9D),
      Color(0xFFFFD700),
    ];
    final Color accent = accents[text.length % 4];

    return GestureDetector(
      onTap: () => _openDetails(accent),
      child: Container(
        width: 320,
        height: 110,
        margin: const EdgeInsets.only(right: 20),
        child: Stack(
          children: [
            // 1. REFRACTIVE GLASS TABLET
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5 ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.05),
                        blurRadius: 20,
                        spreadRadius: 5 ),
                    ] ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(100, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'REFRACTION_ENGINE',
                              style: GoogleFonts.inter(
                                color: accent,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2 ) ),
                            const Spacer(),
                            Text(
                              timeAgo,
                              style: GoogleFonts.inter(
                                color: Colors.white24,
                                fontSize: 7,
                                fontWeight: FontWeight.bold ) ),
                          ] ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2 ) ) ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _MiniGlowTag(label: 'SECURE', color: accent),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Icon(
                                _hasLiked ? Icons.favorite : Icons.favorite_border,
                                color: _hasLiked ? accent : Colors.white24,
                                size: 16 ) ),
                          ] ),
                      ] ) ) ) ) ),

            // 2. FLOATING IMAGE NODE
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 15 ),
                  ] ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover )
                          : Container(color: Colors.white10),
                      
                      // Prismatic Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.transparent,
                              accent.withValues(alpha: 0.1),
                            ] ) ) ),
                    ] ) ) ) ),

            // 3. GLOW ORB
            Positioned(
              right: 12,
              top: 12,
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.5 + (_glowController.value * 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: accent,
                          blurRadius: 4 * _glowController.value ),
                      ] ) );
                } ) ),
          ] ) ) );
  }
}

class _MiniGlowTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniGlowTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
        borderRadius: BorderRadius.circular(4) ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color.withValues(alpha: 0.7),
          fontSize: 6,
          fontWeight: FontWeight.w900,
          letterSpacing: 1 ) ) );
  }
}
