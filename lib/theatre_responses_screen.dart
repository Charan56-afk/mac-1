import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'utils.dart';
import 'services/http_cache_service.dart';

/// Displays a feed of user reactions to movies currently in theatres.
///
/// This screen presents a list of user reviews, ratings, and video responses
/// for various movies. It features a modern, dark-themed UI with
/// movie-specific color accents.
class TheatreResponsesScreen extends StatefulWidget {
  const TheatreResponsesScreen({super.key});

  @override
  State<TheatreResponsesScreen> createState() => _TheatreResponsesScreenState();
}

class _TheatreResponsesScreenState extends State<TheatreResponsesScreen> {
  List<Map<String, dynamic>> _responses = [];
  bool _isLoading = true;

  String _searchQuery = "";
  String _selectedFilter = "All";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchResponses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredResponses {
    return _responses.where((res) {
      // 1. Search Query Filter
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          res['movie'].toString().toLowerCase().contains(q) ||
          res['theatre'].toString().toLowerCase().contains(q) ||
          res['city'].toString().toLowerCase().contains(q) ||
          res['response'].toString().toLowerCase().contains(q);

      if (!matchesSearch) return false;

      // 2. Category Filter
      if (_selectedFilter == "Top Rated") {
        final double rating = (res['rating'] as num).toDouble();
        if (rating < 4.5) return false;
      } else if (_selectedFilter == "Housefull") {
        final c = res['crowd'].toString().toLowerCase();
        final isHousefull = c.contains('houseful') || c.contains('packed') || c.contains('sold');
        if (!isHousefull) return false;
      } else if (_selectedFilter == "With Videos") {
        final List v = res['videos'] as List? ?? [];
        if (v.isEmpty) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _fetchResponses() async {
    try {
      final response = await HttpCacheService.get(
        Uri.parse('$baseUrl/api/theatre-responses'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _responses = data.map((jsonItem) {
              Color colorVal = const Color(0xFFFF0055); // Default
              if (jsonItem['color'] != null) {
                try {
                  colorVal = Color(int.parse(jsonItem['color'].toString()));
                } catch (e) {
                  // Ignore format parsing issue and use default
                }
              }

              return {
                'movie': jsonItem['movie'] ?? '',
                'theatre': jsonItem['theatre'] ?? '',
                'city': jsonItem['city'] ?? '',
                'response': jsonItem['response'] ?? '',
                'rating': jsonItem['rating'] ?? 0.0,
                'crowd': jsonItem['crowd'] ?? '',
                'emoji': jsonItem['emoji'] ?? 'Ã°Å¸Â Â¿',
                'color': colorVal,
                'time': jsonItem['time'] ?? 'Just now',
                'videos': jsonItem['videos'] ?? [],
              };
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredResponses;

    return Scaffold(
      backgroundColor: const Color(0xFF06040E),
      body: CustomScrollView(
        slivers: [
          // ─── Cinematic App Bar ───
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: const Color(0xFF06040E),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(color: const Color(0xFF9D00FF).withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 15),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0040), Color(0xFF06040E)],
                  ),
                ),
                child: Stack(
                  children: [
                    // BG grid lines
                    Positioned.fill(
                      child: CustomPaint(painter: _GridPainter()),
                    ),
                    Positioned(
                      left: 20, bottom: 18, right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _LivePulse(),
                              const SizedBox(width: 10),
                              Text('LIVE FROM THEATRES', style: GoogleFonts.outfit(
                                color: const Color(0xFF00F0FF), fontSize: 11,
                                fontWeight: FontWeight.w800, letterSpacing: 2,
                              )),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [Color(0xFFFF0055), Color(0xFF9D00FF), Color(0xFF00F0FF)],
                            ).createShader(b),
                            child: Text('THEATRE RESPONSES', style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 26,
                              fontWeight: FontWeight.w900, letterSpacing: 1.5,
                            )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.5),
              child: Container(
                height: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFF0055), Color(0xFF9D00FF), Color(0xFF00F0FF)]),
                ),
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF9D00FF))),
            )
          else ...[
            _buildSearchAndFilterBar(),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, color: const Color(0xFF00F0FF).withValues(alpha: 0.4), size: 48),
                      const SizedBox(height: 14),
                      Text(
                        'No matching responses found.',
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try relaxing your search query or filter categories.',
                        style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 50),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildResponseCard(filtered[i], i),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            // Cyber Search Field
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.05),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search movie, theatre, city...',
                  hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00F0FF), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = "";
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Filter Pills Row
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterPill("All", Icons.interests_rounded, const Color(0xFF9D00FF)),
                  _filterPill("Top Rated", Icons.star_rounded, const Color(0xFFFFCC00)),
                  _filterPill("Housefull", Icons.people_alt_rounded, const Color(0xFF00F0FF)),
                  _filterPill("With Videos", Icons.videocam_rounded, const Color(0xFFFF0055)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String name, IconData icon, Color accent) {
    final isSelected = _selectedFilter == name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = name;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: isSelected ? accent : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: -2,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? accent : Colors.white60,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseCard(Map<String, dynamic> response, int index) {
    final Color accentColor = response['color'] as Color;
    final double rating = (response['rating'] as num).toDouble();
    final List videos = response['videos'] as List? ?? [];

    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => TheatreResponseDetailScreen(response: response))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.12),
              const Color(0xFF0A0812),
              accentColor.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: accentColor.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [
            BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: -4, offset: const Offset(0, 12)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Holographic header band ───
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withValues(alpha: 0.3), accentColor.withValues(alpha: 0.05), Colors.transparent],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                ),
                child: Row(children: [
                  // Rating arc avatar
                  SizedBox(width: 62, height: 62,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(size: const Size(62, 62),
                        painter: _RatingArcPainter(rating / 5.0, accentColor)),
                      Text(response['emoji'],
                        style: const TextStyle(fontSize: 24), textAlign: TextAlign.center),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(response['movie'],
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: accentColor.withValues(alpha: 0.7), blurRadius: 10)]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.theaters_rounded, color: accentColor, size: 12),
                      const SizedBox(width: 4),
                      Expanded(child: Text(response['theatre'],
                        style: GoogleFonts.outfit(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.location_on_rounded, color: Colors.white38, size: 11),
                      const SizedBox(width: 3),
                      Text('${response['city']}  •  ${response['time']}',
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                    ]),
                  ])),
                  // Rating badge
                  Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: accentColor.withValues(alpha: 0.2),
                        border: Border.all(color: accentColor.withValues(alpha: 0.6)),
                        boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 10)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded, color: accentColor, size: 14),
                        const SizedBox(width: 3),
                        Text('$rating', style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Icon(Icons.arrow_forward_ios_rounded, color: accentColor.withValues(alpha: 0.7), size: 13),
                  ]),
                ]),
              ),

              // ─── Quote bubble ───
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('"', style: GoogleFonts.outfit(color: accentColor, fontSize: 28, fontWeight: FontWeight.w900, height: 0.9)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(response['response'],
                    style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, height: 1.55),
                    maxLines: 3, overflow: TextOverflow.ellipsis)),
                ]),
              ),

              // ─── Crowd heatbar ───
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.people_alt_rounded, color: const Color(0xFF00F0FF), size: 12),
                    const SizedBox(width: 5),
                    Text('CROWD  ', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
                    Text(response['crowd'], style: GoogleFonts.outfit(color: const Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(height: 4, width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(
                        widthFactor: _crowdFactor(response['crowd']),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFF9D00FF)]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              // ─── Video strip ───
              if (videos.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    itemCount: videos.length,
                    itemBuilder: (_, i) {
                      final v = videos[i];
                      return Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.2),
                          boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 8)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(imageUrl: v['thumbnail'] ?? '', fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(color: const Color(0xFF1A1A2E),
                                child: Icon(Icons.videocam_rounded, color: accentColor.withValues(alpha: 0.4), size: 24))),
                            Container(decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)]))),
                            Center(child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withValues(alpha: 0.9),
                                boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.6), blurRadius: 10)]),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16))),
                            Positioned(bottom: 4, right: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                child: Text(v['duration'] ?? '', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),

              if (videos.isNotEmpty) const SizedBox(height: 12),

              // ─── Footer ───
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: accentColor.withValues(alpha: 0.15))),
                ),
                child: Row(children: [
                  Icon(Icons.videocam_rounded, color: const Color(0xFFFF0055), size: 13),
                  const SizedBox(width: 5),
                  Text('${videos.length} videos', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Tap to explore →', style: GoogleFonts.outfit(color: accentColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _crowdFactor(String crowd) {
    final c = crowd.toLowerCase();
    if (c.contains('houseful') || c.contains('packed') || c.contains('sold')) return 1.0;
    if (c.contains('full') || c.contains('crowd')) return 0.85;
    if (c.contains('moderate') || c.contains('medium')) return 0.55;
    if (c.contains('low') || c.contains('sparse')) return 0.3;
    return 0.65;
  }
}

// ─── Animated LIVE pulse dot ───
class _LivePulse extends StatefulWidget {
  @override
  State<_LivePulse> createState() => _LivePulseState();
}
class _LivePulseState extends State<_LivePulse> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(const Color(0xFF00F0FF), Colors.white, 1 - _anim.value),
        boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withValues(alpha: _anim.value * 0.8), blurRadius: 8, spreadRadius: 2)],
      ),
    ),
  );
}

// ─── Grid background painter ───
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9D00FF).withValues(alpha: 0.07)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ─── Rating arc painter ───
class _RatingArcPainter extends CustomPainter {
  final double fraction;
  final Color color;
  const _RatingArcPainter(this.fraction, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2; final r = size.width / 2 - 4;
    final track = Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    final arc = Paint()..shader = SweepGradient(colors: [color, color.withValues(alpha: 0.4)], startAngle: -math.pi / 2, endAngle: 3 * math.pi / 2).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -math.pi / 2, 2 * math.pi, false, track);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -math.pi / 2, 2 * math.pi * fraction.clamp(0, 1), false, arc);
  }
  @override bool shouldRepaint(_) => false;
}



// ===========================
// DETAIL SCREEN
// ===========================
/// A detailed view for a specific theatre response.
///
/// Shows full response, stats, and video list with premium cinematic styling.
class TheatreResponseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> response;

  const TheatreResponseDetailScreen({super.key, required this.response});

  Future<void> _openVideo(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = response['color'] as Color;
    final List videos = response['videos'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF06040E),
      body: CustomScrollView(
        slivers: [
          // ─── Cinematic App Bar ───
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF06040E),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 15),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentColor.withValues(alpha: 0.15), const Color(0xFF06040E)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                    // Large glowing emoji
                    Positioned(
                      right: 10,
                      top: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140, height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 60)],
                            ),
                          ),
                          Text(response['emoji'], style: const TextStyle(fontSize: 120)),
                        ],
                      ),
                    ),
                    // Content
                    Positioned(
                      left: 20,
                      bottom: 24,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            response['movie'],
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              shadows: [Shadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 15)],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.theaters_rounded, color: accentColor, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  response['theatre'],
                                  style: GoogleFonts.outfit(color: accentColor, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: Colors.white54, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${response['city']}  •  ${response['time']}',
                                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.5),
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.1)]),
                ),
              ),
            ),
          ),

          // ─── Stats Row ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
              child: Row(
                children: [
                  _statChip(Icons.star_rounded, '${response['rating']} RATING', accentColor, true),
                  const SizedBox(width: 12),
                  _statChip(Icons.people_alt_rounded, '${response['crowd']} CROWD'.toUpperCase(), const Color(0xFF00F0FF), false),
                  const SizedBox(width: 12),
                  _statChip(Icons.videocam_rounded, '${videos.length} VIDEOS', const Color(0xFFFF0055), false),
                ],
              ),
            ),
          ),

          // ─── Response Quote Bubble ───
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.05), blurRadius: 20)],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"', style: GoogleFonts.outfit(color: accentColor, fontSize: 40, fontWeight: FontWeight.w900, height: 0.8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      response['response'],
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Videos Section Header ───
          if (videos.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.5), blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'THEATRE VIDEOS',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Video Cards ───
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return _buildVideoCard(context, videos[index], accentColor);
            }, childCount: videos.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color, bool filled) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: filled ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: color.withValues(alpha: filled ? 0.6 : 0.2), width: filled ? 1.5 : 1),
          boxShadow: filled ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: -2)] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(color: filled ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> video, Color accentColor) {
    return GestureDetector(
      onTap: () => _openVideo(context, video['url']),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [accentColor.withValues(alpha: 0.1), const Color(0xFF0A0812)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: video['thumbnail'] ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(color: const Color(0xFF1A1A2E), child: Icon(Icons.videocam_rounded, color: accentColor.withValues(alpha: 0.3), size: 50)),
                    ),
                  ),
                  Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)])))),
                  Positioned.fill(child: Center(child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withValues(alpha: 0.9), boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.6), blurRadius: 20)]), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)))),
                  Positioned(bottom: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)), child: Text(video['duration'] ?? '', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video['title'] ?? '', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(video['views'] ?? '', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withValues(alpha: 0.15), border: Border.all(color: accentColor.withValues(alpha: 0.4))),
                    child: Icon(Icons.open_in_new_rounded, color: accentColor, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
