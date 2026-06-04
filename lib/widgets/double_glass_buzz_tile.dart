import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import '../buzz_details_screen.dart';
import 'package:flutter_application_1/constants.dart';

const _kTileUserId = 'Mobile_User_1';

class DoubleGlassBuzzTile extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onReturnFromDetail;

  const DoubleGlassBuzzTile({super.key, required this.post, this.onReturnFromDetail});

  @override
  State<DoubleGlassBuzzTile> createState() => _DoubleGlassBuzzTileState();
}

class _DoubleGlassBuzzTileState extends State<DoubleGlassBuzzTile> {
  late int _likes;
  bool _hasLiked = false;

  @override
  void initState() {
    super.initState();
    _likes = ((widget.post['likes'] ?? 0) as num).toInt();
    final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
    _hasLiked = likedBy.contains(_kTileUserId);
  }

  @override
  void didUpdateWidget(covariant DoubleGlassBuzzTile oldWidget) {
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
      if (diff.inMinutes < 1) return 'DATA_LNK';
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
        margin: const EdgeInsets.only(right: 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. BASE GLASS LAYER
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1 ) ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(110, 15, 20, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'INTEL_NODE',
                              style: GoogleFonts.firaCode(
                                color: accent,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1 ) ),
                            const Spacer(),
                            Text(
                              timeAgo,
                              style: GoogleFonts.firaCode(
                                color: Colors.white24,
                                fontSize: 8 ) ),
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
                              height: 1.1 ) ) ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.waves, color: Colors.white10, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              'CRYPTO_SYC',
                              style: GoogleFonts.firaCode(color: Colors.white10, fontSize: 7) ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Icon(
                                _hasLiked ? Icons.favorite : Icons.favorite_border,
                                color: _hasLiked ? accent : Colors.white24,
                                size: 16 ) ),
                          ] ),
                      ] ) ) ) ) ),

            // 2. FLOATING IMAGE GLASS CARD
            Positioned(
              left: -10,
              top: 10,
              bottom: 10,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(5, 5) ),
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: -5 ),
                  ] ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
                        borderRadius: BorderRadius.circular(18) ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover )
                              : Container(color: Colors.white10) ) ) ) ) ) ) ),

            // 3. NEON CORNER CLAMPS (Decorative)
            Positioned(
              right: 15,
              top: 0,
              child: Container(
                width: 20,
                height: 2,
                color: accent.withValues(alpha: 0.5) ) ),
            Positioned(
              right: 0,
              top: 15,
              child: Container(
                width: 2,
                height: 20,
                color: accent.withValues(alpha: 0.5) ) ),
          ] ) ) );
  }
}

