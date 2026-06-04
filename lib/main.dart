import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORTS ---
// Ensure these files exist in your project folder
import 'home_screen_v2.dart';
import 'profile_screen.dart';

import 'theatre_responses_screen.dart';
import 'add_review_screen.dart';
import 'splash_screen.dart';
import 'movie_details_screen.dart';
import 'cinematic_details_screen.dart';
import 'go_live_screen.dart';
import 'utils.dart'; // [New] Utils
import 'widgets/pulsing_live_badge.dart';
import 'guess_movie_game_screen.dart';
import 'live_video_player_screen.dart';
import 'live_stream_viewer_screen.dart';
import 'theme_provider.dart'; // [New] Theme Provider
import 'widgets/shimmer_loader.dart';
import 'widgets/screen_state_mixin.dart';
import 'widgets/connectivity_wrapper.dart';
import 'services/connectivity_service.dart';
import 'package:flutter_application_1/constants.dart';
import 'services/app_settings.dart';
import 'screens/settings_screen.dart';

import 'package:media_kit/media_kit.dart'; // [New] MediaKit

import 'services/http_cache_service.dart';
import 'app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint("Failed to initialize MediaKit: $e");
  }
  await AppConfig.init(); // Load server host from prefs
  await ThemeController.init();
  await AppSettings.instance.init();
  await ConnectivityService.instance.initialize();
  await HttpCacheService.initialize(); // [NEW] Warm up API response cache for instant startup
  // Lock entire app to portrait. Only fullscreen video screens unlock temporarily.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const CineSocialApp());
}

class CineSocialApp extends StatelessWidget {
  const CineSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeNotifier,
      builder: (_, ThemeMode currentMode, c) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LocaleController.localeNotifier,
          builder: (_, Locale currentLocale, c2) {
            return MaterialApp(
              scrollBehavior: AppScrollBehavior(),
              debugShowCheckedModeBanner: false,
              title: 'CineSocial',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              locale: currentLocale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const SplashScreen(),
              builder: (context, child) =>
                  ConnectivityWrapper(child: child ?? const SizedBox.shrink()) );
          } );
      } );
  }
}

// --- MAIN SCREEN (TABS) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _headerKey = GlobalKey();
  bool _appBarVisible = true;
  double _headerHeight = 140.0; // estimated, measured after first frame

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Update IndexedStack when tab changes (only fires on index commit, not every swipe frame)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }
      if (mounted) {
        setState(() {});
      }
      // If leaving home (index 0), immediately signal video to pause
      if (_tabController.index != 0) {
        HomeScreenV2.pauseVideo.value = true;
      } else {
        HomeScreenV2.pauseVideo.value = false;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());
  }

  void _measureHeader() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      setState(() => _headerHeight = box.size.height);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Always reveal the header when scrolled back to the top
    if (notification.metrics.pixels <= 0 && !_appBarVisible) {
      setState(() => _appBarVisible = true);
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 2 && _appBarVisible) {
        setState(() => _appBarVisible = false);
      } else if (delta < -2 && !_appBarVisible) {
        setState(() => _appBarVisible = true);
      }
    }
    return false;
  }

  Widget _buildHeader(BuildContext context) {
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xE1050510),
              border: Border(
                bottom: BorderSide(color: Color(0xFF00F0FF), width: 0.5) ) ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // â”€â”€ Top row: hamburger | title | actions â”€â”€
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        // Leading: hamburger + theatre button
                        SizedBox(
                          width: 90,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1 ),
                                      width: 1 ) ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _hamburgerLine(const Color(0xFF00F0FF)),
                                      const SizedBox(height: 4),
                                      _hamburgerLine(const Color(0xFFFF0055)),
                                      const SizedBox(height: 4),
                                      _hamburgerLine(const Color(0xFFFFD700)),
                                    ] ) ) ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TheatreResponsesScreen() ) ),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF9D00FF),
                                        Color(0xFF00F0FF),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF9D00FF ).withValues(alpha: 0.4),
                                        blurRadius: 10 ),
                                    ] ),
                                  child: const Icon(
                                    Icons.movie_filter_rounded,
                                    color: Colors.white,
                                    size: 15 ) ) ),
                            ] ) ),
                        // Title
                        Expanded(
                          child: Center(
                            child: ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [Color(0xFF00F0FF), Color(0xFFFF0055)] ).createShader(b),
                              child: Text(
                                AppLocalizations.of(context).appName.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Colors.white ) ) ) ) ),
                        // Actions
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05) ),
                          child: IconButton(
                            icon: const Icon(Icons.school, color: Colors.amber),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CinemaKnowledgeScreen() ) ) ) ),
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05) ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.search,
                              color: Color(0xFF00F0FF) ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddReviewScreen() ) ) ) ),
                      ] ) ),
                  // â”€â”€ Tab bar â”€â”€
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.transparent,
                    labelColor: const Color(0xFF00F0FF),
                    unselectedLabelColor: Theme.of(
                      context ).textTheme.bodySmall?.color,
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16 ),
                    unselectedLabelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.normal,
                      fontSize: 16 ),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.only(bottom: 10),
                    tabs: [
                      Tab(text: AppLocalizations.of(context).cinemaHub2.toUpperCase()),
                      Tab(
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F0FF), Color(0xFFFF0055)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00F0FF ).withValues(alpha: 0.6),
                                blurRadius: 15,
                                offset: const Offset(0, 5) ),
                            ] ),
                          child: const Icon(
                            Icons.hub,
                            color: Colors.white,
                            size: 28 ) ) ),
                      Tab(text: AppLocalizations.of(context).profile.toUpperCase()),
                    ] ),
                ] ) ) ) ) ) );
  }

  Widget _hamburgerLine(Color color) => Container(
    width: 18,
    height: 2.5,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
      ] ) );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenuDrawer(),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header collapses to 0 height when scrolling down
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              height: _appBarVisible ? _headerHeight : 0.0,
              child: OverflowBox(
                minHeight: 0,
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: SizedBox(key: _headerKey, child: _buildHeader(context)) ) ) ),
          // Tab content â€” IndexedStack renders only ONE screen at a time
          // (TabBarView rendered both simultaneously, causing the freeze)
          Expanded(
            child: RepaintBoundary(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    final vel = details.primaryVelocity ?? 0;
                    if (vel < -300) {
                      // Swipe left â†’ next tab
                      final next = (_tabController.index + 1).clamp(0, 2);
                      // Pause video BEFORE changing tab
                      HomeScreenV2.pauseVideo.value = true;
                      _tabController.animateTo(next);
                    } else if (vel > 300) {
                      // Swipe right â†’ prev tab
                      final prev = (_tabController.index - 1).clamp(0, 2);
                      if (prev != 0) {
                        HomeScreenV2.pauseVideo.value = true;
                      } else {
                        HomeScreenV2.pauseVideo.value = false;
                      }
                      _tabController.animateTo(prev);
                    }
                  },
                  child: IndexedStack(
                    index: _tabController.index,
                    children: const [
                      HomeScreenV2(),
                      InsightScreen(),
                      ProfileScreen(),
                    ] ) ) ) ) ),
        ] ) );
  }
}

// --- SCREEN: TOLLYWOOD TECH KNOWLEDGE (CLEAN VERSION) ---
class CinemaKnowledgeScreen extends StatefulWidget {
  const CinemaKnowledgeScreen({super.key});

  @override
  State<CinemaKnowledgeScreen> createState() => _CinemaKnowledgeScreenState();
}

class _CinemaKnowledgeScreenState extends State<CinemaKnowledgeScreen>
    with ScreenStateMixin {
  List<dynamic> topics = [];

  @override
  void initState() {
    super.initState();
    fetchTopics();
  }

  Future<void> fetchTopics() async {
    await handleApiState(
      cacheKey: 'tollywood_tech_cache',
      fetchData: () => HttpCacheService.get(Uri.parse(AppConstants.tollywoodTech)),
      onDataParsed: (decodedData) {
        if (decodedData is List) {
          topics = decodedData;
        }
      } );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510), // Matches MainScreen background
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF00F0FF), Color(0xFFFF0055)] ).createShader(b),
          child: Text(
            "TOLLYWOOD TECH",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white ) ) ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context) ) ),
      body: buildScreenState(
        onRetry: fetchTopics,
        buildLoading: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: 3,
          itemBuilder: (_, _) => const FeedCardSkeleton() ),
        buildSuccess: () => ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final item = topics[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.05 ), // Glassmorphism style dark card
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1 ) ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IMAGE SECTION
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20) ),
                    child: CachedNetworkImage(
                      imageUrl: item['image'] ?? '',
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover, 
                      filterQuality: FilterQuality.low,
                      placeholder: (c, u) => Container(
                        height: 250,
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00F0FF) ) ) ),
                      errorWidget: (c, u, e) => Container(
                        height: 250,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white24,
                          size: 50 ) ) ) ),

                  // TEXT SECTION (No longer overlapping the image)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? 'Tech Update',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF00F0FF) ) ),
                        const SizedBox(height: 10),
                        Text(
                          item['desc'] ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.5 ) ),
                      ] ) ),
                ] ) );
          } ) ) );
  }
}

// --- ANALYTICS SHEET (Pie Chart Theme) ---
class AnalyticsSheet extends StatefulWidget {
  const AnalyticsSheet({super.key});
  @override
  State<AnalyticsSheet> createState() => _AnalyticsSheetState();
}

class _AnalyticsSheetState extends State<AnalyticsSheet> with ScreenStateMixin {
  Map<String, double> genreStats = {};
  int touchedIndex = -1; // For touch interactions on the pie chart

  // --- THEME COLORS ---
  final Color kBgColor = const Color(0xFF0F0F1A); // Deeper dark blue
  final Color kPrimary = const Color(0xFF00F0FF); // Neon Cyan
  final Color kSecondary = const Color(0xFFFF0055); // Neon Pink
  final List<Color> kPieColors = [
    const Color(0xFF00F0FF), // Cyan
    const Color(0xFFFF0055), // Pink
    const Color(0xFFFFD700), // Gold
    const Color(0xFF9D00FF), // Purple
    const Color(0xFF00FF88), // Green
  ];

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    await handleApiState(
      cacheKey: 'analytics_reviews_cache',
      fetchData: () => HttpCacheService.get(Uri.parse(AppConstants.reviews)),
      onDataParsed: (decodedData) {
        if (decodedData is List) {
          List myReviews = decodedData
              .where((r) => r['user'] == "Mobile_User_1")
              .toList();
          Map<String, int> counts = {};
          for (var r in myReviews) {
            String genreString = r['genre'] ?? "General";
            List<String> genres = genreString
                .split(',')
                .map((e) => e.trim())
                .toList();
            for (var g in genres) {
              counts[g] = (counts[g] ?? 0) + 1;
            }
          }
          int total = counts.values.fold(0, (a, b) => a + b);
          genreStats = counts.map(
            (key, value) => MapEntry(key, total > 0 ? value / total : 0.0) );
        }
      } );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: kBgColor.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, -5) ),
        ] ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart, color: kPrimary, size: 28),
                const SizedBox(width: 10),
                Text(
                  "GENRE PREFERENCES",
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5 ) ),
              ] ),
            const SizedBox(height: 30),

            // Chart Content
            Expanded(
              child: buildScreenState(
                onRetry: _calculateStats,
                buildLoading: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00F0FF)) ),
                buildSuccess: () => genreStats.isEmpty
                    ? Center(
                        child: Text(
                          "No Data",
                          style: GoogleFonts.outfit(color: Colors.white54) ) )
                    : Row(
                        children: [
                          // Pie Chart Section
                          Expanded(
                            flex: 3,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback:
                                        (FlTouchEvent event, pieTouchResponse) {
                                          setState(() {
                                            if (!event
                                                    .isInterestedForInteractions ||
                                                pieTouchResponse == null ||
                                                pieTouchResponse
                                                        .touchedSection ==
                                                    null) {
                                              touchedIndex = -1;
                                              return;
                                            }
                                            touchedIndex = pieTouchResponse
                                                .touchedSection!
                                                .touchedSectionIndex;
                                          });
                                        } ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 4, // Space between sections
                                  centerSpaceRadius: 40, // Donut chart style
                                  sections: _showingSections() ) ) ) ),
                          const SizedBox(width: 20),
                          // Legend Section
                          Expanded(
                            flex: 2,
                            child: ListView(
                              children: genreStats.entries.map((e) {
                                final index = genreStats.keys.toList().indexOf(
                                  e.key );
                                final color =
                                    kPieColors[index % kPieColors.length];
                                final pct = (e.value * 100).toStringAsFixed(1);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle ) ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14 ) ) ),
                                      Text(
                                        "$pct%",
                                        style: GoogleFonts.outfit(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold ) ),
                                    ] ) );
                              }).toList() ) ),
                        ] ) ) ),
          ] ) ) );
  }

  List<PieChartSectionData> _showingSections() {
    return genreStats.entries.map((e) {
      final index = genreStats.keys.toList().indexOf(e.key);
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 20.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;
      final color = kPieColors[index % kPieColors.length];
      final pct = (e.value * 100).toStringAsFixed(0);

      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '$pct%',
        radius: radius,
        titleStyle: GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [const Shadow(color: Colors.black, blurRadius: 2)] ) );
    }).toList();
  }
}

// --- FEED SCREEN ---
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with ScreenStateMixin {
  List posts = [];
  final String currentUserId = "Mobile_User_1";

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    await handleApiState(
      cacheKey: 'feed_screen_posts',
      fetchData: () => HttpCacheService.get(Uri.parse(AppConstants.reviews)),
      onDataParsed: (decodedData) {
        if (decodedData is List) {
          posts = decodedData;
        }
      } );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreenState(
      onRetry: fetchPosts,
      buildLoading: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 80),
        itemCount: 3,
        itemBuilder: (_, _) => const FeedCardSkeleton() ),
      buildSuccess: () => RefreshIndicator(
        onRefresh: fetchPosts,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 80),
          itemCount: posts.length,
          separatorBuilder: (c, i) => const SizedBox(height: 30),
          itemBuilder: (context, index) =>
              MoviePostCard(post: posts[index], currentUserId: currentUserId) ) ) );
  }
}

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
  DateTime _lastRatingCall = DateTime(2000);

  @override
  void initState() {
    super.initState();
    List likedBy = widget.post['likedBy'] ?? [];
    isLiked = likedBy.contains(widget.currentUserId);
    likeCount = widget.post['likes'] ?? 0;
    currentRating = (widget.post['rating'] ?? 0).toDouble();
    comments = widget.post['commentsList'] ?? [];
  }

  Future<void> _updateRating(double newRating) async {
    // Throttle: ignore if called within 2s
    final now = DateTime.now();
    if (now.difference(_lastRatingCall).inSeconds < 2) return;
    _lastRatingCall = now;

    setState(() {
      currentRating = newRating;
    });

    try {
      await http.put(
        Uri.parse('${AppConstants.reviews}/${widget.post['_id']}/rate'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"rating": newRating}) );
    } catch (e) {
      debugPrint("Rating failed: $e");
    }
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
                  fontSize: 18,
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
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
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
                  final navigator = Navigator.of(context);
                  final url = Uri.parse(
                    '${AppConstants.reviews}/${widget.post['_id']}/comment' );
                  await http.post(
                    url,
                    headers: {"Content-Type": "application/json"},
                    body: json.encode({
                      "user": widget.currentUserId,
                      "text": commentController.text,
                    }) );
                  setState(() {
                    comments.add({
                      "user": widget.currentUserId,
                      "text": commentController.text,
                    });
                  });
                  navigator.pop();
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

  Widget _buildInteractiveStars() {
    return Row(
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => _updateRating((index + 1).toDouble()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              index < currentRating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 22 ) ) );
      }) );
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
              heroTag: widget.post['_id'] ) ) );
      },
      child: SizedBox(
        height: 520,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Main Card (Reverted to standard glow)
            Container(
              height: 480,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8) ),
                ] ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover, 
                      placeholder: (c, u) => Container(color: Colors.grey[900]),
                      errorWidget: (c, u, e) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.error) ) ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.9),
                          ] ) ) ),

                    // Interaction Layer
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movieTitle,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00F0FF),
                              fontSize: 26,
                              fontWeight: FontWeight.bold ) ),
                          const SizedBox(height: 10),
                          Text(
                            comment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16 ) ),
                          const SizedBox(height: 20),

                          // --- INTERACTION ROW ---
                          Row(
                            children: [
                              // Rating Stars
                              _buildInteractiveStars(),

                              const SizedBox(width: 15),

                              // Rating Stars
                              _buildInteractiveStars(),

                              const SizedBox(width: 15),

                              // Comments
                              GestureDetector(
                                onTap: _showCommentDialog,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      color: Colors.white,
                                      size: 22 ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${comments.length}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12 ) ),
                                  ] ) ),

                              const Spacer(),

                              // Share Button
                              GestureDetector(
                                onTap: _showShareSheet,
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 24 ) ),
                            ] ),
                        ] ) ),
                  ] ) ) ),
          ] ) ) );
  }
}

// =========================================================
// --- INSIGHT SCREEN (3D CAROUSEL + NAVIGATION) ---
// =========================================================
class InsightScreen extends StatefulWidget {
  const InsightScreen({super.key});

  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends State<InsightScreen>
    with AutomaticKeepAliveClientMixin<InsightScreen> {
  @override
  bool get wantKeepAlive => true; // keep alive when switching tabs
  List showing = [];
  List events = [];
  List buzz = [];
  List liveStreams = [
    {
      'title': 'Pushpa 2 Trailer Launch - LIVE from Hyderabad',
      'host': 'Mythri Movie Makers',
      'viewers': '142K',
      'likes': '89K',
      'comments': '12K',
      'thumbnailUrl': 'https://picsum.photos/seed/pushpalive/400/225',
      'hostAvatar': 'https://picsum.photos/seed/mythri/100/100',
      'videoId': '1ZNgOGO1Lio',
    },
    {
      'title': 'SSMB 29 Press Meet - S.S. Rajamouli',
      'host': 'Telugu FilmNagar',
      'viewers': '85K',
      'likes': '45K',
      'comments': '8.5K',
      'thumbnailUrl': 'https://picsum.photos/seed/ssmb29live/400/225',
      'hostAvatar': 'https://picsum.photos/seed/tfn/100/100',
      'videoId': '8X2kIfS6fb8',
    },
    {
      'title': 'Devara Pre-Release Event - LIVE',
      'host': 'NTR Arts',
      'viewers': '210K',
      'likes': '150K',
      'comments': '45K',
      'thumbnailUrl': 'https://picsum.photos/seed/devaralive/400/225',
      'hostAvatar': 'https://picsum.photos/seed/ntrarts/100/100',
      'videoId': 'qNnVb8E5a5M',
    },
  ];
  bool isLoading = true;
  String _accountType = 'User';
  Timer? _livestreamPollTimer;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.7);
    // Removed the global setState listener to prevent full screen rebuilds
    fetchHubData();
    _loadAccountType();

    // Periodically fetch active user streams in real-time every 30 seconds
    _livestreamPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchLiveStreamsOnly();
      }
    });
  }

  Future<void> _loadAccountType() async {
    final type = await CacheUtility.getProfileValue('accountType');
    if (type != null && mounted) {
      setState(() => _accountType = type);
    }
  }

  void _loadAccountTypeIfNeeded() {
    CacheUtility.getProfileValue('accountType').then((type) {
      final newType = type ?? 'User';
      if (newType != _accountType && mounted) {
        setState(() => _accountType = newType);
      }
    });
  }

  @override
  void dispose() {
    _livestreamPollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveStreamsOnly() async {
    try {
      List userStreams = [];
      try {
        final liveResponse = await HttpCacheService.get(
          Uri.parse('${AppConstants.hub}/livestreams'),
          forceRefresh: true );
        if (liveResponse.statusCode == 200) {
          userStreams = json.decode(liveResponse.body);
        }
      } catch (e) {
        debugPrint('Failed to load active livestreams in background: $e');
        return; // don't overwrite with old data if API failed
      }

      final List mockStreams = [
        {
          'title': 'Pushpa 2 Trailer Launch - LIVE from Hyderabad',
          'host': 'Mythri Movie Makers',
          'viewers': '142K',
          'likes': '89K',
          'comments': '12K',
          'thumbnailUrl': 'https://picsum.photos/seed/pushpalive/400/225',
          'hostAvatar': 'https://picsum.photos/seed/mythri/100/100',
          'videoId': '1ZNgOGO1Lio',
        },
        {
          'title': 'SSMB 29 Press Meet - S.S. Rajamouli',
          'host': 'Telugu FilmNagar',
          'viewers': '85K',
          'likes': '45K',
          'comments': '8.5K',
          'thumbnailUrl': 'https://picsum.photos/seed/ssmb29live/400/225',
          'hostAvatar': 'https://picsum.photos/seed/tfn/100/100',
          'videoId': '8X2kIfS6fb8',
        },
        {
          'title': 'Devara Pre-Release Event - LIVE',
          'host': 'NTR Arts',
          'viewers': '210K',
          'likes': '150K',
          'comments': '45K',
          'thumbnailUrl': 'https://picsum.photos/seed/devaralive/400/225',
          'hostAvatar': 'https://picsum.photos/seed/ntrarts/100/100',
          'videoId': 'qNnVb8E5a5M',
        },
      ];

      final combined = [...userStreams, ...mockStreams];

      if (mounted && json.encode(liveStreams) != json.encode(combined)) {
        setState(() {
          liveStreams = combined;
        });
      }
    } catch (e) {
      debugPrint('Background livestream fetch error: $e');
    }
  }

  Future<void> fetchHubData() async {
    try {
      // 1. Fetch active user streams from live server (forceRefresh is true for real-time bypass)
      List userStreams = [];
      try {
        final liveResponse = await HttpCacheService.get(
          Uri.parse('${AppConstants.hub}/livestreams'),
          forceRefresh: true );
        if (liveResponse.statusCode == 200) {
          userStreams = json.decode(liveResponse.body);
        }
      } catch (e) {
        debugPrint('Failed to load active livestreams: $e');
      }

      // 2. Fetch showing and events
      final response = await HttpCacheService.get(Uri.parse(AppConstants.hub));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            showing = data['showing'] ?? [];
            events = data['events'] ?? [];

            // CORS-friendly movie event images (picsum.photos sends Access-Control-Allow-Origin: *)
            final List<String> eventImages = [
              'https://picsum.photos/seed/ssmb29/400/600',
              'https://picsum.photos/seed/vishwambhara/400/600',
              'https://picsum.photos/seed/pushpa2/400/600',
              'https://picsum.photos/seed/salaar2/400/600',
              'https://picsum.photos/seed/devara/400/600',
              'https://picsum.photos/seed/kalki/400/600',
            ];

            // If events is empty, add mock events with images
            if (events.isEmpty) {
              events = [
                {
                  'title': 'SSMB 29 (Rajamouli)',
                  'event': 'GLOBAL GLIMPSE REVEAL',
                  'dateLocation': 'Jan 08 \u2022 Tokyo / Online',
                  'imageUrl': eventImages[0],
                  'color': '4278255615',
                  'statusColor': '4278255615',
                },
                {
                  'title': 'Vishwambhara',
                  'event': 'MASS RELEASE DAY',
                  'dateLocation': 'Jan 10 \u2022 Worldwide',
                  'imageUrl': eventImages[1],
                  'color': '4294953728',
                  'statusColor': '4294953728',
                },
                {
                  'title': 'Pushpa 2 Premiere',
                  'event': 'RED CARPET EVENT',
                  'dateLocation': 'Jan 15 \u2022 Hyderabad',
                  'imageUrl': eventImages[2],
                  'color': '4294961664',
                  'statusColor': '4294961664',
                },
              ];
            } else {
              // Always override image URLs – external URLs are CORS-blocked on web
              for (int i = 0; i < events.length; i++) {
                events[i]['imageUrl'] = eventImages[i % eventImages.length];
              }
            }

            buzz = data['buzz'] ?? [];

            final List mockStreams = [
              {
                'title': 'Pushpa 2 Trailer Launch - LIVE from Hyderabad',
                'host': 'Mythri Movie Makers',
                'viewers': '142K',
                'likes': '89K',
                'comments': '12K',
                'thumbnailUrl': 'https://picsum.photos/seed/pushpalive/400/225',
                'hostAvatar': 'https://picsum.photos/seed/mythri/100/100',
                'videoId': '1ZNgOGO1Lio',
              },
              {
                'title': 'SSMB 29 Press Meet - S.S. Rajamouli',
                'host': 'Telugu FilmNagar',
                'viewers': '85K',
                'likes': '45K',
                'comments': '8.5K',
                'thumbnailUrl': 'https://picsum.photos/seed/ssmb29live/400/225',
                'hostAvatar': 'https://picsum.photos/seed/tfn/100/100',
                'videoId': '8X2kIfS6fb8',
              },
              {
                'title': 'Devara Pre-Release Event - LIVE',
                'host': 'NTR Arts',
                'viewers': '210K',
                'likes': '150K',
                'comments': '45K',
                'thumbnailUrl': 'https://picsum.photos/seed/devaralive/400/225',
                'hostAvatar': 'https://picsum.photos/seed/ntrarts/100/100',
                'videoId': 'qNnVb8E5a5M',
              },
            ];

            liveStreams = [...userStreams, ...mockStreams];
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      // If API fails, use mock data with images
      if (mounted) {
        setState(() {
          events = [
            {
              'title': 'SSMB 29 (Rajamouli)',
              'event': 'GLOBAL GLIMPSE REVEAL',
              'dateLocation': 'Jan 08 \u2022 Tokyo / Online',
              'imageUrl': 'https://picsum.photos/seed/ssmb29/400/600',
              'color': '4278255615',
              'statusColor': '4278255615',
            },
            {
              'title': 'Vishwambhara',
              'event': 'MASS RELEASE DAY',
              'dateLocation': 'Jan 10 \u2022 Worldwide',
              'imageUrl': 'https://picsum.photos/seed/vishwambhara/400/600',
              'color': '4294953728',
              'statusColor': '4294953728',
            },
            {
              'title': 'Pushpa 2 Premiere',
              'event': 'RED CARPET EVENT',
              'dateLocation': 'Jan 15 \u2022 Hyderabad',
              'imageUrl': 'https://picsum.photos/seed/pushpa2/400/600',
              'color': '4294961664',
              'statusColor': '4294961664',
            },
          ];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _loadAccountTypeIfNeeded();
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F0FF)) );
    }

    return RefreshIndicator(
      onRefresh: fetchHubData,
      color: const Color(0xFF00F0FF),
      backgroundColor: Colors.black,
      child: Scrollbar(
        thumbVisibility: true,
        radius: const Radius.circular(10),
        child: CustomScrollView(
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. HEADER
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF00F0FF).withValues(alpha: 0.15),
                      Colors.transparent,
                    ] ) ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "VIRTUAL",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white54,
                        letterSpacing: 4 ) ),
                    Text(
                      "CINEMA POINT",
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0 ) ),
                  ] ) ) ),

            // 1.5 LIVE STREAMS SECTION
            if (liveStreams.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors, color: Color(0xFFFF0055)),
                          const SizedBox(width: 8),
                          Text(
                            "LIVE NOW",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white ) ),
                          const Spacer(),
                          const PulsingLiveBadge(),
                        ] ) ),

                    // Go Live button — only for certified creators
                    if (_accountType == 'Production House' ||
                        _accountType == 'Event Manager' ||
                        _accountType == 'Certified User')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GoLiveScreen() ) );
                            },
                            icon: const Icon(Icons.videocam_rounded, size: 18),
                            label: Text(
                              'Go Live',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15 ) ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF0055),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14) ),
                              elevation: 0 ) ) ) )
                    else
                      const SizedBox(height: 15),

                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: liveStreams.length,
                        itemBuilder: (context, index) {
                          final stream = liveStreams[index];
                          return _LiveStreamCard(stream: stream);
                        } ) ),
                  ] ) ),

            // 2. TRENDING TITLE
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10 ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.amber ),
                    const SizedBox(width: 8),
                    Text(
                      "TRENDING NOW",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white ) ),
                  ] ) ) ),

            // 3. CAROUSEL
            SliverToBoxAdapter(
              child: showing.isEmpty
                  ? const Center(
                      child: Text(
                        "No movies showing",
                        style: TextStyle(color: Colors.white54) ) )
                  : SizedBox(
                      height: 380,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: showing.length,
                        itemBuilder: (context, index) {
                          final item = showing[index];
                          final Color statusColor = () {
                            try {
                              return Color(int.parse(item['statusColor']));
                            } catch (e) {
                              return Colors.amber;
                            }
                          }();

                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 0;
                              if (_pageController.position.haveDimensions) {
                                value = index - (_pageController.page ?? 0);
                                value = (1 - (value.abs() * 0.3)).clamp(
                                  0.0,
                                  1.0 );
                              } else {
                                value = index == 0 ? 1.0 : 0.7;
                              }

                              return Center(
                                child: SizedBox(
                                  height: Curves.easeOut.transform(value) * 380,
                                  width: Curves.easeOut.transform(value) * 280,
                                  child: GestureDetector(
                                    onTap: () {
                                      Map movieData = {
                                        "movieTitle": item['title'],
                                        "posterUrl": item['imageUrl'],
                                        "rating": item['rating'] ?? 4.5,
                                        "genre": item['genre'] ?? "Trending",
                                        "synopsis":
                                            item['synopsis'] ??
                                            "No synopsis available yet.",
                                        "budget": item['budget'] ?? "N/A",
                                        "boxOffice": item['boxOffice'] ?? "N/A",
                                        "runtime": item['runtime'] ?? "2h 30m",
                                        "cast": item['cast'] ?? [],
                                      };
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (c) =>
                                              CinematicDetailsScreen(
                                                movie: movieData,
                                                heroTag: item['title'] ) ) );
                                    },
                                    child: _CarouselCard(
                                      item: item,
                                      statusColor: statusColor,
                                      scaleValue: value ) ) ) );
                            } );
                        } ) ) ),

            // 4. LIVE EVENTS TITLE
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Color(0xFFFF0055)),
                    const SizedBox(width: 8),
                    Text(
                      "LIVE EVENTS",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white ) ),
                  ] ) ) ),

            // 5. EVENTS LIST
            if (events.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    "No events scheduled",
                    style: TextStyle(color: Colors.white24) ) ) )
            else
              SliverToBoxAdapter(
                child: Container(
                  height: 320,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final e = events[index];
                      return _HorizontalEventCard(
                        title: e['title'],
                        event: e['event'],
                        date: e['dateLocation'],
                        color: Color(int.parse(e['color'])),
                        imageUrl: e['imageUrl'] );
                    } ) ) ),

            // BOTTOM PADDING
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ] ) ) );
  }
}

class _CarouselCard extends StatelessWidget {
  final Map item;
  final Color statusColor;
  final double scaleValue;

  const _CarouselCard({
    required this.item,
    required this.statusColor,
    required this.scaleValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.4 * scaleValue),
            blurRadius: 20,
            spreadRadius: 2 ),
        ] ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item['imageUrl'],
              fit: BoxFit.cover, 
              placeholder: (c, u) => Container(color: Colors.grey[900]) ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.6, 1.0] ) ) ),
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Opacity(
                opacity: scaleValue > 0.8 ? 1.0 : 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4 ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8) ),
                      child: Text(
                        item['status'].toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10 ) ) ),
                  ] ) ) ),
          ] ) ) );
  }
}

class _HorizontalEventCard extends StatelessWidget {
  final String title, event, date, imageUrl;
  final Color color;

  const _HorizontalEventCard({
    required this.title,
    required this.event,
    required this.date,
    required this.color,
    required this.imageUrl,
  });

  Future<void> _launchShreyasEvents(BuildContext context) async {
    final Uri url = Uri.parse('https://www.shreyasgroup.net/event');
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open Shreyas Events website'),
          backgroundColor: Colors.red ) );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _launchShreyasEvents(context),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 24, bottom: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 12) ),
          ] ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // 1. FULL BACKGROUND IMAGE
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,  
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF12121A),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00F0FF),
                        strokeWidth: 2 ) ) ),
                  errorWidget: (context, url, error) {
                    debugPrint('Event image error: $error');
                    return Container(
                      color: const Color(0xFF12121A),
                      child: Icon(
                        Icons.event,
                        color: color.withValues(alpha: 0.3),
                        size: 60 ) );
                  } ) ),

              // 2. GRADIENT OVERLAY FOR TEXT READABILITY
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.5, 1.0] ) ) ) ),

              // 3. GRADIENT BORDER
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      width: 2,
                      color: color.withValues(alpha: 0.4) ) ) ) ),

              // 4. ANIMATED LIVE BADGE
              Positioned(
                top: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6 ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.7),
                          width: 1.5 ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2 ),
                        ] ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color,
                                  blurRadius: 6,
                                  spreadRadius: 2 ),
                              ] ) ),
                          const SizedBox(width: 6),
                          Text(
                            "LIVE",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2 ) ),
                        ] ) ) ) ) ),

              // 5. CONTENT AT BOTTOM
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Event Type Label
                      Text(
                        event.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5 ) ),
                      const SizedBox(height: 6),

                      // Event Title
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2 ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis ),
                      const SizedBox(height: 8),

                      // Date/Location with Icon
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.7) ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              date,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500 ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis ) ),
                        ] ),
                      const SizedBox(height: 14),

                      // BOOK NOW BUTTON
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withValues(alpha: 0.8),
                                  color.withValues(alpha: 0.6),
                                ] ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                                width: 1.5 ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4) ),
                              ] ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _launchShreyasEvents(context),
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.confirmation_number_rounded,
                                        color: Colors.white,
                                        size: 18 ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'BOOK NOW',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2 ) ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 16 ),
                                    ] ) ) ) ) ) ) ),
                    ] ) ) ),
            ] ) ) ) );
  }
}

class _LiveStreamCard extends StatelessWidget {
  final Map stream;

  const _LiveStreamCard({required this.stream});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (stream['isLiveUserStream'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LiveStreamViewerScreen(
                streamId: stream['id'],
                title: stream['title'],
                host: stream['host'],
                hostAvatar: stream['hostAvatar'] ) ) );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LiveVideoPlayerScreen(stream: stream) ) );
        }
      },
      child: Container(
        width: 280,
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A24),
        border: Border.all(
          color: const Color(0xFFFF0055).withValues(alpha: 0.3),
          width: 1 ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0055).withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2 ),
        ] ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with LIVE and Viewers badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: stream['thumbnailUrl'],
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover, 
                  placeholder: (c, u) => Container(height: 150, color: Colors.grey[900]),
                  errorWidget: (c, u, e) => Container(height: 150, color: Colors.grey[900]) ) ),
              // Play button overlay
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2) ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30) ) ) ),
              // LIVE Badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0055),
                    borderRadius: BorderRadius.circular(6) ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        "LIVE",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold) ),
                    ] ) ) ),
              // Viewers Badge
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6) ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        stream['viewers'],
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold) ),
                    ] ) ) ),
            ] ),
          
          // Info Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: CachedNetworkImageProvider(stream['hostAvatar']),
                  backgroundColor: Colors.grey[800] ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stream['title'],
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis ),
                      const SizedBox(height: 4),
                      Text(
                        stream['host'],
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 12 ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.thumb_up_alt_rounded, color: Color(0xFFFF4D8B), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            stream['likes'],
                            style: GoogleFonts.sourceCodePro(color: Colors.white70, fontSize: 11) ),
                          const SizedBox(width: 12),
                          const Icon(Icons.chat_bubble_rounded, color: Color(0xFF00F0FF), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            stream['comments'],
                            style: GoogleFonts.sourceCodePro(color: Colors.white70, fontSize: 11) ),
                        ] ),
                    ] ) ),
              ] ) ),
        ] ) ) );
  }
}

// --- SIDE MENU DRAWER ---
class SideMenuDrawer extends StatefulWidget {
  const SideMenuDrawer({super.key});

  @override
  State<SideMenuDrawer> createState() => _SideMenuDrawerState();
}

class _SideMenuDrawerState extends State<SideMenuDrawer> {
  // User identity
  String _name = '';
  String _handle = '';
  String _avatarUrl = '';
  String _bio = '';
  bool _isVerified = false;

  // Stats (fetched from API)
  int _postsCount = 0;
  int _bookmarksCount = 0;
  int _followingCount = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Load user identity from SharedPreferences Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Future<void> _loadUser() async {
    final name = await CacheUtility.getProfileValue('name') ?? 'CineUser';
    final handle = await CacheUtility.getProfileValue('handle') ?? '@cineuser';
    final avatar = await CacheUtility.getProfileValue('avatar') ?? '';
    final bio = await CacheUtility.getProfileValue('bio') ?? '';
    final verified = await CacheUtility.isUserVerified();

    if (mounted) {
      setState(() {
        _name = name;
        _handle = handle;
        _avatarUrl = avatar;
        _bio = bio;
        _isVerified = verified;
      });
    }

    // Then fetch fresh data + stats from backend
    _fetchProfileAndStats(handle);
  }

  Future<void> _fetchProfileAndStats(String handle) async {
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('${AppConstants.me}/$handle'))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse(AppConstants.posts))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse('$baseUrl/api/users/$handle/following'))
            .timeout(const Duration(seconds: 6)),
      ]);

      // Profile
      if (results[0].statusCode == 200) {
        final data = json.decode(results[0].body);
        if (mounted) {
          setState(() {
            _name = data['name'] ?? _name;
            _handle = data['handle'] ?? _handle;
            _avatarUrl = data['avatar'] ?? _avatarUrl;
            _bio = data['bio'] ?? _bio;
            _isVerified = data['isVerified'] ?? _isVerified;
          });
          // Keep cache in sync
          await CacheUtility.saveProfileData({
            'name': _name,
            'handle': _handle,
            'avatar': _avatarUrl,
            'bio': _bio,
          });
        }
      }

      // Posts Ã¢â€ â€™ count mine
      if (results[1].statusCode == 200) {
        final List posts = json.decode(results[1].body);
        final mine = posts
            .where((p) => p['userHandle'] == handle || p['user'] == handle)
            .length;
        final bmk = posts.where((p) {
          final bb = p['bookmarkedBy'] as List? ?? [];
          return bb.contains(handle);
        }).length;
        if (mounted) {
          setState(() {
            _postsCount = mine;
            _bookmarksCount = bmk;
          });
        }
      }

      // Following
      if (results[2].statusCode == 200) {
        final data = json.decode(results[2].body);
        final List following = data['following'] ?? [];
        if (mounted) {
          setState(() {
            _followingCount = following.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Drawer stats error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _statsLoading = false;
        });
      }
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Logout Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Logged out successfully', style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFFFF0055),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) ) );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Navigate helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showSheet(BuildContext context, Widget sheet) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet );
  }

  void _comingSoon(BuildContext ctx) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text('Coming soon!', style: GoogleFonts.outfit()),
      backgroundColor: const Color(0xFF1A1A2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) ) );

  void _confirmDelete(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0F0F1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Delete Account',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold ) ),
      content: Text(
        'This action is irreversible. All your posts, reviews and data will be permanently deleted.',
        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14) ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cancel',
            style: GoogleFonts.outfit(color: Colors.white54) ) ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _comingSoon(ctx);
          },
          child: Text('Delete', style: GoogleFonts.outfit(color: Colors.red)) ),
      ] ) );

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      _DrawerItem(
        icon: Icons.person_rounded,
        label: 'Profile',
        gradient: [const Color(0xFF00F0FF), const Color(0xFF0055FF)],
        onTap: () => _go(
          context,
          Scaffold(
            backgroundColor: const Color(0xFF050510),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                'PROFILE',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold ) ) ),
            body: const ProfileScreen() ) ) ),
      _DrawerItem(
        icon: Icons.smart_toy_rounded,
        label: 'Guess the Movie',
        gradient: [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
        onTap: () => _go(
          context,
          Scaffold(
            backgroundColor: const Color(0xFF050510),
            body: const GuessMovieGameScreen() ) ) ),
      _DrawerItem(
        icon: Icons.bar_chart_rounded,
        label: 'Statistics',
        gradient: [const Color(0xFF00C896), const Color(0xFF00F0FF)],
        onTap: () => _showSheet(context, const AnalyticsSheet()) ),
      _DrawerItem(
        icon: Icons.manage_accounts_rounded,
        label: 'Account',
        gradient: [const Color(0xFF9D00FF), const Color(0xFFFF00FF)],
        children: [
          _DrawerSubItem(
            label: 'Personal Information',
            onTap: () => _go(
              context,
              const SimplePage(
                title: 'Personal Info',
                content:
                    'Update your email, phone number, and personal details.' ) ) ),
          _DrawerSubItem(
            label: 'Password & Security',
            onTap: () => _go(context, const AccountSecuritySettingsScreen()) ),
          _DrawerSubItem(
            label: 'Verification Request',
            onTap: () => _go(
              context,
              const SimplePage(
                title: 'Verification',
                content: 'Apply for the coveted Platinum verification badge.' ) ) ),
          _DrawerSubItem(
            label: 'Deactivation & Deletion',
            onTap: () => _confirmDelete(context) ),
        ] ),
      _DrawerItem(
        icon: Icons.shield_rounded,
        label: 'Privacy & Safety',
        gradient: [const Color(0xFFFF0055), const Color(0xFFFF6B9D)],
        children: [
          _DrawerSubItem(
            label: 'Private Account',
            onTap: () => _go(context, const PrivacySafetySettingsScreen()) ),
          _DrawerSubItem(
            label: 'Blocked Users',
            onTap: () => _go(context, const PrivacySafetySettingsScreen()) ),
          _DrawerSubItem(
            label: 'Story Privacy',
            onTap: () => _go(context, const PrivacySafetySettingsScreen()) ),
          _DrawerSubItem(
            label: 'Mentions & Tags',
            onTap: () => _go(context, const PrivacySafetySettingsScreen()) ),
        ] ),
      _DrawerItem(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        gradient: [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
        children: [
          _DrawerSubItem(
            label: 'Push Notifications',
            onTap: () => _go(context, const NotificationSettingsScreen()) ),
          _DrawerSubItem(
            label: 'Email Notifications',
            onTap: () => _go(context, const NotificationSettingsScreen()) ),
          _DrawerSubItem(
            label: 'Quiet Mode',
            onTap: () => _go(context, const NotificationSettingsScreen()) ),
        ] ),
      _DrawerItem(
        icon: Icons.display_settings_rounded,
        label: 'Content & Display',
        gradient: [const Color(0xFF00F0FF), const Color(0xFF00C896)],
        children: [
          _DrawerSubItem(
            label: 'Theme, Auto-play & Display',
            onTap: () => _go(context, const ContentDisplaySettingsScreen()) ),
          _DrawerSubItem(
            label: 'Data Saver',
            onTap: () => _go(context, const ContentDisplaySettingsScreen()) ),
          _DrawerSubItem(
            label: 'Language',
            onTap: () => _go(context, const ContentDisplaySettingsScreen()) ),
        ] ),
      _DrawerItem(
        icon: Icons.help_rounded,
        label: 'Help & About',
        gradient: [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
        children: [
          _DrawerSubItem(
            label: 'Help Center',
            onTap: () => _go(
              context,
              const SimplePage(
                title: 'Help Center',
                content: 'Need assistance? Email support@cinesocial.com.' ) ) ),
          _DrawerSubItem(
            label: 'Report a Problem',
            onTap: () => _go(
              context,
              const SimplePage(
                title: 'Report Problem',
                content:
                    'Shake your phone to report a bug, or contact us directly.' ) ) ),
          _DrawerSubItem(
            label: 'Terms of Service',
            onTap: () => _go(
              context,
              const SimplePage(
                title: 'Terms of Service',
                content:
                    'By using CineSocial, you agree to our community guidelines.' ) ) ),
          _DrawerSubItem(
            label: 'Privacy Policy',
            onTap: () => _go(
              context,
              const SimplePage(
                title: 'Privacy Policy',
                content:
                    'We protect your data and never sell it to third parties.' ) ) ),
        ] ),
    ];

    return Drawer(
      backgroundColor: Colors.transparent,
      width: 290,
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF0A0A14)),
        child: Column(
          children: [
            _buildHeader(context),
            Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xFF00F0FF),
                    Colors.transparent,
                  ] ) ) ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                itemCount: menuItems.length,
                itemBuilder: (ctx, i) => _buildMenuTile(ctx, menuItems[i]) ) ),
            // Logout button
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF0055).withValues(alpha: 0.13),
                    const Color(0xFFFF0055).withValues(alpha: 0.06),
                  ] ),
                border: Border.all(
                  color: const Color(0xFFFF0055).withValues(alpha: 0.35),
                  width: 1 ) ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _logout(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14 ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFFFF0055 ).withValues(alpha: 0.15) ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFFF0055),
                            size: 18 ) ),
                        const SizedBox(width: 14),
                        Text(
                          'Log Out',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFF0055),
                            fontWeight: FontWeight.w600,
                            fontSize: 15 ) ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFFFF0055),
                          size: 14 ),
                      ] ) ) ) ) ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'v1.0.0  â€¢  CineSocial',
                style: GoogleFonts.outfit(
                  color: Colors.white24,
                  fontSize: 11,
                  letterSpacing: 1 ) ) ),
          ] ) ) );
  }

  Widget _buildHeader(BuildContext context) {
    final imageProvider = CacheUtility.getAvatarProvider(
      _avatarUrl.isNotEmpty ? _avatarUrl : null );

    return GestureDetector(
      onTap: () => _go(
        context,
        Scaffold(
          backgroundColor: const Color(0xFF050510),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'PROFILE',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold ) ) ),
          body: const ProfileScreen() ) ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 24,
          left: 24,
          right: 24,
          bottom: 24 ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0035), Color(0xFF000D2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight ) ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F0FF), Color(0xFFFF0055)] ) ),
              child: Text(
                'CINESOCIAL',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2 ) ) ),
            const SizedBox(height: 20),

            // Avatar with glow
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.45),
                        blurRadius: 22,
                        spreadRadius: 4 ),
                    ] ) ),
                Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00F0FF), Color(0xFFFF0055)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight ) ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => CachedNetworkImage(
                        imageUrl: 'https://i.pravatar.cc/150?img=12',
                        fit: BoxFit.cover ) ) ) ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00C896),
                      border: Border.all(
                        color: const Color(0xFF0A0A14),
                        width: 2.5 ) ) ) ),
              ] ),
            const SizedBox(height: 14),

            // Name + verified
            Row(
              children: [
                Expanded(
                  child: Text(
                    _name.isEmpty ? 'Loading...' : _name,
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white ),
                    overflow: TextOverflow.ellipsis ) ),
                if (_isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF00F0FF),
                      size: 18 ) ),
              ] ),
            const SizedBox(height: 2),
            Text(
              _handle,
              style: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500 ) ),
            const SizedBox(height: 8),

            // Level badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3 ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)] ) ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 11 ),
                      const SizedBox(width: 3),
                      Text(
                        'PLATINUM',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1 ) ),
                    ] ) ),
                const SizedBox(width: 8),
                Text(
                  'CineCinephile',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12 ) ),
              ] ),
            const SizedBox(height: 16),

            // Stats
            _statsLoading
                ? Row(children: List.generate(3, (_) => _shimmerChip()))
                : Row(
                    children: [
                      _statChip(_postsCount.toString(), 'Posts'),
                      const SizedBox(width: 16),
                      _statChip(_bookmarksCount.toString(), 'Saved'),
                      const SizedBox(width: 16),
                      _statChip(_followingCount.toString(), 'Following'),
                    ] ),
          ] ) ) );
  }

  Widget _statChip(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold ) ),
      Text(
        label,
        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10) ),
    ] );

  Widget _shimmerChip() => Padding(
    padding: const EdgeInsets.only(right: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4) ) ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4) ) ),
      ] ) );

  Widget _buildMenuTile(BuildContext ctx, _DrawerItem item) {
    final bool hasChildren = item.children != null && item.children!.isNotEmpty;

    final headerChild = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: item.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight ),
            boxShadow: [
              BoxShadow(
                color: item.gradient.first.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3) ),
            ] ),
          child: Icon(item.icon, color: Colors.white, size: 20) ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            item.label,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500 ) ) ),
        if (!hasChildren)
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white24,
            size: 20 ),
      ] );

    if (hasChildren) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.04) ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: item.gradient.first.withValues(alpha: 0.15),
            highlightColor: item.gradient.first.withValues(alpha: 0.08) ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4 ),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white24,
            title: headerChild,
            children: item.children!.map((subItem) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: subItem.onTap,
                  splashColor: item.gradient.first.withValues(alpha: 0.15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12 ),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: item.gradient.first.withValues(alpha: 0.5),
                          width: 2 ) ) ),
                    margin: const EdgeInsets.only(
                      left: 34,
                      right: 14,
                      bottom: 4 ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            subItem.label,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w400 ) ) ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white24,
                          size: 12 ),
                      ] ) ) ) );
            }).toList() ) ) );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04) ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: item.onTap,
          splashColor: item.gradient.first.withValues(alpha: 0.15),
          highlightColor: item.gradient.first.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: headerChild ) ) ) );
  }
}

// â”€â”€ Helper data classes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _DrawerItem {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final List<_DrawerSubItem>? children;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.gradient,
    this.onTap,
    this.children,
  });
}

class _DrawerSubItem {
  final String label;
  final VoidCallback onTap;

  const _DrawerSubItem({required this.label, required this.onTap});
}

// â”€â”€ Settings Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SettingsPage extends StatefulWidget {
  const _SettingsPage();
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _notificationsOn = true;
  bool _darkMode = true;
  bool _autoPlay = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'SETTINGS',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5 ) ),
        centerTitle: true ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel('Preferences'),
          _toggleTile(
            icon: Icons.notifications_rounded,
            iconColor: const Color(0xFFFFD700),
            label: 'Push Notifications',
            sublabel: 'Alerts for likes, comments & more',
            value: _notificationsOn,
            onChanged: (v) => setState(() => _notificationsOn = v) ),
          _toggleTile(
            icon: Icons.dark_mode_rounded,
            iconColor: const Color(0xFF9D00FF),
            label: 'Dark Mode',
            sublabel: 'Switch between light and dark themes',
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v) ),
          _toggleTile(
            icon: Icons.play_circle_rounded,
            iconColor: const Color(0xFF00C896),
            label: 'Auto-play Trailers',
            sublabel: 'Automatically play trailers in feed',
            value: _autoPlay,
            onChanged: (v) => setState(() => _autoPlay = v) ),
        ] ) );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5 ) ) );

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white.withValues(alpha: 0.05),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)) ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: iconColor.withValues(alpha: 0.15) ),
          child: Icon(icon, color: iconColor, size: 20) ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500 ) ),
              Text(
                sublabel,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11) ),
            ] ) ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF00F0FF),
          activeTrackColor: const Color(0xFF00F0FF).withValues(alpha: 0.3) ),
      ] ) );
}

// --- GENERIC SIMPLE PAGE ---

class SimplePage extends StatelessWidget {
  final String title;
  final String content;

  const SimplePage({
    super.key,
    required this.title,
    this.content = "Content coming soon...",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context) ),
        title: Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5 ) ),
        centerTitle: true ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(
                  Icons.settings_suggest_outlined, // Generic icon
                  size: 80,
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.5) ) ),
              const SizedBox(height: 30),
              Text(
                content,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5 ) ),
            ] ) ) ) );
  }
}
