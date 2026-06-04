import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_application_1/utils.dart';
import 'services/app_settings.dart';
import 'package:flutter_application_1/widgets/movie_post_card.dart';
import 'package:flutter_application_1/hero_movie_info_screen.dart';
import 'package:flutter_application_1/box_office_detail_screen.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

import 'package:flutter_application_1/cinema_feed_screen.dart';
import 'package:flutter_application_1/genre_movies_screen.dart';
import 'package:flutter_application_1/widgets/prismatic_glass_buzz_tile.dart';
import 'package:flutter_application_1/all_reviews_screen.dart';
import 'package:flutter_application_1/directors_cut_screen.dart';
import 'package:flutter_application_1/widgets/shimmer_loader.dart';
import 'package:flutter_application_1/constants.dart';
import 'package:flutter_application_1/widgets/screen_state_mixin.dart';

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  /// Set to true from MainScreen the instant a tab swipe starts.
  /// _HeroSlideState listens and immediately pauses video decoding.
  static final ValueNotifier<bool> pauseVideo = ValueNotifier(false);

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2>
    with ScreenStateMixin<HomeScreenV2>, AutomaticKeepAliveClientMixin<HomeScreenV2> {
  List posts = [];
  final String currentUserId = "Mobile_User_1";
  List<Map<String, dynamic>> _featured = [];
  List buzz = [];
  @override
  bool get wantKeepAlive => true; // keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  // Lightweight re-fetch of only the buzz list
  Future<void> _refreshBuzz() async {
    try {
      final res = await http
          .get(Uri.parse(AppConstants.industryBuzz))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          buzz = json.decode(res.body);
        });
      }
    } catch (_) {
      /* silently fail */
    }
  }

  Future<void> fetchAllData() async {
    await handleApiState(
      cacheKey: 'home_screen_v2_combined_data',
      fetchData: () async {
        debugPrint("Starting parallel fetch for Home screen...");
        // Paginate: only fetch the 10 most recent reviews for the home screen
        final paginatedReviews = '${AppConstants.reviews}?page=1&limit=10';
        final endpoints = [
          paginatedReviews,
          AppConstants.hub,
          AppConstants.movies,
          AppConstants.industryBuzz,
        ];

        final futureResponses = endpoints.map((url) async {
          try {
            debugPrint("Fetching: $url");
            final r = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 6));
            debugPrint("Success [$url]: Status ${r.statusCode}");
            return r;
          } catch (e) {
            debugPrint("Failed [$url]: $e");
            rethrow;
          }
        }).toList();

        final responses = await Future.wait(futureResponses);

        // If core endpoints fail, let the mixin handle the error
        if (responses[0].statusCode >= 400 || responses[2].statusCode >= 400) {
          final failed = [
            responses[0],
            responses[2],
          ].firstWhere((r) => r.statusCode >= 400);
          return failed;
        }

        // Combine responses
        final combinedBody = {
          'reviews': responses[0].statusCode == 200
              ? jsonDecode(responses[0].body)
              : [],
          'hub': responses[1].statusCode == 200
              ? jsonDecode(responses[1].body)
              : {},
          'movies': responses[2].statusCode == 200
              ? jsonDecode(responses[2].body)
              : [],
          'buzz': responses[3].statusCode == 200
              ? jsonDecode(responses[3].body)
              : [],
        };

        return combinedBody;
      },
      onDataParsed: (decodedData) {
        if (decodedData is Map<String, dynamic>) {
          posts = decodedData['reviews'] ?? [];
          buzz = decodedData['buzz'] ?? [];

          final List mData = decodedData['movies'] ?? [];
          if (mData.isNotEmpty) {
            _featured = mData.map((e) => Map<String, dynamic>.from(e)).toList();
          } else {
            _featured = _getMockMovies();
          }
        }
      } );
  }

  // --- MOCK DATA FALLBACK ---
  List<Map<String, dynamic>> _getMockMovies() {
    return [
      {
        "id": "1",
        "title": "Funky",
        "image":
            "https://m.media-amazon.com/images/M/MV5BY2NhMDM5MTktYjYwMS00OTMzLWFmZjgtYjNlMjdhMGQ2N2VmXkEyXkFqcGc@._V1_.jpg",
        "videoUrl": "https://youtu.be/m4hco660Ino?si=LxahgKOkRxcKp5eN",
        "desc": "Anudeep Kv and Vishwak Sen's Comedy Ride.",
        "tags": "Comedy • Drama",
        "rating": "8.1",
        "cast": [
          {
            "name": "Vishwak Sen",
            "role": "Komal",
            "image":
                "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Vishwak_Sen.jpg/220px-Vishwak_Sen.jpg",
          },
          {
            "name": "Kayadu Lohar",
            "role": "Chitra",
            // Intentionally omit image for 'Kayadu Lohar' to show fallback mechanism
          },
        ],
      },
      {
        "id": "2",
        "title": "Couple Friendly",
        "image":
            "https://cdn.district.in/movies-assets/images/cinema/Couple-Friendly_Poster-4b0a2a70-0586-11f1-ac1f-3391dbf045e5.jpg",
        "videoUrl": "https://youtu.be/exz-qgT2n4E?si=UP42i_rEwKSpLVMu",
        "desc": "A romantic comedy film.",
        "tags": "Comedy • Romance",
        "rating": "7.5",
      },
      {
        "id": "3",
        "title": "Seetha Payanam",
        "image":
            "https://cdn.district.in/movies-assets/images/cinema/Seetha-Payanam-gallery-c7477390-14ff-11f0-afe9-91710f201788.jpg",
        "videoUrl": "https://youtu.be/72czhVw48s0?si=ETPT_F9ChbxzMz8j",
        "desc": "A romantic drama film.",
        "tags": "Drama • Romance",
        "rating": "8.3",
      },
      {
        "id": "4",
        "title": "Mana ShankaraVara Prasad Garu",
        "image":
            "https://m.media-amazon.com/images/M/MV5BMTI3NWE5YjEtMmJkZi00OTUzLWI3YzMtMmNmYjEzNzdhMmM3XkEyXkFqcGc@._V1_FMjpg_UX1000_.jpg",
        "videoUrl": "https://youtu.be/A4CbAkPb468?si=9DyDSP96q9Ns7p5O",
        "desc":
            "Shankara Vara Prasad, a national security officer who seeks to protect his estranged wife and children, seeing it as a chance to re-unite with them.",
        "tags": "Comedy • Action",
      },
      {
        "id": "5",
        "title": "The Raja Saab",
        "image":
            "https://m.media-amazon.com/images/M/MV5BOGUyODA1OGUtNDBlMy00NGY2LTk3ZmUtMDQ1MTM1ODU2NzQwXkEyXkFqcGc@._V1_.jpg",
        "videoUrl": "https://youtu.be/i-8w5yDwukA?si=Oe7sX1BFiKX7il5K",
        "desc":
            "A horror-comedy featuring Prabhas in a never-seen-before avatar with supernatural elements.",
        "tags": "Horror • Comedy • Romance • Action",
        "cast": [
          {
            "name": "Prabhas",
            "role": "Raja Saab",
            "image":
                "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/Prabhas_at_Saaho_Pre_Release_Event.jpg/220px-Prabhas_at_Saaho_Pre_Release_Event.jpg",
          },
          {"name": "Malavika Mohanan", "role": "TBA"},
          {"name": "Nidhhi Agerwal", "role": "TBA"},
        ],
      },
    ];
  }

  Widget _buildLoadingSkeletons() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: HeroCarouselSkeleton(height: 420), // Standard hero height
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 15, 20, 15),
            child: ShimmerBox(width: 150, height: 24) ) ),
        SliverToBoxAdapter(
          child: Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: 3,
              itemBuilder: (_, _) => const BuzzTileSkeleton() ) ) ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
            child: ShimmerBox(width: 200, height: 24) ) ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, _) => const FeedCardSkeleton(),
            childCount: 2 ) ),
      ] );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: buildScreenState(
        onRetry: fetchAllData,
        buildLoading: _buildLoadingSkeletons(),
        buildSuccess: () => Stack(
            children: [
              CustomScrollView(
                primary: false,
                cacheExtent: 500,
                slivers: [
                  // 1. CAROUSEL HERO SECTION
                  SliverToBoxAdapter(
                    child: HeroCarouselSection(
                      featuredMovies: _featured,
                      isLoading: false ) ),

                  // 1.5 INDUSTRY BUZZ SECTION
                  if (buzz.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00F0FF),
                                borderRadius: BorderRadius.circular(6) ),
                              child: const Icon(
                                Icons.flash_on,
                                color: Colors.black,
                                size: 16 ) ),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context).industryBuzz,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context ).textTheme.titleLarge?.color ) ),
                          ] ) ) ),
                    SliverToBoxAdapter(
                      child: Container(
                        height: 205, // Capsule height for PrismaticGlassBuzzTile
                        margin: const EdgeInsets.only(bottom: 20),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          cacheExtent: 300,
                          padding: const EdgeInsets.only(left: 20),
                          itemCount: buzz.length,
                          itemBuilder: (context, index) {
                            final item = buzz[index];

                            return RepaintBoundary(
                              child: PrismaticGlassBuzzTile(
                                post: item,
                                onReturnFromDetail: _refreshBuzz ) );
                          } ) ) ),
                  ],

                  // --- BOX OFFICE TRACKER SECTION ---
                  const SliverToBoxAdapter(child: BoxOfficeTrackerSection()),

                  if (posts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.local_movies_outlined,
                              size: 60,
                              color: Colors.white24 ),
                            const SizedBox(height: 10),
                            Text(
                              AppLocalizations.of(context).noContentAvailable,
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 16 ) ),
                          ] ) ) )
                  else ...[
                    // --- OVERRATED & UNDERRATED TELUGU MOVIES ---
                    SliverToBoxAdapter(child: TeluguRatedMoviesSection()),

                    // --- NEW HEADING: NEW MOVIE REVIEWS ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0055),
                                borderRadius: BorderRadius.circular(6) ),
                              child: const Icon(
                                Icons.reviews,
                                color: Colors.black,
                                size: 16 ) ),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context).newMovieReviews,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context ).textTheme.titleLarge?.color ) ),
                          ] ) ) ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 15 ),
                          child: RepaintBoundary(
                            child: MoviePostCard(
                              post: posts[index],
                              currentUserId: currentUserId ) ) );
                      }, childCount: posts.length > 3 ? 3 : posts.length) ),

                    // 2. VIEW ALL BUTTON
                    if (posts.length > 3)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10 ),
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllReviewsScreen() ) );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF00F0FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15) ),
                              padding: const EdgeInsets.symmetric(vertical: 15) ),
                            child: Text(
                              AppLocalizations.of(context).viewAllReviews,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00F0FF),
                                fontSize: 18,
                                fontWeight: FontWeight.bold ) ) ) ) ),
                  ], // close else array
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100), // padding for bottom
                  ),
                ] ),

              // 3. FLOATING TOP BAR (Placeholder)
              Positioned(
                top: 50,
                left: 20,
                child: SizedBox(
                  width: 200,
                  height: 100,
                  // color: Colors.transparent
                ),
              ),
            ] ) ) );
  }
} // End of _HomeScreenV2State

// --- HERO CAROUSEL SECTION ---
class HeroCarouselSection extends StatefulWidget {
  final List<Map<String, dynamic>> featuredMovies;
  final bool isLoading;
  final bool isParentScrolling;

  const HeroCarouselSection({
    super.key,
    required this.featuredMovies,
    this.isLoading = false,
    this.isParentScrolling = false,
  });

  @override
  State<HeroCarouselSection> createState() => _HeroCarouselSectionState();
}

class _HeroCarouselSectionState extends State<HeroCarouselSection> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Wider slide (0.9) with emphasis on the left side
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isScrolling = false;
  int _currentIndex = 0;
  double? _targetAspect;
  
  void _updateAspect(double aspect) {
    if (mounted && _targetAspect != aspect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _targetAspect = aspect;
          });
        }
      });
    }
  }

  String _getGreetingText(BuildContext context) {
    final int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return AppLocalizations.of(context).greetingMorning;
    if (hour >= 12 && hour < 17) return AppLocalizations.of(context).greetingAfternoon;
    if (hour >= 17 && hour < 21) return AppLocalizations.of(context).greetingEvening;
    return AppLocalizations.of(context).greetingNight;
  }

  String _getGreetingEmoji() {
    final int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "🌅"; // Morning
    if (hour >= 12 && hour < 17) return "☀️"; // Afternoon
    if (hour >= 17 && hour < 21) return "🌆"; // Evening
    return "🌙"; // Night
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight ),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withValues(alpha: 0.55),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4) ),
              ] ),
            child: Icon(icon, color: Colors.white, size: size * 0.44) ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight ).createShader(bounds),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0 ) ) ),
        ] ) );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 420,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00F0FF)) ) );
    }

    if (widget.featuredMovies.isEmpty) {
      return Container(
        height: 420,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1), // Increased opacity
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white24,
            width: 1.5 ), // More visible border
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white54,
                size: 50 ),
              const SizedBox(height: 15),
              Text(
                AppLocalizations.of(context).backendNotConnected,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold ) ),
              const SizedBox(height: 5),
              Text(
                AppLocalizations.of(context).startLocalServer,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 14 ) ),
            ] ) ) );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;
    final double defaultAspectRatio = isMobile ? 0.85 : 1.4;
    final double aspectRatio = _targetAspect ?? defaultAspectRatio;

    return Column(
      children: [
        // 0. Top Brand Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _getGreetingEmoji(),
                    style: const TextStyle(fontSize: 18) ),
                  const SizedBox(width: 8),
                  Text(
                    _getGreetingText(context),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5 ) ),
                ] ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6 ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0055).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF0055).withValues(alpha: 0.4) ) ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF0055),
                        shape: BoxShape.circle ) ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).live,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFF0055),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5 ) ),
                  ] ) ),
            ] ) ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: aspectRatio),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return AspectRatio(
              aspectRatio: value,
              child: child );
          },
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    if (!_isScrolling) setState(() => _isScrolling = true);
                  } else if (notification is ScrollEndNotification) {
                    if (_isScrolling) setState(() => _isScrolling = false);
                  } else if (notification is ScrollUpdateNotification) {
                    // Keep it hidden during drag
                    if (!_isScrolling) setState(() => _isScrolling = true);
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.featuredMovies.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _targetAspect = null; // Revert to default aspect on swipe
                    });
                  },
                  itemBuilder: (context, index) {
                    final movie = widget.featuredMovies[index];
                    final movieId = movie['_id'] ?? movie['id'] ?? index.toString();
                    return RepaintBoundary(
                      child: _HeroSlide(
                        key: ValueKey(movieId),
                        item: movie,
                        isActive: _currentIndex == index,
                        index: index,
                        onAspectChanged: (aspect) => _updateAspect(aspect) ) );
                  } ) ),

              // Page Indicators stay inside for visual focus
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.featuredMovies.length, (
                    index ) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      width: _currentIndex == index ? 20 : 6,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.white54,
                        borderRadius: BorderRadius.circular(2) ) );
                  }) ) ),
            ] ) ),
        SizedBox(height: isMobile ? 12 : 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickAction(
                icon: Icons.category_rounded,
                label: "Genres",
                colors: [
                  const Color(0xFFFF6B00),
                  const Color(0xFFFF0099),
                ],
                size: 46,
                onTap: () => _showGenresPopup(context) ),
              // CINEFEED
              _buildQuickAction(
                icon: Icons.play_circle_filled_rounded,
                label: "CineFeed",
                colors: [
                  const Color(0xFF00FFFF),
                  const Color(0xFF0055FF),
                ],
                size: 52,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CinemaFeedScreen() ) );
                } ),
              // DIRECTOR'S CUT
              _buildQuickAction(
                icon: Icons.movie_creation_rounded,
                label: "Director's Cut",
                colors: [
                  const Color(0xFFFFE000),
                  const Color(0xFF00FF88),
                ],
                size: 46,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DirectorsCutScreen() ) );
                } ),
            ] ) ),
        const SizedBox(height: 15),
      ] );
  }

  void _showGenresPopup(BuildContext context) {
    final List<Map<String, dynamic>> genres = [
      {
        'name': 'Action',
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFFF4500),
        'stat': '92% Match',
        'statColor': const Color(0xFF00FF88),
      },
      {
        'name': 'Comedy',
        'icon': Icons.sentiment_very_satisfied_rounded,
        'color': const Color(0xFFFFD700),
        'stat': '2.4k Titles',
        'statColor': Colors.white54,
      },
      {
        'name': 'Drama',
        'icon': Icons.theater_comedy_rounded,
        'color': const Color(0xFF9D00FF),
        'stat': 'Trending',
        'statColor': const Color(0xFFFF0055),
      },
      {
        'name': 'Romance',
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFFF0055),
        'stat': '85% Match',
        'statColor': const Color(0xFF00FF88),
      },
      {
        'name': 'Horror',
        'icon': Icons.nightlight_round,
        'color': const Color(0xFF8B0000),
        'stat': 'New',
        'statColor': const Color(0xFF00F0FF),
      },
      {
        'name': 'Thriller',
        'icon': Icons.remove_red_eye_rounded,
        'color': const Color(0xFF00C896),
        'stat': '78% Match',
        'statColor': const Color(0xFF00FF88),
      },
      {
        'name': 'Sci-Fi',
        'icon': Icons.rocket_launch_rounded,
        'color': const Color(0xFF00F0FF),
        'stat': '1.1k Titles',
        'statColor': Colors.white54,
      },
      {
        'name': 'Fantasy',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFFAA44FF),
        'stat': 'Trending',
        'statColor': const Color(0xFFFF0055),
      },
      {
        'name': 'Animation',
        'icon': Icons.animation_rounded,
        'color': const Color(0xFFFF8C00),
        'stat': '95% Match',
        'statColor': const Color(0xFF00FF88),
      },
      {
        'name': 'Adventure',
        'icon': Icons.explore_rounded,
        'color': const Color(0xFF00C8FF),
        'stat': '88% Match',
        'statColor': const Color(0xFF00FF88),
      },
      {
        'name': 'Mystery',
        'icon': Icons.search_rounded,
        'color': const Color(0xFF7B68EE),
        'stat': '850 Titles',
        'statColor': Colors.white54,
      },
      {
        'name': 'Crime',
        'icon': Icons.gavel_rounded,
        'color': const Color(0xFFB8860B),
        'stat': 'Trending',
        'statColor': const Color(0xFFFF0055),
      },
      {
        'name': 'Biography',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF20B2AA),
        'stat': '72% Match',
        'statColor': const Color(0xFF00FF88),
      },
      {
        'name': 'Historical',
        'icon': Icons.history_edu_rounded,
        'color': const Color(0xFFCD853F),
        'stat': '600 Titles',
        'statColor': Colors.white54,
      },
      {
        'name': 'Musical',
        'icon': Icons.music_note_rounded,
        'color': const Color(0xFFFF69B4),
        'stat': '54% Match',
        'statColor': const Color(0xFF00FF88),
      },
      {
        'name': 'Sports',
        'icon': Icons.sports_soccer_rounded,
        'color': const Color(0xFF32CD32),
        'stat': 'New',
        'statColor': const Color(0xFF00F0FF),
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
              width: 1.5 ) ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2) ) ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C00), Color(0xFFFF0055)] ),
                      borderRadius: BorderRadius.circular(6) ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: Colors.white,
                      size: 16 ) ),
                  const SizedBox(width: 10),
                  Text(
                    'Browse by Genre',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold ) ),
                ] ),
              const SizedBox(height: 4),
              Text(
                'Tap a genre to explore movies',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 16 ) ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: genres.map((genre) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GenreMoviesScreen(
                            genreName: genre['name'] as String,
                            genreColor: genre['color'] as Color,
                            onBackPressed: () {
                              Navigator.pop(context); // Pop GenreMoviesScreen
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () => _showGenresPopup(
                                  context ), // Re-open the genre modal
                              );
                            } ) ) );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10 ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: (genre['color'] as Color).withValues(alpha: 0.12),
                        border: Border.all(
                          color: (genre['color'] as Color).withValues(alpha: 0.5),
                          width: 1.2 ) ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    genre['icon'] as IconData,
                                    color: genre['color'] as Color,
                                    size: 16 ),
                                  const SizedBox(width: 6),
                                  Text(
                                    genre['name'] as String,
                                    style: GoogleFonts.outfit(
                                      color: Theme.of(
                                        context ).textTheme.bodyMedium?.color,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600 ) ),
                                ] ),
                              if (genre['stat'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  genre['stat'] as String,
                                  style: GoogleFonts.sourceCodePro(
                                    color: genre['statColor'] as Color? ?? Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold ) ),
                              ],
                            ] ),
                        ] ) ) );
                }).toList() ),
            ] ) );
      } );
  }
}

class _HeroSlide extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isActive;
  final int index;
  final void Function(double)? onAspectChanged;

  const _HeroSlide({
    super.key,
    required this.item,
    required this.isActive,
    required this.index,
    this.onAspectChanged,
  });

  @override
  State<_HeroSlide> createState() => _HeroSlideState();
}

class _HeroSlideState extends State<_HeroSlide> {
  VideoPlayerController? _videoController;
  Timer? _delayTimer;
  bool _showVideo = false;
  bool _timerFired = false;
  bool _isVisibleOnScreen = true;
  bool _isWaitingForReplay = false;
  bool _viewIncremented = false;

  static const List<List<Color>> _neonGradients = [
    [Color(0xFF00F0FF), Color(0xFF0080FF)],
    [Color(0xFFFF0055), Color(0xFFFF6B9D)],
    [Color(0xFFFFD700), Color(0xFFFF8C00)],
    [Color(0xFF9D00FF), Color(0xFFFF00FF)],
    [Color(0xFF00FF88), Color(0xFF00FFFF)],
  ];

  @override
  void initState() {
    super.initState();
    // Listen for immediate pause signal from MainScreen on swipe
    HomeScreenV2.pauseVideo.addListener(_onGlobalPause);
    if (widget.item['videoUrl'] != null &&
        widget.item['videoUrl'].toString().isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.item['videoUrl']))
            ..initialize()
                .then((_) {
                  _videoController!.setVolume(kIsWeb ? 0.0 : 1.0); // Mute on web to prevent Chrome autoplay NotAllowedError
                  _videoController!.setLooping(false);
                  _videoController!.addListener(_videoListener);
                  if (mounted) {
                    _setVideoVisible(true);
                  }

                  if (widget.isActive) {
                    _checkAndPlay();
                  }
                })
                .catchError((e) {
                  debugPrint("Video play error: $e");
                  if (mounted) {
                    setState(() {
                      _showVideo = false;
                    });
                  }
                });

      if (widget.isActive) {
        _startDelayTimer();
      }
    }
  }

  void _onGlobalPause() {
    if (HomeScreenV2.pauseVideo.value) {
      _cancelVideoPlayback();
    }
  }

  void _startDelayTimer() {
    // Respect the global autoPlay setting
    if (!AppSettings.instance.autoPlay) return;
    _delayTimer?.cancel();
    _timerFired = false;
    _isWaitingForReplay = false;
    int delayMs = 4500;
    _delayTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted && widget.isActive) {
        _timerFired = true;
        _checkAndPlay();
      }
    });
  }

  void _setVideoVisible(bool visible) {
    if (_showVideo == visible) return;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showVideo != visible) {
          setState(() {
            _showVideo = visible;
          });
        }
      });
    }
    if (widget.onAspectChanged != null) {
      if (visible && _videoController != null && _videoController!.value.isInitialized) {
        widget.onAspectChanged!(_videoController!.value.aspectRatio);
      } else {
        final bool isMobile = MediaQuery.of(context).size.width < 800;
        widget.onAspectChanged!(isMobile ? 0.85 : 1.4);
      }
    }
  }

  void _videoListener() {
    if (_videoController == null) return;
    final value = _videoController!.value;
    if (value.isInitialized && !value.isPlaying) {
      if (value.position >= value.duration && value.duration > Duration.zero) {
        if (!_isWaitingForReplay) {
          _isWaitingForReplay = true;
          _onVideoCompleted();
        }
      }
    }
  }

  void _onVideoCompleted() {
    if (mounted && _showVideo) {
      _setVideoVisible(false);
    }
    _videoController?.seekTo(Duration.zero);
    
    _delayTimer?.cancel();
    _delayTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && widget.isActive && _isVisibleOnScreen) {
        _isWaitingForReplay = false;
        if (!_showVideo) {
          _setVideoVisible(true);
        }
        _videoController?.play();
      } else {
        _isWaitingForReplay = false;
      }
    });
  }

  void _checkAndPlay() {
    if (mounted &&
        widget.isActive &&
        _timerFired &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      if (!_showVideo) {
        _setVideoVisible(true);
      }
      // Check both visibility detector AND ticker mode (which handles tab visibility)
      final bool isTickerActive = TickerMode.valuesOf(context).enabled;
      
      if (_isVisibleOnScreen && isTickerActive) {
        _isWaitingForReplay = false;
        try {
          if (_videoController!.value.position >= _videoController!.value.duration && _videoController!.value.duration > Duration.zero) {
            _videoController!.seekTo(Duration.zero).catchError((_) {});
          }
          _videoController!.play().catchError((_) {});
          _incrementTrailerView();
        } catch (e) {
          debugPrint("Video play exception caught: $e");
        }
      }
    }
  }

  void _cancelVideoPlayback() {
    _delayTimer?.cancel();
    _timerFired = false;
    try {
      _videoController?.pause().catchError((_) {});
    } catch (_) {}
    if (mounted && _showVideo) {
      _setVideoVisible(false);
    }
  }

  @override
  void dispose() {
    HomeScreenV2.pauseVideo.removeListener(_onGlobalPause);
    _delayTimer?.cancel();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HeroSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startDelayTimer();
      } else {
        _cancelVideoPlayback();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode instantly becomes false when the TabBar starts swiping away
    final bool isTickerActive = TickerMode.valuesOf(context).enabled;
    if (!isTickerActive) {
      _cancelVideoPlayback();
    } else if (widget.isActive && _isVisibleOnScreen && _timerFired) {
      _checkAndPlay();
    }
  }

  Future<void> _playTrailer(BuildContext context, String videoUrl) async {
    final Uri url = Uri.parse(videoUrl);
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Could not launch trailer: $url"),
          backgroundColor: Colors.red ) );
    }
  }

  String _formatNumber(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    }
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
    }
    return num.toString();
  }

  String _getStatString(dynamic rawValue, String fallbackFormatted) {
    if (rawValue == null) return fallbackFormatted;
    if (rawValue is int) {
      return _formatNumber(rawValue);
    }
    if (rawValue is double) {
      return _formatNumber(rawValue.toInt());
    }
    if (rawValue is String) {
      final parsed = int.tryParse(rawValue);
      if (parsed != null) {
        return _formatNumber(parsed);
      }
      return rawValue;
    }
    if (rawValue is List) {
      return _formatNumber(rawValue.length);
    }
    return fallbackFormatted;
  }

  Future<void> _incrementTrailerView() async {
    if (_viewIncremented) return;
    _viewIncremented = true;
    try {
      final movieId = widget.item['_id'] ?? widget.item['id'];
      final response = await http.post(
        Uri.parse('$baseUrl/api/movies/$movieId/view'),
        headers: {'Content-Type': 'application/json'} );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            widget.item['trailerViews'] = data['trailerViews'];
            widget.item['views'] = data['views'];
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to increment trailer views: $e");
    }
  }

  // ── Trailer stats strip ────────────────────────────────────────────────────
  static const List<Map<String, Object>> _mockTrailerStats = [
    // index 0 – Funky
    {'views': '45.2M', 'likes': '2.1M', 'comments': '89K', 'isRecord': true,  'record': 'Fastest 30M Views in Telugu Comedy'},
    // index 1 – Couple Friendly
    {'views': '18.7M', 'likes': '890K', 'comments': '34K', 'isRecord': false, 'record': ''},
    // index 2 – Seetha Payanam
    {'views': '22.3M', 'likes': '1.1M', 'comments': '45K', 'isRecord': false, 'record': ''},
    // index 3 – Mana ShankaraVara Prasad
    {'views': '31.5M', 'likes': '1.5M', 'comments': '62K', 'isRecord': true,  'record': '#1 Most Liked Action-Comedy Trailer'},
    // index 4 – The Raja Saab
    {'views': '142M',  'likes': '8.7M', 'comments': '320K', 'isRecord': true, 'record': 'ALL-TIME RECORD · Fastest 100M Views!'},
  ];

  // ── Top-left views/likes floating badge ─────────────────────────────────────
  Widget _buildViewsBadge(Map<String, dynamic> item, int idx, bool isMobile) {
    final s = idx < _mockTrailerStats.length
        ? _mockTrailerStats[idx]
        : _mockTrailerStats[0];
    final String views = _getStatString(item['views'] ?? item['trailerViews'], s['views']! as String);
    final String likes = _getStatString(item['likes'] ?? item['trailerLikes'], s['likes']! as String);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.45) ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
            blurRadius: 10 ),
        ] ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_rounded, color: Color(0xFF00F0FF), size: 13),
          const SizedBox(width: 5),
          Text(
            views,
            style: GoogleFonts.sourceCodePro(
              color: Colors.white,
              fontSize: isMobile ? 12 : 11,
              fontWeight: FontWeight.w800 ) ),
          const SizedBox(width: 10),
          const Icon(Icons.thumb_up_alt_rounded, color: Color(0xFFFF4D8B), size: 12),
          const SizedBox(width: 5),
          Text(
            likes,
            style: GoogleFonts.sourceCodePro(
              color: Colors.white,
              fontSize: isMobile ? 12 : 11,
              fontWeight: FontWeight.w800 ) ),
        ] ) );
  }

  // ── Record-breaker badge (above title) ───────────────────────────────────────
  Widget _buildRecordBadge(Map<String, dynamic> item, int idx, bool isMobile) {
    final s = idx < _mockTrailerStats.length
        ? _mockTrailerStats[idx]
        : _mockTrailerStats[0];
    final bool isRecord =
        (item['isRecordBreaker'] as bool?) ?? (s['isRecord']! as bool);
    final String record =
        item['recordText'] as String? ?? s['record']! as String;

    if (!isRecord || record.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black.withValues(alpha: 0.75),
            border: Border.all(
              color: const Color(0xFFFF4500).withValues(alpha: 0.7),
              width: 1.2 ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4500).withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 1 ),
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                blurRadius: 20 ),
            ] ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFD700), // Gold
                    Color(0xFFFF4500), // Orange
                    Color(0xFFFF0055)  // Crimson
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight ).createShader(bounds),
                child: Text(
                  record,
                  style: GoogleFonts.outfit(
                    color: Colors.white, // Required for ShaderMask
                    fontSize: isMobile ? 12 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4 ) ) ),
            ] ) ),
      ] );
  }



  @override
  Widget build(BuildContext context) {
    final int colorIndex = widget.index;
    final gradientColors = _neonGradients[colorIndex % _neonGradients.length];
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return VisibilityDetector(
      key: Key('hero-slide-${widget.index}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.3;
        if (_isVisibleOnScreen != visible) {
          _isVisibleOnScreen = visible;
          if (visible && widget.isActive) {
            _startDelayTimer();
          } else if (!visible) {
            _cancelVideoPlayback();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HeroMovieInfoScreen(movie: widget.item) ) );
        },
        child: Container(
          margin: const EdgeInsets.only(left: 5, right: 15),
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientColors[0],
                gradientColors[1].withValues(alpha: 0.8),
                gradientColors[0].withValues(alpha: 0.9),
              ] ),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.3),
                blurRadius: 25,
                spreadRadius: 2 ),
            ] ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Background Image
                  CachedNetworkImage(
                    imageUrl: widget.item['image'] ?? "",
                    fit: BoxFit.cover, 
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white24,
                        size: 50 ) ) ),

                  if (_videoController != null &&
                      _videoController!.value.isInitialized)
                    AnimatedOpacity(
                      opacity: (_showVideo && widget.isActive) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
                      child: IgnorePointer(
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.fitHeight,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: VideoPlayer(_videoController!) ) ) ) ) ),

                  AnimatedOpacity(
                    opacity: _showVideo ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 2. HUD Grid Overlay
                        Opacity(
                          opacity: 0.15,
                          child: Container(
                        decoration: BoxDecoration(
                          color: gradientColors[0].withValues(alpha: 0.05) ) ) ),

                  // 3. Dark gradient for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.transparent,
                          const Color(0xFF0F1014).withValues(alpha: 0.7),
                          const Color(0xFF0F1014).withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.4, 0.7, 1.0] ) ) ),

                  // 4. Rating Badge (Top Right)
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6 ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.yellow.withValues(alpha: 0.3) ) ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.yellow,
                            size: 14 ),
                          const SizedBox(width: 4),
                          Text(
                            widget.item['rating']?.toString() ?? "0.0",
                            style: GoogleFonts.outfit(
                              color: Colors.yellow,
                              fontSize: 12,
                              fontWeight: FontWeight.w900 ) ),
                        ] ) ) ),

                  // 4.5. Trailer Views Badge (Top Left)
                  Positioned(
                    top: 15,
                    left: 15,
                    child: _buildViewsBadge(widget.item, widget.index, isMobile) ),



                  // 5. Hero Content Cluster
                  Positioned(
                    bottom: 25,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (widget.item['title'] ?? "Unknown").toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 36 : 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            height: 1.1 ) ),
                        const SizedBox(height: 6),
                        // ── Record-breaker badge (inline, below title) ──
                        _buildRecordBadge(widget.item, widget.index, isMobile),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4 ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0055).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFF0055 ).withValues(alpha: 0.5) ) ),
                              child: Text(
                                (widget.item['tags'] as String? ?? "Action")
                                    .split('•')
                                    .first
                                    .trim(),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFF0055),
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 12 : 10 ) ) ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "${widget.item['tags'] as String? ?? ""} • 2024",
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: isMobile ? 14 : 12,
                                  fontWeight: FontWeight.w500 ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis ) ),
                          ] ),
                        const SizedBox(height: 10),
                        Text(
                          widget.item['desc'] ?? "",
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 18 : 13,
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.4 ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () {
                            if (widget.item['videoUrl'] != null) {
                              _playTrailer(context, widget.item['videoUrl']!);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8 ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F0FF),
                              borderRadius: BorderRadius.circular(
                                isMobile ? 12 : 10 ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00F0FF ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3) ),
                              ] ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  color: Colors.black,
                                  size: isMobile ? 18 : 16 ),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations.of(context).watchTrailer,
                                  style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 16 : 14 ) ),
                              ] ) ) ),
                      ] ) ),
                      ] ) ),
                ] ) ) ) ) ) );
  }
}

// ─── BOX OFFICE TRACKER SECTION ──────────────────────────────────────────────
class BoxOfficeTrackerSection extends StatefulWidget {
  const BoxOfficeTrackerSection({super.key});

  @override
  State<BoxOfficeTrackerSection> createState() =>
      _BoxOfficeTrackerSectionState();
}

class _BoxOfficeTrackerSectionState extends State<BoxOfficeTrackerSection> {
  List<Map<String, dynamic>> _movies = [];
  bool _isLoading = true;
  String? _error;

  // Fallback mock data if API is unavailable
  final List<Map<String, dynamic>> _mockMovies = [
    {
      "title": "Pushpa 2: The Rule",
      "image": "assets/pushpa_poster.png",
      "collected": 850.5,
      "target": 500.0,
      "occupancy": 92,
      "verdict": "BLOCKBUSTER",
      "daily": [45, 60, 85, 120, 150, 210, 180],
    },
    {
      "title": "Game Changer",
      "image": "assets/game_changer_poster.png",
      "collected": 210.0,
      "target": 250.0,
      "occupancy": 65,
      "verdict": "AVERAGE",
      "daily": [30, 25, 40, 35, 30, 25, 25],
    },
    {
      "title": "Devara: Part 1",
      "image": "assets/devara_poster.png",
      "collected": 415.0,
      "target": 300.0,
      "occupancy": 78,
      "verdict": "HIT",
      "daily": [40, 35, 50, 65, 80, 95, 50],
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/box-office'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _movies = data.map((e) {
              final m = Map<String, dynamic>.from(e);
              // Ensure 'daily' is List<int> for the painter
              if (m['daily'] is List) {
                m['daily'] = List<int>.from(
                  (m['daily'] as List).map((v) => (v as num).toInt()) );
              }
              // Use local asset if image key matches
              if ((m['image'] as String? ?? '').isEmpty) {
                m['image'] = 'assets/pushpa_poster.png';
              }
              return m;
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Server Error ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _movies = _mockMovies; // graceful fallback
          _isLoading = false;
          _error = 'Using offline data';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800),
                  borderRadius: BorderRadius.circular(6) ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.black,
                  size: 16 ) ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).boxOfficeCollections,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0 ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis ),
                    const SizedBox(height: 6),
                    _buildHoloStatus(),
                  ] ) ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: GestureDetector(
                    onTap: _fetchData,
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white38,
                      size: 16 ) ) ),
            ] ) ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 6),
            child: Text(
              '⚡ $_error',
              style: const TextStyle(color: Colors.amber, fontSize: 10) ) ),
        SizedBox(
          height: 400,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB800),
                    strokeWidth: 2 ) )
              : _movies.isEmpty
              ? Center(
                  child: Text(
                    'No data available',
                    style: GoogleFonts.outfit(color: Colors.white38) ) )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  itemCount: _movies.length,
                  itemBuilder: (context, index) {
                    return _HologramBoxOfficeCard(movie: _movies[index]);
                  } ) ),
      ] );
  }

  Widget _buildHoloStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00FBFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FBFF).withValues(alpha: 0.4)) ),
      child: const Text(
        'LIVE TRACKER',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF00FBFF),
          letterSpacing: 2.0 ) ) );
  }
}

class _HologramBoxOfficeCard extends StatefulWidget {
  final Map<String, dynamic> movie;
  const _HologramBoxOfficeCard({required this.movie});

  @override
  State<_HologramBoxOfficeCard> createState() => _HologramBoxOfficeCardState();
}

class _HologramBoxOfficeCardState extends State<_HologramBoxOfficeCard>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4) )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut) );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoxOfficeDetailScreen(movie: widget.movie) ) );
  }

  Color _getHoloColor(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'BLOCKBUSTER':
        return const Color(0xFFB08CFF);
      case 'HIT':
        return const Color(0xFF8CFFD4);
      case 'AVERAGE':
        return const Color(0xFFFFEB8C);
      case 'FLOP':
        return const Color(0xFFFF8C9F);
      default:
        return const Color(0xFF8CFAFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double collected = (widget.movie['collected'] as num).toDouble();
    final String verdict = widget.movie['verdict'] as String;
    final Color holoColor = _getHoloColor(verdict);
    final String imagePath = widget.movie['image'];
    final bool isAsset = imagePath.startsWith('assets/');

    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 20),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ProjectionBeamPainter(color: holoColor) ) ),

          // --- GRAPH AREA (TAP FOR TRENDS) ---
          Positioned(
            bottom: 120,
            left: 30,
            right: 30,
            height: 100,
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                painter: _PointCloudPainter(
                  data: List<int>.from(widget.movie['daily']),
                  color: holoColor ) ) ) ),

          // --- POSTER AREA (TAP FOR DETAILS) ---
          Positioned(
            top: 40,
            left: 45,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: GestureDetector(
                    onTap: () => _navigateToDetails(context),
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(-0.3)
                        ..rotateX(0.1),
                      child: Container(
                          width: 130,
                          height: 160,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: holoColor.withValues(alpha: 0.5),
                              width: 1.5 ),
                            boxShadow: [
                              BoxShadow(
                                color: holoColor.withValues(alpha: 0.3),
                                blurRadius: 30 ),
                            ] ),
                          child: child ) ) ) );
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: isAsset
                        ? Image.asset(imagePath, fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: imagePath,
                            fit: BoxFit.cover, 
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.movie, color: Colors.white10) ) ),
                  if (_isExpanded)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DAILY TREND',
                              style: GoogleFonts.shareTechMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: holoColor ) ),
                            const Divider(color: Colors.white24, height: 10),
                            Expanded(
                              child: ListView.builder(
                                itemCount:
                                    (widget.movie['daily'] as List).length,
                                itemBuilder: (context, i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2 ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'DAY ${i + 1}',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            color: Colors.white60 ) ),
                                        Text(
                                          '₹${widget.movie['daily'][i]}Cr',
                                          style: GoogleFonts.shareTechMono(
                                            fontSize: 9,
                                            color: Colors.white ) ),
                                      ] ) );
                                } ) ),
                          ] ) ) ),
                ] ) ) ),

          // --- INFO AREA (TAP FOR DETAILS) ---
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _navigateToDetails(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(15) ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildEnhancedReadout(
                          'COLLECTED',
                          '₹${collected}Cr',
                          holoColor ),
                        _buildEnhancedReadout(
                          'OCCUPANCY',
                          '${widget.movie['occupancy']}%',
                          Colors.white ),
                      ] ),
                    const SizedBox(height: 12),
                    Text(
                      verdict,
                      style: GoogleFonts.shareTechMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: holoColor,
                        letterSpacing: 4,
                        shadows: [Shadow(color: holoColor, blurRadius: 15)] ) ),
                  ] ) ) ) ),

          // --- TITLE AREA (TAP FOR DETAILS) ---
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _navigateToDetails(context),
              child: Center(
                child: Text(
                  widget.movie['title'].toUpperCase(),
                  style: GoogleFonts.shareTechMono(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)] ) ) ) ) ),
        ] ) );
  }

  Widget _buildEnhancedReadout(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1 ) ),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10)] ) ),
      ] );
  }
}

class _ProjectionBeamPainter extends CustomPainter {
  final Color color;
  _ProjectionBeamPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.5),
          color.withValues(alpha: 0.1),
          Colors.transparent,
        ] ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(-size.width * 0.2, size.height * 0.1)
      ..lineTo(size.width * 1.2, size.height * 0.1)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointCloudPainter extends CustomPainter {
  final List<int> data;
  final Color color;

  _PointCloudPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final stepX = size.width / (data.length - 1);
    final maxVal = 250.0;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxVal * size.height);

      // Draw a vertical cloud of points around the data point
      for (int j = 0; j < 5; j++) {
        final double jitterY = (j - 2) * 4.0;
        final double opacity = (1.0 - (j.abs() - 2).abs() / 2.0).clamp(
          0.1,
          1.0 );

        canvas.drawCircle(
          Offset(x, y + jitterY),
          1.5,
          Paint()..color = color.withValues(alpha: opacity * 0.5) );
      }

      // Main glows
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4) );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- TELUGU RATED MOVIES SECTION ---
class TeluguRatedMoviesSection extends StatefulWidget {
  const TeluguRatedMoviesSection({super.key});

  @override
  State<TeluguRatedMoviesSection> createState() =>
      _TeluguRatedMoviesSectionState();
}

class _TeluguRatedMoviesSectionState extends State<TeluguRatedMoviesSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _overrated = [];
  List<Map<String, dynamic>> _underrated = [];
  bool _isLoading = true;
  String? _error;
  Set<String> _likedMovieIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLikedStates();
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLikedStates() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('liked_telugu_verdict_ids') ?? [];
    if (mounted) {
      setState(() {
        _likedMovieIds = list.toSet();
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadLikedStates();
    try {
      final overRes = await http
          .get(Uri.parse('$baseUrl/api/telugu-verdict?category=overrated'))
          .timeout(const Duration(seconds: 10));
      final underRes = await http
          .get(Uri.parse('$baseUrl/api/telugu-verdict?category=underrated'))
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          if (overRes.statusCode == 200) {
            _overrated = List<Map<String, dynamic>>.from(
              json.decode(overRes.body) );
          }
          if (underRes.statusCode == 200) {
            _underrated = List<Map<String, dynamic>>.from(
              json.decode(underRes.body) );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Server busy. Please try again later.';
          _isLoading = false;
        });
      }
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> movie) async {
    final bool isOverrated = (movie['category'] ?? '') == 'overrated';
    final Color accentColor = isOverrated
        ? const Color(0xFFFF4500)
        : const Color(0xFF00C896);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeluguVerdictDetailSheet(
        movie: movie,
        accentColor: accentColor,
        isOverrated: isOverrated ) );

    // Sync state after returning from sheet
    await _loadLikedStates();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800),
                  borderRadius: BorderRadius.circular(6) ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.black,
                  size: 16 ) ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TELUGU VERDICT',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis ) ),
              // Refresh button
              if (!_isLoading)
                GestureDetector(
                  onTap: _fetchData,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08) ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white54,
                      size: 16 ) ) ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4 ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFFFB800) ),
                child: Text(
                  'Telugu',
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13 ) ) ),
            ] ) ),
        const SizedBox(height: 12),

        // ── Tab Bar ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12) ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4500), Color(0xFFFFD700)] ) ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 15 ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                fontSize: 15 ),
              tabs: const [
                Tab(text: '🔥 Overrated'),
                Tab(text: '💎 Underrated'),
              ] ) ) ),
        const SizedBox(height: 14),

        // ── Content ────────────────────────────────────────────────────────
        SizedBox(
          height: 215,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                    strokeWidth: 2 ) )
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white24,
                        size: 36 ),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load Telugu Verdict',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 13 ) ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _fetchData,
                        child: Text(
                          'Retry',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFFD700) ) ) ),
                    ] ) )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMovieList(_overrated, isOverrated: true),
                    _buildMovieList(_underrated, isOverrated: false),
                  ] ) ),
        const SizedBox(height: 10),
      ] );
  }

  Widget _buildMovieList(
    List<Map<String, dynamic>> movies, {
    required bool isOverrated,
  }) {
    if (movies.isEmpty) {
      return Center(
        child: Text(
          'No movies found',
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16) ) );
    }

    final Color verdictColor = isOverrated
        ? const Color(0xFFFF4500)
        : const Color(0xFF00C896);
    final IconData verdictIcon = isOverrated
        ? Icons.trending_up_rounded
        : Icons.diamond_rounded;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20, right: 8),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return GestureDetector(
          onTap: () => _showDetail(context, movie),
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: verdictColor.withValues(alpha: 0.3),
                width: 1.2 ),
              boxShadow: [
                BoxShadow(
                  color: verdictColor.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4) ),
              ] ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Poster ──────────────────────────────────────────────
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: movie['image'] ?? '',
                          fit: BoxFit.cover, 
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey[850],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white24,
                              size: 30 ) ) ),
                        // Gradient overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.9),
                                ] ) ) ) ),
                        // Category badge (top-right)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: verdictColor.withValues(alpha: 0.6),
                                width: 1 ) ),
                            child: Icon(
                              verdictIcon,
                              color: verdictColor,
                              size: 13 ) ) ),
                        // Rating badge (bottom-left over gradient)
                        if ((movie['rating'] ?? 'N/A') != 'N/A')
                          Positioned(
                            bottom: 6,
                            left: 8,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFD700),
                                  size: 12 ),
                                const SizedBox(width: 2),
                                Text(
                                  movie['rating'] ?? '',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold ) ),
                              ] ) ),
                        // Like indicator (bottom-right over gradient)
                        if (_likedMovieIds.contains(movie['_id']))
                          Positioned(
                            bottom: 6,
                            right: 8,
                            child: const Icon(
                              Icons.favorite,
                              color: Color(0xFFFF0055),
                              size: 14 ) ),
                        // Tap hint ripple
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showDetail(context, movie),
                              borderRadius: BorderRadius.circular(16) ) ) ),
                      ] ) ),
                  // ── Info ─────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie['title'] ?? '',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14 ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis ),
                        const SizedBox(height: 2),
                        Text(
                          movie['verdict'] ?? '',
                          style: GoogleFonts.outfit(
                            color: verdictColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500 ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis ),
                      ] ) ),
                ] ) ) ) );
      } );
  }
}

// ─── DETAIL BOTTOM SHEET ──────────────────────────────────────────────────────
// ─── DETAIL BOTTOM SHEET ──────────────────────────────────────────────────────
class _TeluguVerdictDetailSheet extends StatefulWidget {
  final Map<String, dynamic> movie;
  final Color accentColor;
  final bool isOverrated;

  const _TeluguVerdictDetailSheet({
    required this.movie,
    required this.accentColor,
    required this.isOverrated,
  });

  @override
  State<_TeluguVerdictDetailSheet> createState() =>
      _TeluguVerdictDetailSheetState();
}

class _TeluguVerdictDetailSheetState extends State<_TeluguVerdictDetailSheet> {
  bool _isLiked = false;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    // Deterministic base like count based on ID
    final String id = widget.movie['_id']?.toString() ?? '';
    final int baseLikes = (id.hashCode % 80).abs() + 15;
    _likeCount = baseLikes;
    _loadLikedState();
  }

  Future<void> _loadLikedState() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('liked_telugu_verdict_ids') ?? [];
    final id = widget.movie['_id']?.toString() ?? '';
    if (mounted) {
      setState(() {
        _isLiked = list.contains(id);
        if (_isLiked) {
          _likeCount += 1;
        }
      });
    }
  }

  Future<void> _toggleLike() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('liked_telugu_verdict_ids') ?? [];
    final id = widget.movie['_id']?.toString() ?? '';

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount -= 1;
        list.remove(id);
      } else {
        _isLiked = true;
        _likeCount += 1;
        if (!list.contains(id)) list.add(id);
      }
    });

    await prefs.setStringList('liked_telugu_verdict_ids', list);
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final accentColor = widget.accentColor;
    final isOverrated = widget.isOverrated;

    final cast = movie['cast'] as List<dynamic>? ?? [];
    final String rating = movie['rating'] ?? 'N/A';
    final double ratingValue = double.tryParse(rating) ?? 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1 ) ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Poster hero ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28) ),
                  child: Stack(
                    children: [
                      // Poster
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: movie['image'] ?? '',
                          fit: BoxFit.cover, 
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey[900],
                            child: const Icon(
                              Icons.movie_outlined,
                              color: Colors.white24,
                              size: 50 ) ) ) ),
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.9),
                              ],
                              stops: const [0.4, 1.0] ) ) ) ),
                      // Category stamp
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6 ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: accentColor.withValues(alpha: 0.85) ),
                          child: Row(
                            children: [
                              Icon(
                                isOverrated
                                    ? Icons.trending_up_rounded
                                    : Icons.diamond_rounded,
                                color: Colors.white,
                                size: 14 ),
                              const SizedBox(width: 5),
                              Text(
                                isOverrated ? 'Overrated' : 'Underrated',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12 ) ),
                            ] ) ) ),
                      // Close button
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1 ) ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18 ) ) ) ),
                      // Title + year at bottom of poster
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie['title'] ?? 'Unknown',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: accentColor.withValues(alpha: 0.4),
                                    blurRadius: 10 ),
                                ] ) ),
                            if ((movie['year'] ?? '').isNotEmpty)
                              Text(
                                movie['year'] ?? '',
                                style: GoogleFonts.outfit(
                                  color: Colors.white60,
                                  fontSize: 14 ) ),
                          ] ) ),
                      // Drag handle
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2) ) ) ) ),
                    ] ) ),

                // ── Body ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating + Tags row
                      Row(
                        children: [
                          // Star rating
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6 ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                width: 1 ) ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFD700),
                                  size: 16 ),
                                const SizedBox(width: 4),
                                Text(
                                  rating,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14 ) ),
                                Text(
                                  '/10',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white38,
                                    fontSize: 12 ) ),
                              ] ) ),
                          const SizedBox(width: 10),

                          // Like Button (Glowing Cyber-HUD style)
                          GestureDetector(
                            onTap: _toggleLike,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6 ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: _isLiked
                                    ? const Color(0xFFFF0055).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: _isLiked
                                      ? const Color(0xFFFF0055)
                                      : Colors.white24,
                                  width: 1 ),
                                boxShadow: _isLiked
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF0055).withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          spreadRadius: 1 )
                                      ]
                                    : [] ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: _isLiked ? const Color(0xFFFF0055) : Colors.white70,
                                    size: 16 ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "$_likeCount",
                                    style: GoogleFonts.outfit(
                                      color: _isLiked ? const Color(0xFFFF0055) : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14 ) ),
                                ] ) ) ),
                          const SizedBox(width: 10),

                          // Tags
                          if ((movie['tags'] ?? '').isNotEmpty)
                            Expanded(
                              child: Text(
                                movie['tags'] ?? '',
                                style: GoogleFonts.outfit(
                                  color: Colors.white54,
                                  fontSize: 12 ),
                                overflow: TextOverflow.ellipsis ) ),
                        ] ),
                      const SizedBox(height: 16),

                      // Verdict banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: accentColor.withValues(alpha: 0.1),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.4),
                            width: 1.2 ) ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isOverrated
                                  ? Icons.trending_up_rounded
                                  : Icons.diamond_rounded,
                              color: accentColor,
                              size: 20 ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Our Verdict',
                                    style: GoogleFonts.outfit(
                                      color: accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13 ) ),
                                  const SizedBox(height: 3),
                                  Text(
                                    movie['verdict'] ?? '',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 13 ) ),
                                ] ) ),
                          ] ) ),
                      const SizedBox(height: 18),

                      // Director
                      if ((movie['director'] ?? 'N/A') != 'N/A') ...[
                        Row(
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: accentColor,
                              size: 16 ),
                            const SizedBox(width: 6),
                            Text(
                              'Director',
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 13 ) ),
                            const SizedBox(width: 8),
                            Text(
                              movie['director'] ?? '',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13 ) ),
                          ] ),
                        const SizedBox(height: 14),
                      ],

                      // Synopsis
                      if ((movie['desc'] ?? '').isNotEmpty) ...[
                        Text(
                          'Synopsis',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15 ) ),
                        const SizedBox(height: 6),
                        Text(
                          movie['desc'] ?? '',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.6 ) ),
                        const SizedBox(height: 18),
                      ],

                      // Cast
                      if (cast.isNotEmpty) ...[
                        Text(
                          'Cast',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15 ) ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: cast.length,
                            itemBuilder: (context, i) {
                              final member = cast[i] as Map<String, dynamic>;
                              final imgUrl = member['image']?.toString() ?? '';
                              return Container(
                                width: 70,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: accentColor.withValues(alpha: 0.2),
                                      backgroundImage: imgUrl.isNotEmpty
                                          ? NetworkImage(imgUrl)
                                          : null,
                                      child: imgUrl.isEmpty
                                          ? Icon(
                                              Icons.person_rounded,
                                              color: accentColor,
                                              size: 26 )
                                          : null ),
                                    const SizedBox(height: 5),
                                    Text(
                                      member['name']?.toString() ?? '',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600 ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis ),
                                  ] ) );
                            } ) ),
                        const SizedBox(height: 10),
                      ],

                      // Star rating bar (visual)
                      if (ratingValue > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(10, (i) {
                            final filled = i < ratingValue.floor();
                            final half =
                                !filled &&
                                i < ratingValue &&
                                ratingValue - i >= 0.5;
                            return Icon(
                              filled
                                  ? Icons.star_rounded
                                  : half
                                  ? Icons.star_half_rounded
                                  : Icons.star_outline_rounded,
                              color: filled || half
                                  ? const Color(0xFFFFD700)
                                  : Colors.white24,
                              size: 18 );
                          }) ),
                        const SizedBox(height: 20),
                      ],
                    ] ) ),
              ] ) ) );
      } );
  }
}

