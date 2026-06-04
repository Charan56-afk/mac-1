import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'utils.dart'; // Make sure $baseUrl is in utils

class MovieInfoScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  final bool isGenreMovie;

  const MovieInfoScreen({
    super.key,
    required this.movie,
    this.isGenreMovie = false,
  });

  @override
  State<MovieInfoScreen> createState() => _MovieInfoScreenState();
}

class _MovieInfoScreenState extends State<MovieInfoScreen>
    with TickerProviderStateMixin {
  bool _isLiked = false;
  bool _isBookmarked = false;
  int _likeCount = 0;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _comments = [];

  // Avatar colors for comments
  final List<Color> _avatarColors = [
    const Color(0xFF7C4DFF),
    const Color(0xFF00BCD4),
    const Color(0xFFFF5722),
    const Color(0xFF4CAF50),
    const Color(0xFFE91E63),
    const Color(0xFFFF9800),
  ];

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.movie['videoUrl'] != null && widget.movie['videoUrl'].toString().isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.movie['videoUrl']))
        ..initialize().then((_) {
          _videoController!.setVolume(1.0);
          _videoController!.setLooping(true);
          _videoController!.play();
          if (mounted) setState(() {});
        }).catchError((e) {
          debugPrint("Video play error: $e");
        });
    }

    // Use real comments from the database
    final dbComments = widget.movie['commentsList'] as List? ?? [];
    for (int i = 0; i < dbComments.length; i++) {
      final c = dbComments[i] as Map;
      _comments.add({
        'user': c['user'] ?? 'User',
        'comment': c['text'] ?? '',
        'rating': null,
        'time': 'Recent',
        'isOwn': c['user'] == 'Mobile_User_1',
      });
    }

    // Use real likes from the database
    _likeCount = widget.movie['likes'] ?? 0;
    final likedBy = widget.movie['likedBy'] as List? ?? [];
    if (likedBy.contains('Mobile_User_1')) {
      _isLiked = true;
    }

    // Initialize bookmark state
    final bookmarkedBy = widget.movie['bookmarkedBy'] as List? ?? [];
    if (bookmarkedBy.contains('Mobile_User_1')) {
      _isBookmarked = true;
    }

    // Like animation
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300) );
    _likeScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _likeAnimController, curve: Curves.easeInOut) );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _likeAnimController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final bool isCurrentlyLiked = _isLiked;
    setState(() {
      _isLiked = !isCurrentlyLiked;
      _likeCount += isCurrentlyLiked ? -1 : 1;

      // Update parent's cached map to persist state upon screen pop
      widget.movie['likes'] = _likeCount;
      final likedBy = widget.movie['likedBy'] as List? ?? [];
      if (_isLiked) {
        if (!likedBy.contains('Mobile_User_1')) likedBy.add('Mobile_User_1');
      } else {
        likedBy.remove('Mobile_User_1');
      }
      widget.movie['likedBy'] = likedBy;
    });
    _likeAnimController.forward(from: 0);

    try {
      final movieId = widget.movie['_id'] ?? widget.movie['id'];
      final endpoint = widget.isGenreMovie ? 'genre-movies' : 'movies';
      final response = await http.post(
        Uri.parse('$baseUrl/api/$endpoint/$movieId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': 'Mobile_User_1'}) );
      if (response.statusCode != 200) {
        setState(() {
          _isLiked = isCurrentlyLiked;
          _likeCount += isCurrentlyLiked ? 1 : -1;
        });
      }
    } catch (e) {
      setState(() {
        _isLiked = isCurrentlyLiked;
        _likeCount += isCurrentlyLiked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final bool isCurrentlyBookmarked = _isBookmarked;
    setState(() {
      _isBookmarked = !isCurrentlyBookmarked;

      // Update parent's cached map to persist state upon screen pop
      final bookmarkedBy = widget.movie['bookmarkedBy'] as List? ?? [];
      if (_isBookmarked) {
        if (!bookmarkedBy.contains('Mobile_User_1')) {
          bookmarkedBy.add('Mobile_User_1');
        }
      } else {
        bookmarkedBy.remove('Mobile_User_1');
      }
      widget.movie['bookmarkedBy'] = bookmarkedBy;
    });

    try {
      final movieId = widget.movie['_id'] ?? widget.movie['id'];
      final endpoint = widget.isGenreMovie ? 'genre-movies' : 'movies';
      final response = await http.post(
        Uri.parse('$baseUrl/api/$endpoint/$movieId/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': 'Mobile_User_1'}) );

      // We expect the backend to have the bookmark endpoint logic
      // But we update optimistically anyway. If it fails, revert.
      if (response.statusCode != 200) {
        setState(() {
          _isBookmarked = isCurrentlyBookmarked;
        });
      }
    } catch (e) {
      setState(() {
        _isBookmarked = isCurrentlyBookmarked;
      });
      debugPrint("Failed to toggle bookmark: $e");
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Optimistic UI update
    setState(() {
      _comments.insert(0, {
        'user': 'Mobile_User_1',
        'comment': text,
        'rating': null,
        'time': 'Just now',
        'isOwn': true,
      });

      // Update parent's cached map to persist state upon screen pop
      final dbComments = widget.movie['commentsList'] as List? ?? [];
      dbComments.insert(0, {
        'user': 'Mobile_User_1',
        'text': text,
        'createdAt': DateTime.now().toIso8601String(),
      });
      widget.movie['commentsList'] = dbComments;
    });
    _commentController.clear();
    _commentFocusNode.unfocus();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut );
      }
    });

    try {
      final movieId = widget.movie['_id'] ?? widget.movie['id'];
      final endpoint = widget.isGenreMovie ? 'genre-movies' : 'movies';
      await http.post(
        Uri.parse('$baseUrl/api/$endpoint/$movieId/comment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user': 'Mobile_User_1', 'text': text}) );
    } catch (e) {
      debugPrint("Failed to comment: $e");
    }
  }

  Color _getOttColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'prime video':
        return const Color(0xFF00A8E1);
      case 'aha':
        return const Color(0xFFFF4500);
      case 'disney+ hotstar':
        return const Color(0xFF131A56);
      case 'sonyliv':
        return const Color(0xFFffb500);
      case 'zee5':
        return const Color(0xFF8230c6);
      default:
        return const Color(0xFF00F0FF); // Default theme color
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.movie['title'] ?? 'Unknown Title';
    final String image = widget.movie['image'] ?? '';
    final String desc = widget.movie['desc'] ?? 'No description available.';
    final String tags = widget.movie['tags'] ?? '';
    final String budget = widget.movie['budget'] ?? 'N/A';
    final String boxOffice = widget.movie['boxOffice'] ?? 'N/A';
    final String rating = widget.movie['rating']?.toString() ?? 'N/A';
    final String year = widget.movie['year']?.toString() ?? '';
    final String runtime = widget.movie['runtime'] ?? '2h 30m';
    final String? ottPlatform = widget.movie['ottPlatform']?.toString();

    final List<Map<String, dynamic>> cast =
        (widget.movie['cast'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── HERO APP BAR ──────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 420,
                  pinned: true,
                  backgroundColor: const Color(0xFF0F1014),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover, 
                          errorWidget: (_, _, _) => Container(
                            color: const Color(0xFF1A1D27),
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white24,
                              size: 80 ) ) ),
                        if (_videoController != null && _videoController!.value.isInitialized)
                          IgnorePointer(
                            child: SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController!.value.size.width,
                                  height: _videoController!.value.size.height,
                                  child: VideoPlayer(_videoController!) ) ) ) ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x990F1014),
                                Color(0xFF0F1014),
                              ],
                              stops: [0.45, 0.78, 1.0] ) ) ),
                        // Rating badge on image
                        Positioned(
                          top: 16,
                          right: 16,
                          child: SafeArea(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5 ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10) ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.black87,
                                    size: 16 ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating,
                                    style: GoogleFonts.outfit(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14 ) ),
                                ] ) ) ) ),
                        // Year badge
                        if (year.isNotEmpty)
                          Positioned(
                            bottom: 80,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3 ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24) ),
                              child: Text(
                                year,
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 12 ) ) ) ),
                      ] ) ),
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20 ),
                        onPressed: () => Navigator.pop(context) ) ) ) ),

                // ── MAIN CONTENT ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2 ) ),
                        const SizedBox(height: 6),
                        Text(
                          tags,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF00F0FF),
                            fontWeight: FontWeight.w500 ) ),
                        if (ottPlatform != null && ottPlatform.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4 ),
                            decoration: BoxDecoration(
                              color: _getOttColor(
                                ottPlatform ).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white30,
                                width: 0.5 ) ),
                            child: Text(
                              ottPlatform,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5 ) ) ),
                        ],
                        const SizedBox(height: 18),

                        // ── LIKE BUTTON ROW ───────────────────────────────────
                        _buildLikeRow(),
                        const SizedBox(height: 22),

                        // ── STATS ROW ─────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12) ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('BUDGET', budget, Colors.amber),
                              _buildStatDivider(),
                              _buildStatItem(
                                'BOX OFFICE',
                                boxOffice,
                                Colors.greenAccent ),
                              _buildStatDivider(),
                              _buildStatItem(
                                'RUNTIME',
                                runtime,
                                Colors.white70 ),
                              _buildStatDivider(),
                              _buildStatItem('RATING', rating, Colors.amber),
                            ] ) ),
                        const SizedBox(height: 26),

                        // ── SYNOPSIS ──────────────────────────────────────────
                        _buildSectionTitle('SYNOPSIS'),
                        const SizedBox(height: 10),
                        Text(
                          desc,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.white70,
                            height: 1.6 ) ),
                        const SizedBox(height: 30),

                        // ── CAST ──────────────────────────────────────────────
                        _buildSectionTitle('CAST & CREW'),
                        const SizedBox(height: 14),
                        if (cast.isEmpty)
                          Text(
                            'No cast info.',
                            style: GoogleFonts.outfit(color: Colors.white54) )
                        else
                          SizedBox(
                            height: 140,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: cast.length,
                              itemBuilder: (context, index) {
                                final actor = cast[index];
                                return Container(
                                  margin: const EdgeInsets.only(right: 16),
                                  width: 82,
                                  child: Column(
                                    children: [
                                      ClipOval(
                                        child: Container(
                                          width: 72,
                                          height: 72,
                                          color: Colors.white10,
                                          child:
                                              ((actor['image'] != null &&
                                                      actor['image']
                                                          .toString()
                                                          .isNotEmpty) ||
                                                  (actor['imageUrl'] != null &&
                                                      actor['imageUrl']
                                                          .toString()
                                                          .isNotEmpty))
                                              ? CachedNetworkImage(
                                                  imageUrl:
                                                      actor['image'] ??
                                                      actor['imageUrl'] ??
                                                      '',
                                                  fit: BoxFit.cover, 
                                                  httpHeaders: const {
                                                    'User-Agent':
                                                        'Mozilla/5.0 (Mobile) CineSocialApp/1.0',
                                                  },
                                                  errorWidget:
                                                      (
                                                        context,
                                                        url,
                                                        error ) => Center(
                                                        child: Text(
                                                          (actor['name'] !=
                                                                      null &&
                                                                  actor['name']
                                                                      .toString()
                                                                      .isNotEmpty)
                                                              ? actor['name']
                                                                    .toString()
                                                                    .substring(
                                                                      0,
                                                                      1 )
                                                                    .toUpperCase()
                                                              : '?',
                                                          style:
                                                              GoogleFonts.outfit(
                                                                color: Colors
                                                                    .white54,
                                                                fontSize: 24,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold ) ) ) )
                                              : Center(
                                                  child: Text(
                                                    (actor['name'] != null &&
                                                            actor['name']
                                                                .toString()
                                                                .isNotEmpty)
                                                        ? actor['name']
                                                              .toString()
                                                              .substring(0, 1)
                                                              .toUpperCase()
                                                        : '?',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white54,
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold ) ) ) ) ),
                                      const SizedBox(height: 8),
                                      Text(
                                        actor['name'] ?? '',
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600 ) ),
                                      Text(
                                        actor['role'] ?? '',
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white54,
                                          fontSize: 10 ) ),
                                    ] ) );
                              } ) ),
                        const SizedBox(height: 32),

                        // --- CINESOCIAL OFFICIAL REVIEW ---
                        if ((widget.movie['cineSocialRating'] ?? 0) > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00F0FF).withValues(alpha: 0.1),
                                  const Color(0xFFFF0055).withValues(alpha: 0.05),
                                ] ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.3) ) ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      color: Color(0xFF00F0FF),
                                      size: 18 ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "OFFICIAL REVIEW",
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF00F0FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 1 ) ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2 ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00F0FF),
                                        borderRadius: BorderRadius.circular(6) ),
                                      child: Text(
                                        "⭐ ${widget.movie['cineSocialRating']}",
                                        style: GoogleFonts.outfit(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12 ) ) ),
                                  ] ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.movie['cineSocialReview'] ??
                                      widget.movie['comment'] ??
                                      "Verified authentic review.",
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontStyle: FontStyle.italic ) ),
                              ] ) ),
                          const SizedBox(height: 32),
                        ],

                        // ── COMMENTS SECTION HEADER ───────────────────────────
                        Row(
                          children: [
                            _buildSectionTitle('COMMENTS'),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2 ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00F0FF ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00F0FF ).withValues(alpha: 0.4) ) ),
                              child: Text(
                                '${_comments.length}',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF00F0FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold ) ) ),
                          ] ),
                        const SizedBox(height: 14),
                      ] ) ) ),

                // ── COMMENTS LIST ─────────────────────────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final comment = _comments[index];
                    return _buildCommentCard(comment, index);
                  }, childCount: _comments.length) ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                if (_comments.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white24,
                              size: 50 ),
                            const SizedBox(height: 12),
                            Text(
                              'No comments yet. Be the first!',
                              style: GoogleFonts.outfit(
                                color: Colors.white38,
                                fontSize: 15 ) ),
                          ] ) ) ) ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ] ) ),

          // ── STICKY COMMENT INPUT ──────────────────────────────────────────
          _buildCommentInput(),
        ] ) );
  }

  Widget _buildLikeRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _toggleLike,
          child: AnimatedBuilder(
            animation: _likeScaleAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: _likeScaleAnim.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10 ),
                  decoration: BoxDecoration(
                    gradient: _isLiked
                        ? const LinearGradient(
                            colors: [Color(0xFFFF4081), Color(0xFFFF1744)] )
                        : null,
                    color: _isLiked ? null : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _isLiked
                          ? const Color(0xFFFF4081)
                          : Colors.white24,
                      width: 1.5 ) ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isLiked ? Colors.white : Colors.white60,
                        size: 20 ),
                      const SizedBox(width: 8),
                      Text(
                        _likeCount.toString(),
                        style: GoogleFonts.outfit(
                          color: _isLiked ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 14 ) ),
                    ] ) ) );
            } ) ),
        const SizedBox(width: 10),
        // Share button
        GestureDetector(
          onTap: () {
            final String title = widget.movie['title'] ?? 'Unknown Title';
            final String tags = widget.movie['tags'] ?? '';
            final String movieId =
                widget.movie['_id'] ?? widget.movie['id'] ?? '';
            final String shareText =
                'Check out "$title" ($tags) on CineSocial!\n\n$baseUrl/movie/$movieId';
            SharePlus.instance.share(ShareParams(text: shareText));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24, width: 1.5) ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.share_rounded,
                  color: Colors.white60,
                  size: 20 ),
                const SizedBox(width: 8),
                Text(
                  'Share',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 14 ) ),
              ] ) ) ),
        const SizedBox(width: 10),
        // Watchlist button
        GestureDetector(
          onTap: _toggleBookmark,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isBookmarked
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _isBookmarked ? const Color(0xFF00F0FF) : Colors.white24,
                width: 1.5 ) ),
            child: Icon(
              _isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _isBookmarked ? const Color(0xFF00F0FF) : Colors.white60,
              size: 20 ) ) ),
      ] );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment, int index) {
    final bool isOwn = comment['isOwn'] == true;
    final Color avatarColor = isOwn
        ? const Color(0xFF00F0FF)
        : _avatarColors[index % _avatarColors.length];
    final String userName = comment['user'] ?? 'User';
    final String? rating = comment['rating']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOwn
              ? const Color(0xFF00F0FF).withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwn
                ? const Color(0xFF00F0FF).withValues(alpha: 0.3)
                : Colors.white10 ) ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor.withValues(alpha: 0.25),
                  child: Text(
                    userName[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15 ) ) ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            userName,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14 ) ),
                          if (isOwn) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1 ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6) ),
                              child: Text(
                                'You',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF00F0FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold ) ) ),
                          ],
                          const Spacer(),
                          if (rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 14 ),
                            const SizedBox(width: 3),
                            Text(
                              rating,
                              style: GoogleFonts.outfit(
                                color: Colors.amber,
                                fontSize: 13,
                                fontWeight: FontWeight.bold ) ),
                          ],
                        ] ),
                      const SizedBox(height: 2),
                      Text(
                        comment['time'] ?? '',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 11 ) ),
                    ] ) ),
              ] ),
            const SizedBox(height: 10),
            Text(
              comment['comment'] ?? '',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5 ) ),
            const SizedBox(height: 8),
            // Like/Reply row
            Row(
              children: [
                _buildCommentAction(Icons.thumb_up_outlined, 'Like'),
                const SizedBox(width: 16),
                _buildCommentAction(Icons.reply_rounded, 'Reply'),
              ] ),
          ] ) ) );
  }

  Widget _buildCommentAction(IconData icon, String label) {
    return GestureDetector(
      onTap: () {},
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 15),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12) ),
        ] ) );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))) ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12 ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.25),
            child: Text(
              'Y',
              style: GoogleFonts.outfit(
                color: const Color(0xFF00F0FF),
                fontWeight: FontWeight.bold ) ) ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 14 ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10 ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)) ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF00F0FF)) ) ),
              onSubmitted: (_) => _addComment() ) ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _commentController,
            builder: (context, _) {
              final hasText = _commentController.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _addComment : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasText
                        ? const LinearGradient(
                            colors: [Color(0xFF00F0FF), Color(0xFF7C4DFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight )
                        : null,
                    color: hasText ? null : Colors.white12 ),
                  child: Icon(
                    Icons.send_rounded,
                    color: hasText ? Colors.white : Colors.white38,
                    size: 20 ) ) );
            } ),
        ] ) );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.2 ) );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ) ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.white54,
            fontWeight: FontWeight.w600,
            letterSpacing: 1 ) ),
      ] );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 35, color: Colors.white12);
  }
}

