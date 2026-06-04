import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../profile_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import '../utils.dart';
import 'feed_video_player.dart';
import 'social_feed_card.dart' show FullScreenImageViewer;
import 'package:flutter_application_1/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';


/// Instagram-style social feed card with fully interactive state.
class InstaFeedCard extends StatefulWidget {
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

  const InstaFeedCard({
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
  State<InstaFeedCard> createState() => _InstaFeedCardState();
}

class _InstaFeedCardState extends State<InstaFeedCard>
    with TickerProviderStateMixin {
  late int _likeCount;
  late int _commentCount;
  bool _isLiked = false;
  bool _isReposted = false;
  bool _isBookmarked = false;
  bool _isPostingComment = false;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  late int _repostCount;
  late List<dynamic> _localCommentsList;
  String _localHandle = '@cineuser';
  late String _currentTimeAgo;

  // Heart animation
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
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

  @override
  void didUpdateWidget(covariant InstaFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timeAgo != oldWidget.timeAgo) {
      _currentTimeAgo = TimeUtility.getTimeAgo(widget.timeAgo);
    }
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
                                      throw Exception('Failed to post comment: ${response.statusCode}');
                                    }
                                  } catch (e) {
                                    debugPrint('Comment post error: $e');
                                    setModalState(() {
                                      _isPostingComment = false;
                                    });
                                    setState(() {
                                      _isPostingComment = false;
                                    });
                                    
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to post comment. Please try again.',
                                            style: GoogleFonts.outfit() ),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating ) );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.send),
                                color: Colors.blue ),
                      ] ),
                  ] ) ) );
          } );
      } );
  }

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
          style: const TextStyle(
            color: Color(0xFF00F0FF),
            fontWeight: FontWeight.w600 ) ) );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 15,
          height: 1.4 ),
        children: spans ) );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(
          0xFF1E1B4B ).withValues(alpha: 0.7), // Indigo hint, glassmorphic base
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.2),
          width: 1 ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8) ),
        ] ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProfileScreen(
                              userHandle: widget.userHandle,
                              initialName: widget.userName,
                              initialAvatar: widget.userAvatar ) ) );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2 ),
                      ] ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage: CacheUtility.getAvatarProvider(
                        widget.userAvatar ),
                      backgroundColor: Colors.grey[900] ) ) ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileScreen(
                                      userHandle: widget.userHandle,
                                      initialName: widget.userName,
                                      initialAvatar: widget.userAvatar ) ) );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.userName,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 0.2 ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis ) ),
                                  if (widget.isVerified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.verified,
                                        color: Colors.blueAccent,
                                        size: 16 ) ),
                                ] ),
                              Text(
                                '${widget.userHandle} • $_currentTimeAgo',
                                style: GoogleFonts.outfit(
                                  color: Colors.grey[400],
                                  fontSize: 13 ) ),
                            ] ) ) ),
                      if (widget.userHandle != _localHandle) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _onFollow,
                          style: TextButton.styleFrom(
                            side: BorderSide(
                              color: _isFollowing ? Colors.white54 : Colors.blueAccent ),
                            backgroundColor: _isFollowing ? Colors.transparent : Colors.blueAccent.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(0, 0),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4) ),
                          child: _isLoadingFollow
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2) )
                              : Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: GoogleFonts.outfit(
                                    color: _isFollowing ? Colors.white54 : Colors.blueAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12 ) ) ),
                      ],
                    ] ) ),
                if (widget.userHandle == '@cineuser')
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Colors.white54,
                      size: 24 ),
                    onSelected: (value) {
                      if (value == 'delete' && widget.onDelete != null) {
                        widget.onDelete!();
                      }
                    },
                    color: const Color(0xFF16181C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15) ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20 ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete Post',
                              style: GoogleFonts.outfit(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600 ) ),
                          ] ) ),
                    ] )
                else
                  const Icon(Icons.more_horiz, color: Colors.white54, size: 24),
              ] ) ),

          // Caption
          if (widget.text != null && widget.text!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _buildRichText(widget.text!) ),

          // Media
          if (!widget.isCommentView) ...[
            if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FeedVideoPlayer(
                  videoUrl: widget.videoUrl!,
                  thumbnailUrl: widget.thumbnailUrl ) )
            else if (widget.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageGrid() ) ),
          ],

          if (!widget.isCommentView &&
              (widget.videoUrl != null || widget.images.isNotEmpty))
            const SizedBox(height: 12),

          // Actions Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ScaleTransition(
                      scale: _heartScale,
                      child: GestureDetector(
                        onTap: _onLike,
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.redAccent : Colors.white,
                          size: 28 ) ) ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: _onComment,
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 26 ) ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        final String shareText =
                            'Check out this post by ${widget.userName} (@${widget.userHandle}) on CineSocial!\n\n${widget.text ?? ''}\n\n$baseUrl/post/${widget.postId}';
                        SharePlus.instance.share(ShareParams(text: shareText));
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 26 ) ),
                  ] ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _onBookmark,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: _isBookmarked
                            ? Colors.purpleAccent
                            : Colors.white,
                        size: 28 ) ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: _onRepost,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        _isReposted ? Icons.repeat_on : Icons.repeat,
                        color: _isReposted ? Colors.greenAccent : Colors.white,
                        size: 28 ) ),
                  ] ),
              ] ) ),

          // Likes Count & Comments Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      '${_formatCount(_likeCount)} likes',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15 ) ) ),
                if (_commentCount > 0) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _onComment,
                    child: Text(
                      'View all ${_formatCount(_commentCount)} comments',
                      style: GoogleFonts.outfit(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w500 ) ) ),
                ],
                const SizedBox(height: 16),
              ] ) ),
        ] ) );
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
        child: CachedNetworkImage(
          imageUrl: widget.images[0],
          fit: BoxFit.cover, 
          width: double.infinity,
          placeholder: (context, url) => Container(
            height: 300,
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.3),
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent) ) ) ) ),
          errorWidget: (c, u, e) => Container(
            height: 300,
            color: const Color(0xFF16181C),
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white24, size: 36) ) ) ) );
    }

    return GridView.builder(
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
              color: const Color(0xFF1E1B4B).withValues(alpha: 0.3),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent) ) ) ) ),
            errorWidget: (c, u, e) => Container(
              color: const Color(0xFF16181C),
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.white24, size: 24) ) ) ) );
      } );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

