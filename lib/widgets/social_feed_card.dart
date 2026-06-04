import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import '../utils.dart';
import '../profile_screen.dart';
import 'feed_video_player.dart';
import 'package:flutter_application_1/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';


/// Twitter/X-style social feed card with fully interactive state.
class SocialFeedCard extends StatefulWidget {
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
  final bool isCommentView;
  final String localHandle;
  final bool initialIsFollowing;

  const SocialFeedCard({
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
    this.isCommentView = false,
    this.localHandle = '@cineuser',
    this.initialIsFollowing = false,
  });

  @override
  State<SocialFeedCard> createState() => _SocialFeedCardState();
}

class _SocialFeedCardState extends State<SocialFeedCard>
    with TickerProviderStateMixin {
  late int _likeCount;
  late int _repostCount;
  late int _commentCount;
  bool _isLiked = false;
  bool _isReposted = false;
  bool _isBookmarked = false;
  bool _isPostingComment = false;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  late List<dynamic> _localCommentsList;
  String _localHandle = '@cineuser';
  late String _currentTimeAgo;

  // Heart animation
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    // Use the handle passed from the parent — no async read needed
    _localHandle = widget.localHandle;
    _likeCount = widget.likes;
    _repostCount = widget.reposts;
    _commentCount = widget.comments;
    _localCommentsList = List.from(widget.commentsList);
    _isLiked = widget.likedBy.contains(_localHandle);
    _isBookmarked = widget.bookmarkedBy.contains(_localHandle);
    _isFollowing = widget.userHandle != _localHandle ? widget.initialIsFollowing : false;
    _currentTimeAgo = TimeUtility.getTimeAgo(widget.timeAgo);

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300) );
    _heartScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut) );
    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _heartController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _onFollow() async {
    if (_isLoadingFollow) return;

    // Optimistic update
    final prevState = _isFollowing;
    setState(() {
      _isLoadingFollow = true;
      _isFollowing = !_isFollowing;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/${widget.userHandle}/follow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': _localHandle}) );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          // Backend always returns 'isFollowing' (confirmed from API)
          setState(() => _isFollowing = data['isFollowing'] ?? !prevState);
        }
      } else {
        // Revert on non-200
        if (mounted) setState(() => _isFollowing = prevState);
      }
    } catch (e) {
      debugPrint('Follow error: $e');
      if (mounted) {
        setState(() => _isFollowing = prevState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update follow. Try again.',
                style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)) ) );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  @override
  void didUpdateWidget(covariant SocialFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timeAgo != oldWidget.timeAgo) {
      _currentTimeAgo = TimeUtility.getTimeAgo(widget.timeAgo);
    }
    // Sync state if props change (e.g. parent refreshes or updates list)
    if (widget.likes != oldWidget.likes) {
      _likeCount = widget.likes;
    }
    if (widget.likedBy != oldWidget.likedBy) {
      _isLiked = widget.likedBy.contains(_localHandle);
    }
    if (widget.bookmarkedBy != oldWidget.bookmarkedBy) {
      _isBookmarked = widget.bookmarkedBy.contains(_localHandle);
    }
    if (widget.comments != oldWidget.comments) {
      _commentCount = widget.comments;
    }
    if (widget.commentsList != oldWidget.commentsList) {
      _localCommentsList = List.from(widget.commentsList);
    }
  }



  Future<void> _onLike() async {
    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    if (_isLiked) _heartController.forward();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.posts}/${widget.postId}/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': _localHandle}) );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _likeCount = data['likes'];
          _isLiked = data['isLiked'] ?? _isLiked;
        });

        // Notify parent so state is preserved during scrolling/recycling
        if (widget.onLikeChanged != null) {
          widget.onLikeChanged!(_likeCount, _isLiked);
        }
      }
    } catch (e) {
      debugPrint('Like error: $e');
      // Revert on error
      setState(() {
        _likeCount -= _isLiked ? 1 : -1;
        _isLiked = !_isLiked;
      });
    }
  }

  Future<void> _onRepost() async {
    // Optimistic UI update
    setState(() {
      _isReposted = !_isReposted;
      _repostCount += _isReposted ? 1 : -1;
    });

    if (_isReposted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reposted to your feed',
            style: GoogleFonts.outfit(color: Colors.white) ),
          backgroundColor: const Color(
            0xFF00BA7C ).withValues(alpha: 0.9), // Green color matching the repost icon
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10) ),
          margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
          duration: const Duration(milliseconds: 1500) ) );
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.posts}/${widget.postId}/repost'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': _localHandle}) );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _repostCount = data['reposts'];
          _isReposted = data['isReposted'] ?? _isReposted;
        });

        if (widget.onRepostChanged != null) {
          widget.onRepostChanged!(_repostCount, _isReposted);
        }
      }
    } catch (e) {
      debugPrint('Repost error: $e');
      // Revert on error
      setState(() {
        _repostCount -= _isReposted ? 1 : -1;
        _isReposted = !_isReposted;
      });
    }
  }

  Future<void> _onBookmark() async {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    if (_isBookmarked) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to your Bookmarks',
            style: GoogleFonts.outfit(color: Colors.white) ),
          backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10) ),
          margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
          duration: const Duration(milliseconds: 1500) ) );
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.posts}/${widget.postId}/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': _localHandle}) );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isBookmarked = data['isBookmarked'] ?? _isBookmarked;
        });
      }
    } catch (e) {
      debugPrint('Bookmark error: $e');
      setState(() {
        _isBookmarked = !_isBookmarked;
      });
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
                decoration: const BoxDecoration(
                  color: Color(0xFF16181C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)) ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2) ) ),
                    const SizedBox(height: 16),
                    Text(
                      'Comments',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold ) ),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: _localCommentsList.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet. Start the conversation!',
                                style: GoogleFonts.outfit(color: Colors.grey) ) )
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
                                            Text(
                                              comment['userName'] ?? 'User',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14 ) ),
                                            const SizedBox(height: 2),
                                            Text(
                                              comment['text'] ?? '',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white70,
                                                fontSize: 14 ) ),
                                          ] ) ),
                                    ] ) );
                              } ) ),
                    const Divider(color: Colors.white10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20) ),
                            child: TextField(
                              controller: controller,
                              maxLines: 4,
                              minLines: 1,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16 ),
                              decoration: InputDecoration(
                                hintText: 'Post your reply',
                                hintStyle: GoogleFonts.outfit(
                                  color: Colors.grey,
                                  fontSize: 15 ),
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
                                    color: Color(0xFF00F0FF),
                                    strokeWidth: 2 ) ) )
                            : IconButton(
                                onPressed: () async {
                                  if (controller.text.trim().isEmpty) return;

                                  setModalState(() {
                                    _isPostingComment = true;
                                  });

                                  try {
                                    final name = await CacheUtility.getProfileValue('name');
                                    final handle = await CacheUtility.getProfileValue('handle');
                                    final avatar = await CacheUtility.getProfileValue('avatar');

                                    final response = await http.post(
                                      Uri.parse(
                                        '${AppConstants.posts}/${widget.postId}/comments' ),
                                      headers: {
                                        'Content-Type': 'application/json',
                                      },
                                      body: json.encode({
                                        'userName': (name != null && name.isNotEmpty) ? name : 'CineUser',
                                        'userHandle': (handle != null && handle.isNotEmpty) ? handle : '@cineuser',
                                        'userAvatar': (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=12',
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
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to post reply.',
                                            style: GoogleFonts.outfit() ),
                                          backgroundColor: Colors.red ) );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.send),
                                color: const Color(0xFF00F0FF) ),
                      ] ),
                  ] ) ) );
          } );
      } );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isVerified
              ? const Color(0xFF00F0FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          width: 1 ),
        boxShadow: [
          BoxShadow(
            color: widget.isVerified
                ? const Color(0xFF00F0FF).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4) ),
        ] ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Neon left accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.isVerified
                      ? [const Color(0xFF00F0FF), const Color(0xFFB06EFF)]
                      : [Colors.blueAccent, Colors.purpleAccent] ) ) ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    // Post text
                    if (widget.text != null && widget.text!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildRichText(widget.text!),
                    ],
                    // Media
                    if (!widget.isCommentView) ...[
                      if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FeedVideoPlayer(
                            videoUrl: widget.videoUrl!,
                            thumbnailUrl: widget.thumbnailUrl ) ),
                      ] else if (widget.images.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImageGrid() ),
                      ],
                    ],
                    // Action bar
                    const SizedBox(height: 12),
                    _buildActionBar(),
                  ] ) ) ),
          ] ) ) );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar with optional neon verified ring
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userHandle: widget.userHandle,
                initialName: widget.userName,
                initialAvatar: widget.userAvatar ) ) ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.isVerified
                  ? const LinearGradient(
                      colors: [Color(0xFF00F0FF), Color(0xFFB06EFF)] )
                  : null,
              color: widget.isVerified ? null : Colors.transparent ),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: CacheUtility.getAvatarProvider(widget.userAvatar),
              backgroundColor: Colors.grey[800] ) ) ),
        const SizedBox(width: 10),

        // Name + handle + time
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  userHandle: widget.userHandle,
                  initialName: widget.userName,
                  initialAvatar: widget.userAvatar ) ) ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.userName,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14 ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1 ) ),
                    if (widget.isVerified) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF00F0FF), Color(0xFFB06EFF)] ) ),
                        child: const Icon(Icons.verified, color: Colors.white, size: 11) ),
                    ],
                  ] ),
                Text(
                  '${widget.userHandle}  ·  $_currentTimeAgo',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12 ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis ),
              ] ) ) ),

        // Follow button (for other users)
        if (widget.userHandle != _localHandle) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _onFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _isFollowing
                    ? Colors.transparent
                    : const Color(0xFF00F0FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isFollowing
                      ? Colors.white24
                      : const Color(0xFF00F0FF).withValues(alpha: 0.8),
                  width: 1 ) ),
              child: _isLoadingFollow
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Color(0xFF00F0FF),
                        strokeWidth: 2 ) )
                  : Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: GoogleFonts.outfit(
                        color: _isFollowing ? Colors.white38 : const Color(0xFF00F0FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12 ) ) ) ),
        ],

        const SizedBox(width: 4),
        if (widget.userHandle == _localHandle)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.white30, size: 18),
            onSelected: (value) {
              if (value == 'delete' && widget.onDelete != null) {
                widget.onDelete!();
              }
            },
            color: const Color(0xFF16181C),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('Delete', style: GoogleFonts.outfit(color: Colors.redAccent)),
                  ] ) ),
            ] )
        else
          const Icon(Icons.more_horiz, color: Colors.white24, size: 18),
      ] );
  }

  /// Highlights #hashtags and @mentions in cyan.
  Widget _buildRichText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(#\w+|@\w+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(color: Color(0xFF00F0FF)) ) );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 15,
          height: 1.35 ),
        children: spans ) );
  }

  Widget _buildImageGrid() {
    if (widget.images.length == 1) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenImageViewer(imageUrl: widget.images[0]) ) );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: widget.images[0],
            fit: BoxFit.contain, 
            width: double.infinity,
            placeholder: (context, url) => Container(
              height: 200,
              color: const Color(0xFF0F1117),
              child: const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)) ) ) ) ),
            errorWidget: (c, u, e) => Container(
              height: 200, // Keep an error fallback height
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(14) ),
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white24,
                  size: 36 ) ) ) ) ) );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2 ),
        itemCount: widget.images.length > 4 ? 4 : widget.images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FullScreenImageViewer(imageUrl: widget.images[index]) ) );
            },
            child: CachedNetworkImage(
              imageUrl: widget.images[index],
              fit: BoxFit.cover, 
              placeholder: (context, url) => Container(
                color: const Color(0xFF0F1117),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)) ) ) ) ),
              errorWidget: (c, u, e) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white24,
                    size: 24 ) ) ) ) );
        } ) );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Comments
        _actionButton(
          icon: Icons.chat_bubble_outline,
          count: _commentCount,
          onTap: _onComment ),

        // Reposts
        _actionButton(
          icon: _isReposted ? Icons.repeat_on : Icons.repeat,
          count: _repostCount,
          color: _isReposted ? const Color(0xFF00BA7C) : null,
          onTap: _onRepost ),

        // Likes
        ScaleTransition(
          scale: _heartScale,
          child: _actionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            count: _likeCount,
            color: _isLiked ? const Color(0xFFF91880) : null,
            onTap: _onLike ) ),

        // Bookmark
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _onBookmark,
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? const Color(0xFF00F0FF) : Colors.grey,
                size: 18 ) ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                final String shareText =
                    'Check out this post by ${widget.userName} (@${widget.userHandle}) on CineSocial!\n\n${widget.text ?? ''}\n\n$baseUrl/post/${widget.postId}';
                SharePlus.instance.share(ShareParams(text: shareText));
              },
              child: const Icon(Icons.ios_share, color: Colors.grey, size: 18) ),
          ] ),
      ] );
  }

  Widget _actionButton({
    required IconData icon,
    required int count,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.grey, size: 18),
            const SizedBox(width: 4),
            Text(
              _formatCount(count),
              style: GoogleFonts.outfit(
                color: color ?? Colors.grey,
                fontSize: 13 ) ),
          ] ) ) );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white) ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain, 
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)) ) ) ),
            errorWidget: (c, u, e) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 60 ) ) ) ) );
  }
}

