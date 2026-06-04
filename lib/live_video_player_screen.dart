import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LiveVideoPlayerScreen extends StatefulWidget {
  final Map stream;

  const LiveVideoPlayerScreen({super.key, required this.stream});

  @override
  State<LiveVideoPlayerScreen> createState() => _LiveVideoPlayerScreenState();
}

class _LiveVideoPlayerScreenState extends State<LiveVideoPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isLiked = false;
  int _likesCount = 0;
  
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, String>> _comments = [];

  @override
  void initState() {
    super.initState();
    
    // Parse initial likes count (mock parsing "89K" -> 89000 for demo, or just use int logic)
    // For simplicity, we just keep it as an int that we increment.
    _likesCount = _parseK(widget.stream['likes'] ?? '0K');

    // Setup YouTube controller
    final videoId = widget.stream['videoId'] ?? '1ZNgOGO1Lio';
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        isLive: true,
      ),
    );

    // Initial mock comments
    _comments = [
      {'user': 'Rahul99', 'text': 'Can\'t wait for this! 🔥'},
      {'user': 'CineFanatic', 'text': 'The visuals look insane!'},
      {'user': 'TollywoodKing', 'text': 'When are the tickets opening?'},
      {'user': 'Priya_M', 'text': 'Wow, the BGM is giving me goosebumps!'},
      {'user': 'NTR_Devotee', 'text': 'Jai NTR! 🙏'},
      {'user': 'MovieBuff22', 'text': 'Let\'s goooooooooo!'},
    ];
  }

  int _parseK(String kString) {
    try {
      final str = kString.replaceAll('K', '').replaceAll('k', '');
      return (double.parse(str) * 1000).toInt();
    } catch (e) {
      return 1000;
    }
  }

  String _formatLikes(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likesCount++;
      } else {
        _likesCount--;
      }
    });
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _comments.add({'user': 'You', 'text': text});
        _commentController.clear();
      });
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            // YouTube Player
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFFFF0055),
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFFFF0055),
                handleColor: Color(0xFFFF0055),
              ),
              topActions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.stream['title'] ?? 'Live Video',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Video Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.stream['title'] ?? 'Unknown Title',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0055),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "LIVE",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.visibility, color: Colors.white54, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.stream['viewers']} watching",
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: CachedNetworkImageProvider(widget.stream['hostAvatar'] ?? ''),
                        backgroundColor: Colors.grey[800],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.stream['host'] ?? 'Unknown Host',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "1.2M subscribers",
                              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      
                      // Interactive Action Buttons
                      Row(
                        children: [
                          _buildActionButton(
                            icon: _isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded,
                            label: _formatLikes(_likesCount),
                            color: _isLiked ? const Color(0xFF00F0FF) : Colors.white,
                            onTap: _handleLike,
                          ),
                          const SizedBox(width: 16),
                          _buildActionButton(
                            icon: Icons.share_rounded,
                            label: "Share",
                            color: Colors.white,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Live Chat Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.forum_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Live Chat",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Comments List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  final isMe = comment['user'] == 'You';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isMe ? const Color(0xFF00F0FF) : Colors.grey[800],
                          child: Text(
                            comment['user']!.substring(0, 1),
                            style: TextStyle(
                              color: isMe ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment['user']!,
                                style: GoogleFonts.outfit(
                                  color: isMe ? const Color(0xFF00F0FF) : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                comment['text']!,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Comment Input Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF161824),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Chat publicly as You...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _addComment,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00F0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
