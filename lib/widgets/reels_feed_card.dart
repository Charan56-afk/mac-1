import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../profile_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import '../utils.dart';
import 'feed_video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/constants.dart';

/// Reels-style vertical feed card.
class ReelsFeedCard extends StatefulWidget {
  final String postId;
  final String userName;
  final String userHandle;
  final String userAvatar;
  final String timeAgo;
  final String? text;
  final List<String> images;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int likes;
  final int comments;
  final int reposts;
  final bool isVerified;
  final List<dynamic> commentsList;
  final List<String> likedBy;
  final List<String> bookmarkedBy;
  final Function(int newLikeCount, bool isLiked)? onLikeChanged;
  final Function(int newRepostCount, bool isReposted)? onRepostChanged;
  final VoidCallback? onDelete;
  final String localHandle;
  final bool initialIsFollowing;

  const ReelsFeedCard({
    super.key,
    required this.postId,
    required this.userName,
    required this.userHandle,
    required this.userAvatar,
    required this.timeAgo,
    this.text,
    this.images = const [],
    this.videoUrl,
    this.thumbnailUrl,
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
    this.isVerified = false,
    this.commentsList = const [],
    this.likedBy = const [],
    this.bookmarkedBy = const [],
    this.onLikeChanged,
    this.onRepostChanged,
    this.onDelete,
    this.localHandle = '@cineuser',
    this.initialIsFollowing = false,
  });

  @override
  State<ReelsFeedCard> createState() => _ReelsFeedCardState();
}

class _ReelsFeedCardState extends State<ReelsFeedCard>
    with TickerProviderStateMixin {
  late int _likeCount;
  late int _commentCount;
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isPostingComment = false;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  late List<dynamic> _localCommentsList;
  String _localHandle = '@cineuser';
  // Heart + disc animations
  late AnimationController _heartController;
  late AnimationController _discController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _localHandle = widget.localHandle;
    _likeCount = widget.likes;
    _commentCount = widget.comments;
    _localCommentsList = List.from(widget.commentsList);
    _isLiked = widget.likedBy.contains(_localHandle);
    _isBookmarked = widget.bookmarkedBy.contains(_localHandle);
    _isFollowing = widget.userHandle != _localHandle ? widget.initialIsFollowing : false;

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300) );
    _heartScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut) );
    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _heartController.reverse();
    });
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4) )..repeat();
  }

  @override
  void dispose() {
    _heartController.dispose();
    _discController.dispose();
    super.dispose();
  }

  Future<void> _onLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    if (_isLiked) _heartController.forward();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.reels}/${widget.postId}/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': _localHandle}) );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _likeCount = data['likes'];
          _isLiked = data['isLiked'] ?? _isLiked;
        });

        if (widget.onLikeChanged != null) {
          widget.onLikeChanged!(_likeCount, _isLiked);
        }
      }
    } catch (e) {
      debugPrint('Like error: $e');
      setState(() {
        _likeCount -= _isLiked ? 1 : -1;
        _isLiked = !_isLiked;
      });
    }
  }

  Future<void> _onFollow() async {
    if (_isLoadingFollow) return;
    setState(() {
      _isLoadingFollow = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/${widget.userHandle}/follow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': _localHandle}) );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _isFollowing = data['isFollowing'] ?? !_isFollowing;
            _isLoadingFollow = false;
          });
        }
      } else {
        throw Exception('Failed to follow');
      }
    } catch (e) {
      debugPrint('Follow error: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  void _onComment() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8 ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20) ) ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2) ) ),
                    const SizedBox(height: 16),
                    Text(
                      'Comments',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold ) ),
                    Divider(color: Theme.of(context).dividerTheme.color),
                    Expanded(
                      child: _localCommentsList.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet.',
                                style: GoogleFonts.inter(color: Colors.grey) ) )
                          : ListView.builder(
                              itemCount: _localCommentsList.length,
                              itemBuilder: (context, index) {
                                final comment = _localCommentsList[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0 ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            CacheUtility.getAvatarProvider(
                                              comment['userAvatar'] ??
                                                  widget.userAvatar ) ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        comment['userName'] ??
                                                        'User',
                                                    style: GoogleFonts.inter(
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14 ) ),
                                                  TextSpan(
                                                    text:
                                                        '  ${comment['text'] ?? ''}',
                                                    style: GoogleFonts.inter(
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color,
                                                      fontSize: 14 ) ),
                                                ] ) ),
                                          ] ) ),
                                    ] ) );
                              } ) ),
                    Divider(color: Theme.of(context).dividerTheme.color),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20) ),
                            child: TextField(
                              controller: controller,
                              maxLines: 4,
                              minLines: 1,
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context ).textTheme.bodyLarge?.color,
                                fontSize: 14 ),
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 14 ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12 ),
                                border: InputBorder.none ) ) ) ),
                        const SizedBox(width: 12),
                        _isPostingComment
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.blue,
                                    strokeWidth: 2 ) ) )
                            : IconButton(
                                onPressed: () async {
                                  if (controller.text.trim().isEmpty) return;
                                  setModalState(() {
                                    _isPostingComment = true;
                                  });
                                  try {
                                    final name =
                                        await CacheUtility.getProfileValue(
                                          'name' );
                                    final handle =
                                        await CacheUtility.getProfileValue(
                                          'handle' );
                                    final avatar =
                                        await CacheUtility.getProfileValue(
                                          'avatar' );

                                    final response = await http.post(
                                      Uri.parse(
                                        '${AppConstants.reels}/${widget.postId}/comments' ),
                                      headers: {
                                        'Content-Type': 'application/json',
                                      },
                                      body: json.encode({
                                        'userName':
                                            (name != null && name.isNotEmpty)
                                            ? name
                                            : 'CineUser',
                                        'userHandle':
                                            (handle != null &&
                                                handle.isNotEmpty)
                                            ? handle
                                            : '@cineuser',
                                        'userAvatar':
                                            (avatar != null &&
                                                avatar.isNotEmpty)
                                            ? avatar
                                            : 'https://i.pravatar.cc/150?img=12',
                                        'text': controller.text.trim(),
                                      }) );

                                    if (response.statusCode == 200) {
                                      final updatedComments = json.decode(
                                        response.body );
                                      setState(() {
                                        _localCommentsList = updatedComments;
                                        _commentCount = updatedComments.length;
                                        _isPostingComment = false;
                                      });
                                      setModalState(() {
                                        _localCommentsList = updatedComments;
                                        _isPostingComment = false;
                                      });
                                      controller.clear();
                                    } else {
                                      throw Exception('Failed to post comment');
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      _isPostingComment = false;
                                    });
                                    setState(() {
                                      _isPostingComment = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.send),
                                color: Colors.blue ),
                      ] ),
                  ] ) ) );
          } );
      } );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  bool _captionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background video / image ──────────────────────────────────
          if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty)
            Positioned.fill(
              child: FeedVideoPlayer(
                videoUrl: widget.videoUrl!,
                thumbnailUrl: widget.thumbnailUrl,
                isReel: true ) )
          else if (widget.images.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: widget.images.first,
                fit: BoxFit.cover, 
                placeholder: (_, _) => Container(color: Colors.grey[900]),
                errorWidget: (_, _, _) => Container(color: Colors.grey[900]) ) ),

          // ── 2. Top vignette ───────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0, height: 160,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent] ) ) ) ),

          // ── 3. Bottom scrim ───────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0, height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.88), Colors.transparent] ) ) ) ),

          // ── 4. Top "REELS" bar ────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.35) ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 17) ) ),
                    const Spacer(),
                    Text('REELS',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3 )),
                    const Spacer(),
                    const SizedBox(width: 36),
                  ] ) ) ) ),

          // ── 5. Bottom-left: avatar + user info + caption + audio ──────────
          Positioned(
            left: 16,
            bottom: 36,
            width: screenW * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar row with neon ring + follow pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Neon-ring avatar
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            userHandle: widget.userHandle,
                            initialName: widget.userName,
                            initialAvatar: widget.userAvatar ) ) ),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00F0FF), Color(0xFFFF0055)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.45),
                              blurRadius: 14 ),
                          ] ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: CacheUtility.getAvatarProvider(widget.userAvatar) ) ) ),
                    const SizedBox(width: 12),
                    // Name + handle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.userName,
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          Text('@${widget.userHandle}',
                              style: GoogleFonts.outfit(
                                  color: Colors.white54, fontSize: 12)),
                        ] ) ),
                    // Follow pill
                    if (widget.userHandle != _localHandle)
                      GestureDetector(
                        onTap: _onFollow,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isFollowing
                                  ? Colors.white38
                                  : const Color(0xFF00F0FF),
                              width: 1.4 ),
                            color: _isFollowing
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFF00F0FF).withValues(alpha: 0.12) ),
                          child: _isLoadingFollow
                              ? const SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _isFollowing ? 'Following' : '+ Follow',
                                  style: GoogleFonts.outfit(
                                    color: _isFollowing
                                        ? Colors.white70
                                        : const Color(0xFF00F0FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold ) ) ) ),
                  ] ),

                const SizedBox(height: 12),

                // Caption with expand
                if (widget.text != null && widget.text!.trim().isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _captionExpanded = !_captionExpanded),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: widget.text!,
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4) ),
                          if (!_captionExpanded && widget.text!.length > 80)
                            TextSpan(
                              text: '  more',
                              style: GoogleFonts.outfit(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold) ),
                        ] ),
                      maxLines: _captionExpanded ? null : 2,
                      overflow: _captionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis ) ),

                const SizedBox(height: 14),

                // Spinning audio disc
                _ReelAudioLabel(discController: _discController),
              ] ) ),

          // ── 6. Right action column ────────────────────────────────────────
          Positioned(
            right: 10,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)) ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Like
                  ScaleTransition(
                    scale: _heartScale,
                    child: _ActionBtn(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? const Color(0xFFFF2D55) : Colors.white,
                      glow: _isLiked ? const Color(0xFFFF2D55) : null,
                      onTap: _onLike ) ),
                  Text(_formatCount(_likeCount),
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 11)),
                  const SizedBox(height: 18),

                  // Comment
                  _ActionBtn(
                    icon: Icons.mode_comment_outlined,
                    color: Colors.white,
                    onTap: _onComment ),
                  Text(_formatCount(_commentCount),
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 11)),
                  const SizedBox(height: 18),

                  // Bookmark
                  _ActionBtn(
                    icon: _isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _isBookmarked
                        ? const Color(0xFF00F0FF)
                        : Colors.white,
                    glow: _isBookmarked ? const Color(0xFF00F0FF) : null,
                    onTap: () => setState(() => _isBookmarked = !_isBookmarked) ),
                  Text('Save',
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 11)),
                  const SizedBox(height: 18),

                  // Share
                  _ActionBtn(
                    icon: Icons.reply_rounded,
                    color: Colors.white,
                    mirrorX: true,
                    onTap: () {
                      final txt =
                          'Check out this post by ${widget.userName} on CineSocial!\n\n${widget.text ?? ''}\n\n$baseUrl/post/${widget.postId}';
                      SharePlus.instance.share(ShareParams(text: txt));
                    } ),
                  Text('Share',
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 11)),

                  // Delete (own posts)
                  if (widget.userHandle == _localHandle) ...[
                    const SizedBox(height: 18),
                    _ActionBtn(
                      icon: Icons.more_horiz_rounded,
                      color: Colors.white,
                      onTap: () {
                        if (widget.onDelete != null) widget.onDelete!();
                      } ),
                  ],
                ] ) ) ),

          // ── 7. Bottom neon progress scrubber ──────────────────────────────
          const Positioned(
            bottom: 0, left: 0, right: 0,
            child: _ProgressScrubber() ),
        ] ) );
  }
}

// ── Helper: Spinning audio disc ───────────────────────────────────────────────

class _ReelAudioLabel extends StatelessWidget {
  final AnimationController discController;
  const _ReelAudioLabel({required this.discController});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: discController,
          builder: (_, child) => Transform.rotate(
            angle: discController.value * 2 * math.pi,
            child: child ),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00F0FF), Color(0xFF0040FF)] ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                    blurRadius: 8),
              ] ),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 14) ) ),
        const SizedBox(width: 8),
        Text('Original Audio',
            style: GoogleFonts.outfit(
                color: Colors.white70, fontSize: 12,
                fontWeight: FontWeight.w600)),
      ] );
  }
}

// ── Helper: Right-side action button ─────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? glow;
  final VoidCallback onTap;
  final bool mirrorX;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.glow,
    this.mirrorX = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconW = Icon(icon, color: color, size: 30);
    if (mirrorX) {
      iconW = Transform.scale(scaleX: -1, child: iconW);
    }
    return GestureDetector(
      onTap: onTap,
      child: glow != null
          ? Stack(alignment: Alignment.center, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: glow!.withValues(alpha: 0.35), blurRadius: 16)
                  ] ) ),
              iconW,
            ])
          : SizedBox(width: 44, height: 44,
              child: Center(child: iconW)) );
  }
}

// ── Helper: Bottom progress scrubber ─────────────────────────────────────────

class _ProgressScrubber extends StatelessWidget {
  const _ProgressScrubber();

  @override
  Widget build(BuildContext context) {
    // Thin neon line at the very bottom — static styling,
    // actual video progress comes from FeedVideoPlayer's own progress bar
    return Container(
      height: 2.5,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00F0FF), Color(0xFFFF0055)] ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.6),
              blurRadius: 6),
        ] ) );
  }
}


