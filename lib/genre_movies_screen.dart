import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_info_screen.dart';
import 'utils.dart';
import 'services/http_cache_service.dart';
import 'widgets/shimmer_loader.dart';
import 'widgets/screen_state_mixin.dart';

// ─── 

// Section titles per genre
Map<String, List<String>> _genreSections = {
  "Action": [
    "🔥 Blockbuster Hits",
    "💥 Mass Entertainers",
    "⚔️ Classic Action",
  ],
  "Comedy": ["😂 Laugh Riots", "🎭 Comedy-Drama Gems", "🤣 Fan Favorites"],
  "Drama": ["🏆 Award Winners", "💎 Hidden Gems", "🎬 Must Watch Dramas"],
  "Romance": [
    "❤️ Iconic Love Stories",
    "💕 Feel-Good Romance",
    "🌹 Classic Telugu Romance",
  ],
  "Horror": [
    "👻 Spine-Chilling Hits",
    "🎃 Horror Comedy",
    "💀 Supernatural Thrillers",
  ],
  "Thriller": [
    "🔍 Mind-Bending Thrillers",
    "🕵️ Crime Thrillers",
    "🎯 Spy & Action Thrillers",
  ],
  "Sci-Fi": [
    "🚀 Futuristic Epics",
    "⚡ Sci-Fi Classics",
    "🌌 Visual Spectacles",
  ],
};

// Sub-genre chips
Map<String, List<String>> _subGenres = {
  "Action": ["All", "Mass", "Martial Arts", "War", "Spy"],
  "Comedy": ["All", "Slapstick", "Dark Comedy", "Satire", "Rom-Com"],
  "Drama": ["All", "Family", "Social", "Period", "Biopic"],
  "Romance": ["All", "Love Story", "Rom-Com", "Tragic", "Musical"],
  "Horror": ["All", "Supernatural", "Horror-Comedy", "Psychological", "Gothic"],
  "Thriller": ["All", "Crime", "Mystery", "Spy", "Psychological"],
  "Sci-Fi": ["All", "Time Travel", "Dystopian", "Mythology", "Space"],
};

// ─── Main Screen ─────────────────────────────────────────────────────────────
class GenreMoviesScreen extends StatefulWidget {
  final String genreName;
  final Color genreColor;
  final VoidCallback? onBackPressed;

  const GenreMoviesScreen({
    super.key,
    required this.genreName,
    required this.genreColor,
    this.onBackPressed,
  });

  @override
  State<GenreMoviesScreen> createState() => _GenreMoviesScreenState();
}

class _GenreMoviesScreenState extends State<GenreMoviesScreen>
    with ScreenStateMixin {
  int _selectedChipIndex = 0;
  List<Map<String, dynamic>> _movies = [];
  List<Map<String, dynamic>> _cachedSortedMovies = [];

  @override
  void initState() {
    super.initState();
    _fetchGenreMovies();
  }

  Future<void> _fetchGenreMovies() async {
    await handleApiState(
      cacheKey: 'genre_movies_${widget.genreName}',
      fetchData: () => HttpCacheService.get(
        Uri.parse('$baseUrl/api/genre-movies?genre=${widget.genreName}') ),
      onDataParsed: (data) {
        if (data is List) {
          _movies = List<Map<String, dynamic>>.from(data);
        }
      } );
  }

  List<Map<String, dynamic>> _getMovies() {
    return _movies;
  }

  List<String> _getSections() {
    return _genreSections[widget.genreName] ??
        ["🎬 Top Picks", "💎 Hidden Gems", "🔥 Trending"];
  }

  List<String> _getSubGenres() {
    return _subGenres[widget.genreName] ?? ["All", "Popular", "New", "Classic"];
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: const Color(0xFF080A10),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: widget.genreColor.withValues(alpha: 0.5)) ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 15) ),
        onPressed: () {
          if (widget.onBackPressed != null) {
            widget.onBackPressed!();
          } else {
            Navigator.pop(context);
          }
        } ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.genreColor.withValues(alpha: 0.3),
                const Color(0xFF080A10),
              ] ) ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GridPainter(color: widget.genreColor.withValues(alpha: 0.3)))),
              Positioned(
                left: 20, bottom: 18, right: 20,
                child: Text(
                  widget.genreName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800 ) ) ),
            ] ) ) ) );
  }

  // Filter movies based on selected sub-genre chip
  List<Map<String, dynamic>> _filterMovies(List<Map<String, dynamic>> movies) {
    if (_selectedChipIndex == 0) return movies; // "All" selected
    final subGenres = _getSubGenres();
    if (_selectedChipIndex >= subGenres.length) return movies;
    final selectedSubGenre = subGenres[_selectedChipIndex];
    return movies.where((movie) {
      final movieSubGenres = movie['subGenre'] as List<dynamic>?;
      if (movieSubGenres == null) return false;
      return movieSubGenres.any(
        (sg) => sg.toString().toLowerCase() == selectedSubGenre.toLowerCase() );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: buildScreenState(
        onRetry: _fetchGenreMovies,
        buildLoading: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverFillRemaining(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, _) => const MovieCardSkeleton() ) ),
          ] ),
        buildSuccess: () {
          final allMovies = _getMovies();
          final filteredMovies = _filterMovies(allMovies);
          _cachedSortedMovies = List.from(filteredMovies)
            ..sort((a, b) {
              final rA = double.tryParse(a['rating']?.toString() ?? '0') ?? 0.0;
              final rB = double.tryParse(b['rating']?.toString() ?? '0') ?? 0.0;
              return rB.compareTo(rA);
            });
          final sections = _getSections();

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              // Sub-genre filter chips
              SliverToBoxAdapter(child: _buildSubGenreChips()),
              if (filteredMovies.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.movie_filter_outlined,
                          size: 60,
                          color: widget.genreColor.withValues(alpha: 0.4) ),
                        const SizedBox(height: 16),
                        Text(
                          "No movies found for this filter",
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 16 ) ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() => _selectedChipIndex = 0),
                          child: Text(
                            "Show All",
                            style: GoogleFonts.outfit(
                              color: widget.genreColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold ) ) ),
                      ] ) ) )
              else ...[
                // Featured Hero Banner
                SliverToBoxAdapter(
                  child: _buildFeaturedBanner(filteredMovies.first) ),
                // Genre Statistics Chart
                SliverToBoxAdapter(
                  child: _GenreStatisticsChart(
                    movies: filteredMovies,
                    accentColor: widget.genreColor,
                    genreName: widget.genreName ) ),
                // Movie sections
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= sections.length) return const SizedBox(height: 50);
                      return _buildMovieSection(
                        sections[index],
                        _getMoviesForSection(filteredMovies, index) );
                    },
                    childCount: sections.length + 1 ) ),
              ],
            ] );
        } ) );
  }

  List<Map<String, dynamic>> _getMoviesForSection(
    List<Map<String, dynamic>> allMovies,
    int sectionIndex ) {
    if (_cachedSortedMovies.isEmpty) return [];

    final sectionsCount = _getSections().length;
    if (sectionsCount == 0) return _cachedSortedMovies;

    final moviesPerSection = (_cachedSortedMovies.length / sectionsCount).ceil();
    final start = sectionIndex * moviesPerSection;

    if (start >= _cachedSortedMovies.length) return [];

    final end = (start + moviesPerSection).clamp(0, _cachedSortedMovies.length);
    return _cachedSortedMovies.sublist(start, end);
  }

  Widget _buildSubGenreChips() {
    final chips = _getSubGenres();
    return SizedBox(
      height: 54,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedChipIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedChipIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          widget.genreColor,
                          widget.genreColor.withValues(alpha: 0.6),
                        ] )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: isSelected
                      ? widget.genreColor
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1 ) ),
              child: Center(
                child: Text(
                  chips[index],
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500 ) ) ) ) );
        } ) );
  }

  Widget _buildFeaturedBanner(Map<String, dynamic> movie) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieInfoScreen(movie: movie, isGenreMovie: true) ) ),
      child: Container(
        height: 220,
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.genreColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8) ),
          ] ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: movie['image'] ?? '',
                fit: BoxFit.cover, 
                errorWidget: (_, _, _) =>
                    Container(color: const Color(0xFF13151A)) ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.genreColor.withValues(alpha: 0.4),
                      const Color(0xFF0F1014),
                    ] ) ) ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(
                  painter: _GridPainter(color: widget.genreColor) ) ) ),
            Positioned(
              right: -30,
              bottom: -20,
              child: Icon(
                Icons.movie_filter_rounded,
                size: 180,
                color: widget.genreColor.withValues(alpha: 0.2) ) ),
          ] ) ) ) );
}

  Widget _buildMovieSection(String title, List<Map<String, dynamic>> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Row(
            children: [
              Container(width: 4, height: 20, color: widget.genreColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15 ) ) ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _SeeAllMoviesScreen(
                        sectionTitle: title,
                        movies: movies,
                        accentColor: widget.genreColor ) ) );
                },
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white38,
                  size: 14 ) ),
            ] ) ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, index) => _MovieThumbnailCard(
              movie: movies[index],
              accentColor: widget.genreColor ) ) ),
        const SizedBox(height: 10),
      ] );
  }
}

// ─── Genre Statistics Chart ───────────────────────────────────────────────────
class _GenreStatisticsChart extends StatefulWidget {
  final List<Map<String, dynamic>> movies;
  final Color accentColor;
  final String genreName;

  const _GenreStatisticsChart({
    required this.movies,
    required this.accentColor,
    required this.genreName,
  });

  @override
  State<_GenreStatisticsChart> createState() => _GenreStatisticsChartState();
}

class _GenreStatisticsChartState extends State<_GenreStatisticsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _growAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900) );
    _growAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic );
    // Small delay then animate in
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Build rating buckets: 1-4, 5-6, 7-8, 9-10
  List<_RatingBucket> _buildBuckets() {
    final List<_RatingBucket> buckets = [
      _RatingBucket(label: '1–4', count: 0, color: Colors.redAccent),
      _RatingBucket(label: '5–6', count: 0, color: Colors.orangeAccent),
      _RatingBucket(label: '7–8', count: 0, color: Colors.amber),
      _RatingBucket(label: '9–10', count: 0, color: Colors.greenAccent),
    ];
    for (final movie in widget.movies) {
      final r = double.tryParse(movie['rating']?.toString() ?? '0') ?? 0.0;
      if (r < 5) {
        buckets[0].count++;
      } else if (r < 7) {
        buckets[1].count++;
      } else if (r < 9) {
        buckets[2].count++;
      } else {
        buckets[3].count++;
      }
    }
    return buckets;
  }

  double _avgRating() {
    if (widget.movies.isEmpty) return 0.0;
    double sum = 0;
    for (final m in widget.movies) {
      sum += double.tryParse(m['rating']?.toString() ?? '0') ?? 0.0;
    }
    return sum / widget.movies.length;
  }

  String _topRated() {
    if (widget.movies.isEmpty) return 'N/A';
    Map<String, dynamic> top = widget.movies.first;
    for (final m in widget.movies) {
      final a = double.tryParse(m['rating']?.toString() ?? '0') ?? 0.0;
      final b = double.tryParse(top['rating']?.toString() ?? '0') ?? 0.0;
      if (a > b) top = m;
    }
    return top['title'] ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBuckets();
    final maxCount = buckets.map((b) => b.count).reduce(math.max).toDouble();
    final avg = _avgRating();
    final topRatedTitle = _topRated();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.accentColor.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.04),
          ] ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)) ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: widget.accentColor,
                size: 22 ),
              const SizedBox(width: 8),
              Text(
                'GENRE STATISTICS',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2 ) ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8) ),
                child: Text(
                  '${widget.movies.length} movies',
                  style: GoogleFonts.outfit(
                    color: widget.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600 ) ) ),
            ] ),
          const SizedBox(height: 16),

          // Quick stats row
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  '⭐ Avg Rating',
                  avg.toStringAsFixed(1),
                  Colors.amber ) ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildQuickStat(
                  '🏆 Top Rated',
                  topRatedTitle,
                  widget.accentColor,
                  small: true ) ),
            ] ),
          const SizedBox(height: 18),

          // Chart title
          Text(
            'Rating Distribution',
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8 ) ),
          const SizedBox(height: 12),

          // Bar chart
          AnimatedBuilder(
            animation: _growAnim,
            builder: (context, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: buckets.map((bucket) {
                  final barFraction = maxCount > 0
                      ? (bucket.count / maxCount) * _growAnim.value
                      : 0.0;
                  final barH = 80.0 * barFraction + (bucket.count > 0 ? 6 : 0);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Count label
                          if (bucket.count > 0)
                            Text(
                              '${bucket.count}',
                              style: GoogleFonts.outfit(
                                color: bucket.color,
                                fontSize: 13,
                                fontWeight: FontWeight.bold ) ),
                          const SizedBox(height: 4),
                          // Bar
                          Container(
                            height: barH > 0 ? barH : 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  bucket.color.withValues(alpha: 0.6),
                                  bucket.color,
                                ] ),
                              borderRadius: BorderRadius.circular(6) ) ),
                          const SizedBox(height: 6),
                          // Label
                          Text(
                            bucket.label,
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 11 ) ),
                        ] ) ) );
                }).toList() );
            } ),
        ] ) );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    Color valueColor, {
    bool small = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10) ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600 ) ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: valueColor,
              fontSize: small ? 13 : 20,
              fontWeight: FontWeight.bold ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis ),
        ] ) );
  }
}

class _RatingBucket {
  final String label;
  int count;
  final Color color;
  _RatingBucket({
    required this.label,
    required this.count,
    required this.color,
  });
}

// ─── Enhanced Movie Card (with Like Button) ────────────────────────────────────
class _MovieThumbnailCard extends StatefulWidget {
  final Map<String, dynamic> movie;
  final Color accentColor;

  const _MovieThumbnailCard({required this.movie, required this.accentColor});

  @override
  State<_MovieThumbnailCard> createState() => _MovieThumbnailCardState();
}

class _MovieThumbnailCardState extends State<_MovieThumbnailCard>
    with TickerProviderStateMixin {
  // ── Press-scale animation ──────────────────────────────────────────
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  // ── Glow border animation on tap ──────────────────────────────────
  late AnimationController _glowCtrl;
  late Animation<double> _glowOpacity;

  // ── Burst tap effect ───────────────────────────────────────────────
  late AnimationController _effectCtrl;
  Offset _localTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();

    // Press scale (fast squeeze + spring back)
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 280) );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: 0.93 ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn));

    // Burst effect controller (plays on tap, then navigates)
    _effectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380) );

    // Glow border flash
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500) );
    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _glowCtrl.dispose();
    _effectCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressCtrl.reverse();
    _glowCtrl.forward(from: 0);
    // Record the local tap position for the burst painter
    _localTapPosition = details.localPosition;
    _effectCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, _) =>
              MovieInfoScreen(movie: widget.movie, isGenreMovie: true),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut) ),
                child: child ) );
          },
          transitionDuration: const Duration(milliseconds: 280) ) );
    });
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressCtrl, _glowCtrl, _effectCtrl]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pressScale.value,
            child: Container(
              width: 145,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Color.lerp(
                    Colors.white12,
                    const Color(0xFF00F0FF),
                    _glowOpacity.value )!,
                  width: 1 + _glowOpacity.value * 1.5 ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5) ),
                  if (_glowOpacity.value > 0.01)
                    BoxShadow(
                      color: const Color(
                        0xFF00F0FF ).withValues(alpha: _glowOpacity.value * 0.55),
                      blurRadius: 18,
                      spreadRadius: 2 ),
                ] ),
              child: child ) );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              CachedNetworkImage(
                imageUrl: widget.movie['image'] ?? '',
                fit: BoxFit.cover, 
                placeholder: (_, _) => Container(
                  color: const Color(0xFF13151A),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: widget.accentColor,
                      strokeWidth: 2 ) ) ),
                errorWidget: (_, _, _) => Container(
                  color: const Color(0xFF13151A),
                  child: const Icon(Icons.broken_image, color: Colors.white24) ) ),
              // Bottom gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.38, 1.0] ) ) ),
              // Title & Year at bottom
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie['title'] ?? '',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13 ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis ),
                    if (widget.movie['year'] != null)
                      Text(
                        widget.movie['year'],
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 11 ) ),
                  ] ) ),
              // Rating badge (top right)
              if (widget.movie['rating'] != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3 ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.6)) ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 11 ),
                        const SizedBox(width: 2),
                        Text(
                          widget.movie['rating'],
                          style: GoogleFonts.outfit(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold ) ),
                      ] ) ) ),
              // Genre tag (top left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2 ),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4) ),
                  child: Text(
                    'TELUGU',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold ) ) ) ),
              // Burst effect overlay (CustomPaint on top of everything)
              if (_effectCtrl.isAnimating || _effectCtrl.value > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CardBurstPainter(
                      progress: _effectCtrl.value,
                      tapOffset: _localTapPosition,
                      color: widget.accentColor ) ) ),
            ] ) ) ) );
  }
}

// ─── Burst tap effect painter ─────────────────────────────────────────────
// Draws:
//  1. A bright white flash that fades quickly
//  2. An expanding ring from the tap point
//  3. 8 spark dots radiating outward
class _CardBurstPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Offset tapOffset; // local tap position
  final Color color; // accent color for sparks

  _CardBurstPainter({
    required this.progress,
    required this.tapOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. White flash (fast: fades in first 30% of animation)
    final flashOpacity = (1.0 - (progress / 0.3).clamp(0.0, 1.0)) * 0.45;
    if (flashOpacity > 0) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashOpacity);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), flashPaint);
    }

    // 2. Expanding ring from tap point
    final maxRadius = size.longestSide * 1.1;
    final ringRadius = progress * maxRadius;
    final ringOpacity = (1.0 - progress).clamp(0.0, 1.0);
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: ringOpacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 - progress) * 3 + 1;
    canvas.drawCircle(tapOffset, ringRadius, ringPaint);

    // Accent-colored secondary ring (slightly delayed)
    if (progress > 0.15) {
      final p2 = ((progress - 0.15) / 0.85).clamp(0.0, 1.0);
      final ring2Radius = p2 * maxRadius * 0.8;
      final ring2Opacity = (1.0 - p2).clamp(0.0, 1.0);
      final ring2Paint = Paint()
        ..color = color.withValues(alpha: ring2Opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 - p2) * 2 + 0.5;
      canvas.drawCircle(tapOffset, ring2Radius, ring2Paint);
    }

    // 3. Eight spark dots radiating outward
    const sparkCount = 8;
    final sparkOpacity = (1.0 - progress).clamp(0.0, 1.0);
    final sparkPaint = Paint()
      ..color = color.withValues(alpha: sparkOpacity * 0.9)
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: sparkOpacity * 0.9)
      ..style = PaintingStyle.fill;
    final sparkDist = progress * 60;
    for (int i = 0; i < sparkCount; i++) {
      final angle = (i / sparkCount) * 3.14159265 * 2;
      final dx = tapOffset.dx + sparkDist * (0.9 + 0.1 * (i % 2)) * _cos(angle);
      final dy = tapOffset.dy + sparkDist * (0.9 + 0.1 * (i % 2)) * _sin(angle);
      final sparkRadius = (1.0 - progress) * 4.0 + 1.0;
      canvas.drawCircle(
        Offset(dx, dy),
        sparkRadius,
        i.isEven ? sparkPaint : whitePaint );
    }
  }

  double _cos(double radians) => math.cos(radians);
  double _sin(double radians) => math.sin(radians);

  @override
  bool shouldRepaint(_CardBurstPainter old) =>
      old.progress != progress || old.tapOffset != tapOffset;
}

// ─── See All Movies Screen (Grid View) ───────────────────────────────────────
class _SeeAllMoviesScreen extends StatelessWidget {
  final String sectionTitle;
  final List<Map<String, dynamic>> movies;
  final Color accentColor;

  const _SeeAllMoviesScreen({
    required this.sectionTitle,
    required this.movies,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1014),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white ),
          onPressed: () => Navigator.pop(context) ),
        title: Text(
          sectionTitle.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18 ) ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accentColor.withValues(alpha: 0.5),
                  Colors.transparent,
                ] ) ) ) ) ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14 ),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieInfoScreen(movie: movie) ) ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4) ),
                        ] ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: movie['image'] ?? '',
                              fit: BoxFit.cover, 
                              placeholder: (_, _) => Container(
                                color: const Color(0xFF13151A),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: accentColor,
                                    strokeWidth: 2 ) ) ),
                              errorWidget: (_, _, _) => Container(
                                color: const Color(0xFF13151A),
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24 ) ) ),
                            // Rating badge
                            if (movie['rating'] != null)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2 ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.5) ) ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 10 ),
                                      const SizedBox(width: 2),
                                      Text(
                                        movie['rating'],
                                        style: GoogleFonts.outfit(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold ) ),
                                    ] ) ) ),
                          ] ) ) ) ),
                  const SizedBox(height: 6),
                  Text(
                    movie['title'] ?? '',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600 ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis ),
                  if (movie['year'] != null)
                    Text(
                      movie['year'],
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 10 ) ),
                ] ) );
          } ) ) );
  }
}

// ─── Grid Painter ────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const double step = 30.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


