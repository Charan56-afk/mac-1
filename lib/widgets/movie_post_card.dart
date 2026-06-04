import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils.dart';
import '../movie_details_screen.dart';
import 'package:flutter_application_1/constants.dart';


// --- SMART CARD WIDGET ---
class MoviePostCard extends StatefulWidget {
  final Map post;
  final String currentUserId;

  const MoviePostCard({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<MoviePostCard> createState() => _MoviePostCardState();
}

class _MoviePostCardState extends State<MoviePostCard> {
  late bool isLiked;
  late int likeCount;
  late double currentRating;
  late List comments;
  DateTime _lastLikeCall = DateTime(2000);

  @override
  void initState() {
    super.initState();
    List likedBy = widget.post['likedBy'] ?? [];
    isLiked = likedBy.contains(widget.currentUserId);
    likeCount = widget.post['likes'] ?? 0;
    currentRating = (widget.post['rating'] ?? 0).toDouble();
    comments = widget.post['commentsList'] ?? [];
  }

  @override
  void didUpdateWidget(covariant MoviePostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post ||
        widget.currentUserId != oldWidget.currentUserId ||
        widget.post['likes'] != oldWidget.post['likes'] ||
        widget.post['rating'] != oldWidget.post['rating'] ||
        widget.post['commentsList'] != oldWidget.post['commentsList']) {
      setState(() {
        List likedBy = widget.post['likedBy'] ?? [];
        isLiked = likedBy.contains(widget.currentUserId);
        likeCount = widget.post['likes'] ?? 0;
        currentRating = (widget.post['rating'] ?? 0).toDouble();
        comments = widget.post['commentsList'] ?? [];
      });
    }
  }

  Future<void> _toggleLike() async {
    // Throttle: ignore if called within 1s (prevents spam at scale)
    final now = DateTime.now();
    if (now.difference(_lastLikeCall).inSeconds < 1) return;
    _lastLikeCall = now;

    final prevLiked = isLiked;
    final prevCount = likeCount;

    setState(() {
      if (isLiked) {
        isLiked = false;
        likeCount = (likeCount - 1).clamp(0, 999999999);
      } else {
        isLiked = true;
        likeCount++;
      }
      widget.post['likes'] = likeCount;
      final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
      if (isLiked) {
        if (!likedBy.contains(widget.currentUserId)) likedBy.add(widget.currentUserId);
      } else {
        likedBy.remove(widget.currentUserId);
      }
      widget.post['likedBy'] = likedBy;
    });

    try {
      final res = await http.put(
        Uri.parse('${AppConstants.reviews}/${widget.post['_id']}/like'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"userId": widget.currentUserId}) ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        _rollbackLike(prevLiked, prevCount);
      }
    } catch (e) {
      debugPrint("Like failed: $e");
      _rollbackLike(prevLiked, prevCount);
    }
  }

  void _rollbackLike(bool prevLiked, int prevCount) {
    if (!mounted) return;
    setState(() {
      isLiked = prevLiked;
      likeCount = prevCount;
      widget.post['likes'] = likeCount;
      final likedBy = (widget.post['likedBy'] as List?)?.cast<String>() ?? [];
      if (isLiked) {
        if (!likedBy.contains(widget.currentUserId)) likedBy.add(widget.currentUserId);
      } else {
        likedBy.remove(widget.currentUserId);
      }
      widget.post['likedBy'] = likedBy;
    });
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)) ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "SEND TO...",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold ) ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: globalFriendsList.length,
                  itemBuilder: (context, index) {
                    final friend = globalFriendsList[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(friend['avatar']!) ),
                      title: Text(
                        friend['name']!,
                        style: const TextStyle(color: Colors.white) ),
                      trailing: const Icon(
                        Icons.send,
                        color: Color(0xFF00F0FF) ),
                      onTap: () {
                        // Capture the messenger before popping the context
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              "Sent '${widget.post['movieTitle']}' to ${friend['name']}!" ) ) );
                      } );
                  } ) ),
            ] ) );
      } );
  }

  void _showCommentDialog() {
    TextEditingController commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(
            "Add Comment",
            style: GoogleFonts.outfit(color: Colors.white) ),
          content: TextField(
            controller: commentController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Type your thoughts...",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00F0FF)) ) ) ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)) ),
            ElevatedButton(
              onPressed: () async {
                if (commentController.text.isNotEmpty) {
                  final text = commentController.text;
                  final optimisticComment = {
                    "user": widget.currentUserId,
                    "text": text,
                  };
                  if (mounted) {
                    setState(() {
                      comments.add(optimisticComment);
                      widget.post['commentsList'] = comments;
                    });
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }

                  try {
                    final url = Uri.parse(
                      '${AppConstants.reviews}/${widget.post['_id']}/comment' );
                    final res = await http.post(
                      url,
                      headers: {"Content-Type": "application/json"},
                      body: json.encode({
                        "user": widget.currentUserId,
                        "text": text,
                      }) ).timeout(const Duration(seconds: 8));

                    if (res.statusCode == 200) {
                      final data = json.decode(res.body);
                      if (mounted) {
                        setState(() {
                          comments = List.from(data['commentsList'] ?? comments);
                          widget.post['commentsList'] = comments;
                        });
                      }
                    } else {
                      _rollbackComment(optimisticComment);
                    }
                  } catch (e) {
                    debugPrint("Comment failed: $e");
                    _rollbackComment(optimisticComment);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF) ),
              child: const Text(
                "Post",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold ) ) ),
          ] );
      } );
  }

  void _rollbackComment(Map optimisticComment) {
    if (!mounted) return;
    setState(() {
      comments.remove(optimisticComment);
      widget.post['commentsList'] = comments;
    });
  }


  @override
  Widget build(BuildContext context) {
    final movieTitle = widget.post['movieTitle'] ?? "Unknown Title";
    final comment = widget.post['comment'] ?? "No description";
    final posterUrl = widget.post['posterUrl'] ?? "";

    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(
              movie: widget.post,
              heroTag: widget.post['_id'] ) ) ).then((_) {
          if (mounted) {
            setState(() {
              List likedBy = widget.post['likedBy'] ?? [];
              isLiked = likedBy.contains(widget.currentUserId);
              likeCount = widget.post['likes'] ?? 0;
              currentRating = (widget.post['rating'] ?? 0).toDouble();
              comments = widget.post['commentsList'] ?? [];
            });
          }
        });
      },
      child: Container(
        height: 460,
        margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // 1. Back Glow / Base Panel
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101216),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10) ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05) ) ) ) ),
            
            // 2. Floating Poster
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 25,
                      offset: const Offset(0, 15) ),
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: -5,
                      offset: const Offset(0, 10) ),
                  ] ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover, 
                    placeholder: (c, u) => Container(color: Colors.grey[900]),
                    errorWidget: (c, u, e) => Container(color: Colors.grey[900], child: const Icon(Icons.error)) ) ) ) ),
            
            // 3. Floating Rating Badge
            Positioned(
              top: 260, // Overlaps the bottom edge of the poster
              right: 35, 
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16181C),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4) ),
                  ] ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      currentRating.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        color: Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold ) ),
                  ] ) ) ),
            
            // 4. Overlapping Info Panel
            Positioned(
              top: 310,
              left: 20,
              right: 20,
              bottom: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          movieTitle,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF00F0FF),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5 ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis ) ),
                      if (widget.post['isVerified'] == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF00F0FF), Color(0xFFFF0055)] ) ),
                            child: const Icon(Icons.verified, color: Colors.white, size: 14) ) ),
                    ] ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5 ) ) ),
                  
                  const Spacer(),
                  
                  // Interaction Row (Minimal)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInteractionIcon(
                        icon: isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isLiked ? const Color(0xFFFF0055) : Colors.white54,
                        label: "$likeCount",
                        onTap: _toggleLike ),
                      _buildInteractionIcon(
                        icon: Icons.chat_bubble_outline,
                        color: Colors.white54,
                        label: "${comments.length}",
                        onTap: _showCommentDialog ),
                      _buildInteractionIcon(
                        icon: Icons.send_rounded,
                        color: Colors.white54,
                        label: "Share",
                        onTap: _showShareSheet ),
                    ] ),
                ] ) ),
          ] ) ) );
  }

  Widget _buildInteractionIcon({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.transparent, // increases tap area
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold ) ),
          ] ) ) );
  }
}
