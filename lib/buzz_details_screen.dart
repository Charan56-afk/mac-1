import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_application_1/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Constant "user" identifier used for like/dislike/comment tracking.
//  In a real app this would come from an auth provider.
// ─────────────────────────────────────────────────────────────────────────────
const _kUserId = 'Mobile_User_1';

class BuzzDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final Color accentColor;

  const BuzzDetailsScreen({
    super.key,
    required this.post,
    required this.accentColor,
  });

  @override
  State<BuzzDetailsScreen> createState() => _BuzzDetailsScreenState();
}

class _BuzzDetailsScreenState extends State<BuzzDetailsScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isSubmitting = false;

  int _likes = 0;
  int _dislikes = 0;
  bool _hasLiked = false;
  bool _hasDisliked = false;

  // ── Init / Dispose ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Seed UI immediately from cached post data
    _comments = List.from(widget.post['comments'] ?? []);
    _likes = ((widget.post['likes'] ?? 0) as num).toInt();
    _dislikes = ((widget.post['dislikes'] ?? 0) as num).toInt();

    final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
    final dislikedBy =
        (widget.post['dislikedBy'] as List?)?.cast<String>() ?? [];
    _hasLiked = likedBy.contains(_kUserId);
    _hasDisliked = dislikedBy.contains(_kUserId);

    // Always fetch fresh data from server — keeps likes/comments accurate
    // every time the screen is (re-)opened without blocking the UI
    final postId = widget.post['_id']?.toString();
    if (postId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshPost(postId);
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _relativeTime(dynamic rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ── Re-fetch from Server ───────────────────────────────────────────────────
  Future<void> _refreshPost(String postId) async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.industryBuzz}/$postId'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final lb = (data['likedBy'] as List?)?.cast<String>() ?? [];
        final db = (data['dislikedBy'] as List?)?.cast<String>() ?? [];
        setState(() {
          _comments = List.from(data['comments'] ?? []);
          _likes = ((data['likes'] ?? _likes) as num).toInt();
          _dislikes = ((data['dislikes'] ?? _dislikes) as num).toInt();
          _hasLiked = lb.contains(_kUserId);
          _hasDisliked = db.contains(_kUserId);

          // Sync shared map
          widget.post['comments'] = _comments;
          widget.post['likes'] = _likes;
          widget.post['dislikes'] = _dislikes;
          widget.post['likedBy'] = lb;
          widget.post['dislikedBy'] = db;
        });
      }
    } catch (_) {
      /* keep optimistic state */
    }
  }

  // ── Toggle Like ────────────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    final postId = widget.post['_id'];

    // ① Save BEFORE optimistic mutation (clean rollback target)
    final prevLikes = _likes;
    final prevHasLiked = _hasLiked;
    final prevDislikes = _dislikes;
    final prevHasDisliked = _hasDisliked;

    // ② Optimistic update
    setState(() {
      if (_hasLiked) {
        _likes = (_likes - 1).clamp(0, 999999999);
        _hasLiked = false;
      } else {
        if (_hasDisliked) {
          _dislikes = (_dislikes - 1).clamp(0, 999999999);
          _hasDisliked = false;
        }
        _likes++;
        _hasLiked = true;
      }
      widget.post['likes'] = _likes;
      widget.post['dislikes'] = _dislikes;
      
      final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
      if (_hasLiked) {
        if (!likedBy.contains(_kUserId)) likedBy.add(_kUserId);
      } else {
        likedBy.remove(_kUserId);
      }
      widget.post['likedBy'] = likedBy;

      final dislikedBy = (widget.post['dislikedBy'] as List?)?.cast<String>() ?? [];
      if (_hasDisliked) {
        if (!dislikedBy.contains(_kUserId)) dislikedBy.add(_kUserId);
      } else {
        dislikedBy.remove(_kUserId);
      }
      widget.post['dislikedBy'] = dislikedBy;
    });

    if (postId == null) return;

    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.industryBuzz}/$postId/like'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _kUserId}) )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data.containsKey('likedBy')) {
          // ③a New server: sync authoritative state
          final lb = (data['likedBy'] as List).cast<String>();
          final db = (data['dislikedBy'] as List? ?? []).cast<String>();
          setState(() {
            _likes = ((data['likes'] ?? _likes) as num).toInt();
            _dislikes = ((data['dislikes'] ?? _dislikes) as num).toInt();
            _hasLiked = lb.contains(_kUserId);
            _hasDisliked = db.contains(_kUserId);

            // Sync shared map
            widget.post['likes'] = _likes;
            widget.post['dislikes'] = _dislikes;
            widget.post['likedBy'] = lb;
            widget.post['dislikedBy'] = db;
          });
        } else {
          // ③b Old server: update count only, keep optimistic button state
          setState(() {
            _likes = ((data['likes'] ?? _likes) as num).toInt();
            widget.post['likes'] = _likes;
          });
        }
      } else {
        // ③c Server error – rollback to saved state
        _rollbackReactionState(prevLikes, prevHasLiked, prevDislikes, prevHasDisliked);
      }
    } catch (_) {
      // ③d Network error – rollback to saved state
      _rollbackReactionState(prevLikes, prevHasLiked, prevDislikes, prevHasDisliked);
    }
  }

  void _rollbackReactionState(int l, bool hl, int d, bool hd) {
    if (!mounted) return;
    setState(() {
      _likes = l;
      _hasLiked = hl;
      _dislikes = d;
      _hasDisliked = hd;
      
      widget.post['likes'] = _likes;
      widget.post['dislikes'] = _dislikes;
      
      final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
      if (_hasLiked) {
        if (!likedBy.contains(_kUserId)) likedBy.add(_kUserId);
      } else {
        likedBy.remove(_kUserId);
      }
      widget.post['likedBy'] = likedBy;

      final dislikedBy = (widget.post['dislikedBy'] as List?)?.cast<String>() ?? [];
      if (_hasDisliked) {
        if (!dislikedBy.contains(_kUserId)) dislikedBy.add(_kUserId);
      } else {
        dislikedBy.remove(_kUserId);
      }
      widget.post['dislikedBy'] = dislikedBy;
    });
  }

  // ── Toggle Dislike ─────────────────────────────────────────────────────────
  Future<void> _toggleDislike() async {
    final postId = widget.post['_id'];

    final prevLikes = _likes;
    final prevHasLiked = _hasLiked;
    final prevDislikes = _dislikes;
    final prevHasDisliked = _hasDisliked;

    setState(() {
      if (_hasDisliked) {
        _dislikes = (_dislikes - 1).clamp(0, 999999999);
        _hasDisliked = false;
      } else {
        if (_hasLiked) {
          _likes = (_likes - 1).clamp(0, 999999999);
          _hasLiked = false;
        }
        _dislikes++;
        _hasDisliked = true;
      }
      widget.post['likes'] = _likes;
      widget.post['dislikes'] = _dislikes;
      
      final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
      if (_hasLiked) {
        if (!likedBy.contains(_kUserId)) likedBy.add(_kUserId);
      } else {
        likedBy.remove(_kUserId);
      }
      widget.post['likedBy'] = likedBy;

      final dislikedBy = (widget.post['dislikedBy'] as List?)?.cast<String>() ?? [];
      if (_hasDisliked) {
        if (!dislikedBy.contains(_kUserId)) dislikedBy.add(_kUserId);
      } else {
        dislikedBy.remove(_kUserId);
      }
      widget.post['dislikedBy'] = dislikedBy;
    });

    if (postId == null) return;

    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.industryBuzz}/$postId/dislike'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _kUserId}) )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data.containsKey('dislikedBy')) {
          final lb = (data['likedBy'] as List? ?? []).cast<String>();
          final db = (data['dislikedBy'] as List).cast<String>();
          setState(() {
            _likes = ((data['likes'] ?? _likes) as num).toInt();
            _dislikes = ((data['dislikes'] ?? _dislikes) as num).toInt();
            _hasLiked = lb.contains(_kUserId);
            _hasDisliked = db.contains(_kUserId);

            // Sync shared map
            widget.post['likes'] = _likes;
            widget.post['dislikes'] = _dislikes;
            widget.post['likedBy'] = lb;
            widget.post['dislikedBy'] = db;
          });
        } else {
          setState(() {
            _dislikes = ((data['dislikes'] ?? _dislikes) as num).toInt();
            widget.post['dislikes'] = _dislikes;
          });
        }
      } else {
        _rollbackReactionState(prevLikes, prevHasLiked, prevDislikes, prevHasDisliked);
      }
    } catch (_) {
      _rollbackReactionState(prevLikes, prevHasLiked, prevDislikes, prevHasDisliked);
    }
  }

  // ── Add Comment ────────────────────────────────────────────────────────────
  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;
    final postId = widget.post['_id'];

    final optimistic = {
      'user': _kUserId,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isSubmitting = true;
      _comments.add(optimistic);
      widget.post['comments'] = _comments; // Update shared map
      _commentController.clear();
    });

    if (postId != null) {
      try {
        final res = await http
            .post(
              Uri.parse('${AppConstants.industryBuzz}/$postId/comment'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'user': _kUserId, 'text': text}) )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          await _refreshPost(postId);
        } else {
          _rollbackComment(optimistic, text);
        }
      } catch (_) {
        _rollbackComment(optimistic, text);
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _rollbackComment(Map<String, dynamic> comment, String text) {
    if (!mounted) return;
    setState(() {
      _comments.remove(comment);
      widget.post['comments'] = _comments;
      _commentController.text = text;
    });
    _showSnack('Failed to post comment. Please try again.', isError: true);
  }

  // ── Delete Comment ─────────────────────────────────────────────────────────
  Future<void> _deleteComment(dynamic comment) async {
    final commentId = comment['_id']?.toString();
    final postId = widget.post['_id'];
    if (commentId == null || postId == null) return;

    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete Comment?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold ) ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.outfit(color: Colors.white60) ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white38) ) ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFF0055),
                fontWeight: FontWeight.bold ) ) ),
        ] ) );

    if (confirmed != true || !mounted) return;

    // Optimistic remove
    setState(() {
      _comments.remove(comment);
      widget.post['comments'] = _comments; // Update shared map
    });

    try {
      final res = await http
          .delete(
            Uri.parse(
              '${AppConstants.industryBuzz}/$postId/comment/$commentId' ) )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200 && mounted) {
        // Restore comment
        setState(() {
          _comments.add(comment);
          widget.post['comments'] = _comments;
        });
        _showSnack('Could not delete comment.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _comments.add(comment);
          widget.post['comments'] = _comments;
        });
        _showSnack('Could not delete comment.', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFFFF0055) : widget.accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) ) );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final String content = widget.post['content'] ?? 'Trending Update';
    final String author = widget.post['author'] ?? 'CineSocial';
    final List<dynamic> images = widget.post['images'] as List<dynamic>? ?? [];
    final String postedAt = _relativeTime(widget.post['createdAt']);
    final Color accent = widget.accentColor;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white ),
          onPressed: () => Navigator.pop(context) ),
        title: Text(
          'BUZZ DETAILS',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1 ) ),
        centerTitle: true ),

      body: Column(
        children: [
          // ── Scrollable content ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Post Card ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1014),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.3),
                        width: 1 ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 5) ),
                      ] ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: accent.withValues(alpha: 0.2),
                              child: Text(
                                author.isNotEmpty
                                    ? author[0].toUpperCase()
                                    : 'C',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16 ) ) ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    author,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14 ) ),
                                  if (postedAt.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          color: Colors.white38,
                                          size: 12 ),
                                        const SizedBox(width: 4),
                                        Text(
                                          postedAt,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white38,
                                            fontSize: 11 ) ),
                                      ] ),
                                ] ) ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4 ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6) ),
                              child: Text(
                                'TRENDING',
                                style: GoogleFonts.outfit(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5 ) ) ),
                          ] ),

                        const SizedBox(height: 16),

                        // Content text
                        Text(
                          content,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            height: 1.5 ) ),

                        // Images – constrained 3:4 size
                        if (images.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ...images.map((img) {
                            final url = img.toString();
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    width: 180, // Constrained width
                                    height: 240, // 3:4 aspect ratio limit
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover, 
                                      placeholder: (_, _) => AspectRatio(
                                        aspectRatio: 3 / 4,
                                        child: Container(
                                          color: Colors.white10,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white30,
                                              strokeWidth: 2 ) ) ) ),
                                      errorWidget: (_, _, _) => AspectRatio(
                                        aspectRatio: 3 / 4,
                                        child: Container(
                                          color: Colors.white10,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white30 ) ) ) ) ) ) ) );
                          }),
                        ],

                        const SizedBox(height: 16),

                        // ── Like / Dislike / Comment row ─────────────
                        Row(
                          children: [
                            // ❤️ Like
                            _ReactionButton(
                              active: _hasLiked,
                              activeColor: const Color(0xFFFF0055),
                              icon: _hasLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              label: _formatCount(_likes),
                              onTap: _toggleLike ),

                            const SizedBox(width: 10),

                            // 👎 Dislike
                            _ReactionButton(
                              active: _hasDisliked,
                              activeColor: const Color(0xFF00F0FF),
                              icon: _hasDisliked
                                  ? Icons.thumb_down_rounded
                                  : Icons.thumb_down_off_alt_rounded,
                              label: _formatCount(_dislikes),
                              onTap: _toggleDislike ),

                            const SizedBox(width: 10),

                            // 💬 Comment count (decorative)
                            _ReactionButton(
                              active: false,
                              activeColor: accent,
                              icon: Icons.chat_bubble_outline_rounded,
                              label: '${_comments.length}',
                              onTap: null ),
                          ] ),
                      ] ) ),

                  const SizedBox(height: 28),

                  // ── Comments Header ──────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'COMMENTS (${_comments.length})',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5 ) ),
                      const Spacer(),
                      const Icon(Icons.sort, color: Colors.white38, size: 20),
                    ] ),

                  const SizedBox(height: 14),

                  // ── Comment list ─────────────────────────────────────
                  if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color: Colors.white24 ),
                            const SizedBox(height: 10),
                            Text(
                              'No comments yet.\nBe the first to share your thoughts!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white38,
                                fontSize: 14 ) ),
                          ] ) ) )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final commentUser =
                            (comment['user'] ?? 'Anonymous') as String;
                        final commentText = (comment['text'] ?? '') as String;
                        final commentTime = _relativeTime(comment['createdAt']);
                        final isOwn = commentUser == _kUserId;

                        return GestureDetector(
                          onLongPress: isOwn
                              ? () => _deleteComment(comment)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isOwn
                                  ? accent.withValues(alpha: 0.07)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isOwn
                                    ? accent.withValues(alpha: 0.25)
                                    : Colors.white10 ) ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: accent.withValues(alpha: 0.2),
                                  child: Text(
                                    commentUser.isNotEmpty
                                        ? commentUser[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13 ) ) ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            commentUser,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold ) ),
                                          if (commentTime.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '· $commentTime',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white38,
                                                fontSize: 11 ) ),
                                          ],
                                          const Spacer(),
                                          // Delete hint for own comments
                                          if (isOwn)
                                            GestureDetector(
                                              onTap: () =>
                                                  _deleteComment(comment),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: Colors.white24 ) ),
                                        ] ),
                                      const SizedBox(height: 5),
                                      Text(
                                        commentText,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 14,
                                          height: 1.4 ) ),
                                    ] ) ),
                              ] ) ) );
                      } ),

                  const SizedBox(height: 80),
                ] ) ) ),

          // ── Pinned comment input ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1014),
              border: Border(top: BorderSide(color: Colors.white10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  offset: Offset(0, -5),
                  blurRadius: 10 ),
              ] ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addComment(),
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10 ) ) ) ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isSubmitting ? null : _addComment,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSubmitting
                          ? widget.accentColor.withValues(alpha: 0.4)
                          : widget.accentColor,
                      shape: BoxShape.circle ),
                    child: _isSubmitting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black ) )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.black,
                            size: 20 ) ) ),
              ] ) ),
        ] ) );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable animated reaction pill (like / dislike / comment count)
// ─────────────────────────────────────────────────────────────────────────────
class _ReactionButton extends StatelessWidget {
  final bool active;
  final Color activeColor;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ReactionButton({
    required this.active,
    required this.activeColor,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeColor.withValues(alpha: 0.6) : Colors.white12 ) ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(active),
                color: active ? activeColor : Colors.white54,
                size: 16 ) ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: active ? activeColor : Colors.white54,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal ) ),
          ] ) ) );
  }
}

