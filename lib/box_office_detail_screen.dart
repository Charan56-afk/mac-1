import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BoxOfficeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const BoxOfficeDetailScreen({super.key, required this.movie});

  @override
  State<BoxOfficeDetailScreen> createState() => _BoxOfficeDetailScreenState();
}

class _BoxOfficeDetailScreenState extends State<BoxOfficeDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final TextEditingController _commentController = TextEditingController();

  List<Map<String, dynamic>> _comments = [];
  bool _isCommentsLoading = true;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    );

    _entryController.forward();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    final String movieId = widget.movie['_id'] ?? '';
    if (movieId.isEmpty) {
      if (mounted) setState(() => _isCommentsLoading = false);
      return;
    }

    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/box-office/$movieId/comments'))
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        if (res.statusCode == 200) {
          final List data = json.decode(res.body);
          setState(() {
            _comments = List<Map<String, dynamic>>.from(data);
            _isCommentsLoading = false;
          });
        } else {
          debugPrint('Comments fetch failed: ${res.statusCode}');
          setState(() => _isCommentsLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      if (mounted) setState(() => _isCommentsLoading = false);
    }
  }

  void _addComment() async {
    final String msg = _commentController.text.trim();
    if (msg.isEmpty) return;

    final String movieId = widget.movie['_id'] ?? '';
    if (movieId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot post comment for offline movie')),
      );
      return;
    }

    // Optimistic UI update
    final newComment = {
      "userHandle": "@current_user",
      "message": msg,
      "createdAt": DateTime.now().toIso8601String(),
    };

    setState(() {
      _comments.insert(0, newComment);
      _commentController.clear();
    });

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/box-office/$movieId/comments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"userHandle": "@current_user", "message": msg}),
      );
      if (res.statusCode != 201) {
        debugPrint('Post failed: ${res.body}');
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Color _getAccentColor() {
    final String verdict = (widget.movie['verdict'] as String? ?? 'HIT')
        .toUpperCase();
    switch (verdict) {
      case 'BLOCKBUSTER':
        return const Color(0xFFB08CFF);
      case 'HIT':
        return const Color(0xFF8CFFD4);
      case 'AVERAGE':
        return const Color(0xFFFFEB8C);
      case 'FLOP':
        return const Color(0xFFFF8C9F);
      default:
        return const Color(0xFF00FBFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor();
    final double collected = (widget.movie['collected'] as num).toDouble();
    final double target = (widget.movie['target'] as num).toDouble();
    final double recovery = target > 0
        ? (collected / target).clamp(0.0, 1.5)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberBackgroundPainter(
                color: accentColor.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        'CRITICAL_HUD v1.0',
                        style: GoogleFonts.shareTechMono(
                          color: accentColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        children: [
                          _buildFloatingHeroPoster(accentColor),
                          const SizedBox(width: 30),
                          Expanded(
                            child: _buildRecoveryGauge(recovery, accentColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    widget.movie['title']?.toUpperCase() ?? 'UNKNOWN_ENTITY',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildVerdictBadge(accentColor),
                  const SizedBox(height: 40),
                  Text(
                    'REVENUE_STREAM_ANALYSIS',
                    style: GoogleFonts.shareTechMono(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInteractiveTrendChart(accentColor),
                  const SizedBox(height: 40),
                  _buildDataGrid(accentColor),
                  const SizedBox(height: 50),
                  Text(
                    'INTEL_FEED_STREAM',
                    style: GoogleFonts.shareTechMono(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCommentInput(accentColor),
                  const SizedBox(height: 20),
                  _buildCommentList(accentColor),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'UPLOAD_INTEL...',
                hintStyle: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 12,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: _addComment,
            icon: Icon(Icons.send_rounded, color: accentColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList(Color accentColor) {
    if (_isCommentsLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(
            color: accentColor,
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'NO_INTEL_AVAILABLE',
            style: GoogleFonts.shareTechMono(
              color: Colors.white24,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return Column(
      children: _comments
          .map((c) => _buildCommentTile(c, accentColor))
          .toList(),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment, Color accentColor) {
    final String user = comment['userHandle'] ?? '@anonymous';
    final String msg = comment['message'] ?? '';
    final String rawDate = comment['createdAt'] ?? '';
    final String time = TimeUtility.getTimeAgo(rawDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user,
                style: GoogleFonts.shareTechMono(
                  color: accentColor.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                time.toUpperCase(),
                style: GoogleFonts.shareTechMono(
                  color: Colors.white24,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingHeroPoster(Color accentColor) {
    final String imagePath = widget.movie['image'] ?? '';
    final bool isAsset = imagePath.startsWith('assets/');

    return Container(
      width: 140,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: isAsset
            ? Image.asset(imagePath, fit: BoxFit.cover)
            : CachedNetworkImage(
                imageUrl: imagePath,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.movie_outlined,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRecoveryGauge(double recovery, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _RadialRecoveryPainter(
              value: recovery,
              color: accentColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(recovery * 100).toInt()}%',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RECOVERY',
                    style: GoogleFonts.shareTechMono(
                      color: accentColor.withValues(alpha: 0.7),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '₹${widget.movie['collected']}Cr / ₹${widget.movie['target']}Cr',
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerdictBadge(Color accentColor) {
    final String verdict = widget.movie['verdict'] ?? 'UNKNOWN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accentColor, blurRadius: 10, spreadRadius: 2),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            verdict,
            style: GoogleFonts.shareTechMono(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTrendChart(Color accentColor) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(20),
      child: CustomPaint(
        painter: _CyberTrendPainter(
          data: List<int>.from(widget.movie['daily'] ?? []),
          color: accentColor,
        ),
      ),
    );
  }

  Widget _buildDataGrid(Color accentColor) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _buildHudTile(
          'THEATRE_OCCUPANCY',
          '${widget.movie['occupancy']}%',
          accentColor,
        ),
        _buildHudTile(
          'DAYS_ACTIVE',
          '${(widget.movie['daily'] as List).length}',
          accentColor,
        ),
        _buildHudTile('REGION_DOMINANCE', 'AP/TG', accentColor),
        _buildHudTile('HYPER_SYNC_LVL', 'CRITICAL', accentColor),
      ],
    );
  }

  Widget _buildHudTile(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.shareTechMono(
              color: Colors.white38,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialRecoveryPainter extends CustomPainter {
  final double value;
  final Color color;
  _RadialRecoveryPainter({required this.value, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 8.0;
    canvas.drawCircle(
      center,
      radius - strokeWidth / 2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    final sweepAngle = 2 * math.pi * (value / 1.5).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CyberTrendPainter extends CustomPainter {
  final List<int> data;
  final Color color;
  _CyberTrendPainter({required this.data, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce(math.max).toDouble();
    final double dx = size.width / (data.length - 1);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final double x = i * dx;
      final double y = size.height - (data[i] / maxVal * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final shadowPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.2), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * (i / 3)),
        Offset(size.width, size.height * (i / 3)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.03)
          ..strokeWidth = 1,
      );
    }
    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(
        Offset(i * dx, size.height - (data[i] / maxVal * size.height)),
        3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CyberBackgroundPainter extends CustomPainter {
  final Color color;
  _CyberBackgroundPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    for (int i = 0; i < 50; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        random.nextDouble() * 2,
        Paint()..color = color,
      );
    }
    for (int i = 0; i < 10; i++) {
      final y = random.nextDouble() * size.height;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = color.withValues(alpha: 0.1)
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

