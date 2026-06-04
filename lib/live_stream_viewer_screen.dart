import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'utils.dart'; // to get serverIp and CacheUtility

class LiveStreamViewerScreen extends StatefulWidget {
  final String streamId;
  final String title;
  final String host;
  final String hostAvatar;

  const LiveStreamViewerScreen({
    super.key,
    required this.streamId,
    required this.title,
    required this.host,
    required this.hostAvatar,
  });

  @override
  State<LiveStreamViewerScreen> createState() => _LiveStreamViewerScreenState();
}

class _LiveStreamViewerScreenState extends State<LiveStreamViewerScreen>
    with TickerProviderStateMixin {
  // WebSockets
  WebSocket? _socket;
  Uint8List? _currentFrameBytes;

  // Live stats
  int _viewerCount = 0;
  int _likeCount = 0;
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _chatScroll = ScrollController();
  final _commentController = TextEditingController();

  String _displayName = 'Viewer';

  // Animations
  late AnimationController _pulseController;
  late AnimationController _likeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _likeAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.elasticOut),
    );

    _loadUserInfo();
    _connectWebSocket();
  }

  Future<void> _loadUserInfo() async {
    final name = await CacheUtility.getProfileValue('name');
    if (mounted) {
      setState(() {
        if (name != null) _displayName = name;
      });
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      final ip = serverIp;
      _socket = await WebSocket.connect('ws://$ip:5000').timeout(
        const Duration(seconds: 5),
      );

      // Join the stream
      _wsSend({
        'type': 'join_stream',
        'streamId': widget.streamId,
        'username': _displayName,
      });

      _socket!.listen(
        (message) {
          final data = json.decode(message);
          if (!mounted) return;

          switch (data['type']) {
            case 'join_success':
              setState(() {
                _viewerCount = data['viewersCount'] ?? 1;
                _likeCount = data['likes'] ?? 0;
                
                // Add initial comments if any
                if (data['comments'] != null) {
                  _chatMessages.clear();
                  for (var c in data['comments']) {
                    _chatMessages.add({
                      'user': c['username'] ?? 'Anonymous',
                      'msg': c['message'] ?? '',
                    });
                  }
                }
              });
              _scrollChat();
              break;

            case 'video_frame':
              if (data['frame'] != null) {
                setState(() {
                  _currentFrameBytes = base64Decode(data['frame']);
                });
              }
              break;

            case 'stats_update':
              setState(() {
                _viewerCount = data['viewersCount'] ?? _viewerCount;
                _likeCount = data['likes'] ?? _likeCount;
              });
              break;

            case 'chat_message':
              setState(() {
                _chatMessages.add({
                  'user': data['comment']['username'] ?? 'Anonymous',
                  'msg': data['comment']['message'] ?? '',
                });
              });
              _scrollChat();
              break;

            case 'stream_ended':
              _handleStreamEnded();
              break;
          }
        },
        onError: (err) {
          debugPrint('WS stream error: $err');
          _showDisconnectError();
        },
        onDone: () {
          debugPrint('WS stream closed by server');
          _handleStreamEnded();
        },
      );
    } catch (e) {
      debugPrint('WS connection error: $e');
      _showDisconnectError();
    }
  }

  void _wsSend(Map<String, dynamic> data) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(json.encode(data));
    }
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _wsSend({
      'type': 'chat_message',
      'streamId': widget.streamId,
      'username': _displayName,
      'message': text,
    });

    _commentController.clear();
  }

  void _sendLike() {
    _wsSend({
      'type': 'like',
      'streamId': widget.streamId,
    });
    _likeController.forward(from: 0.0);
  }

  void _handleStreamEnded() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF151528),
          title: Text(
            'Stream Ended',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'The broadcaster has finished this live stream.',
            style: GoogleFonts.outfit(color: Colors.white54),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Pop dialog
                Navigator.pop(context); // Pop stream screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0055),
                foregroundColor: Colors.white,
              ),
              child: Text('Go Back', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisconnectError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to connect to active stream server.')),
    );
    Navigator.pop(context);
  }

  void _leaveStream() {
    _wsSend({'type': 'leave_stream', 'streamId': widget.streamId});
    _socket?.close();
    Navigator.pop(context);
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _likeController.dispose();
    _commentController.dispose();
    _chatScroll.dispose();
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── VIDEO STREAM PREVIEW BACKGROUND ──
          SizedBox.expand(
            child: _currentFrameBytes != null
                ? Image.memory(
                    _currentFrameBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true, // prevents flickering between frames!
                  )
                : Container(
                    color: const Color(0xFF0C0C14),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.sensors_rounded,
                            color: Color(0xFFFF0055),
                            size: 54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Connecting to broadcast feed...',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Gradient Overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xEE000000),
                ],
                stops: [0, 0.25, 0.65, 1],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── TOP BAR ──
                _buildTopBar(),

                const Spacer(),

                // ── CHAT FEED ──
                _buildChatFeed(),

                // ── BOTTOM CONTROLS / COMMENT FIELD ──
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0055),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Stream Title & Host Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'by ${widget.host}',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Viewers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatCount(_viewerCount),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Close / Exit
          GestureDetector(
            onTap: _leaveStream,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatFeed() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        controller: _chatScroll,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: _chatMessages.length,
        itemBuilder: (context, i) {
          final msg = _chatMessages[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: _randomColor(msg['user']!),
                  child: Text(
                    msg['user']![0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${msg['user']}  ',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00F0FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: msg['msg'],
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _randomColor(String seed) {
    final colors = [
      const Color(0xFFFF0055),
      const Color(0xFF00F0FF),
      const Color(0xFF9D00FF),
      const Color(0xFFFF6B00),
      const Color(0xFF00D4AA),
      const Color(0xFFFFD600),
    ];
    return colors[seed.hashCode.abs() % colors.length];
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        children: [
          // Comment box
          Expanded(
            child: TextField(
              controller: _commentController,
              onSubmitted: (_) => _sendComment(),
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Say something live...',
                hintStyle: GoogleFonts.outfit(color: Colors.white38),
                filled: true,
                fillColor: Colors.black54,
                suffixIcon: IconButton(
                  onPressed: _sendComment,
                  icon: const Icon(Icons.send, color: Color(0xFF00F0FF), size: 18),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Floating Like button
          GestureDetector(
            onTap: _sendLike,
            child: ScaleTransition(
              scale: _likeAnim,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF0055),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FF0055),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
