import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'utils.dart';
import 'services/http_cache_service.dart';
import 'qr_payment_screen.dart';
import 'widgets/social_feed_card.dart';
import 'theme_provider.dart'; // [New] Theme Provider
import 'movie_info_screen.dart';
import 'hero_movie_info_screen.dart';
import 'buzz_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets/shimmer_loader.dart';
import 'widgets/screen_state_mixin.dart';
import 'package:flutter_application_1/constants.dart';

class ProfileScreen extends StatefulWidget {
  final String? userHandle; // If null, means local user
  final String? initialName;
  final String? initialAvatar;

  const ProfileScreen({super.key, this.userHandle, this.initialName, this.initialAvatar});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, ScreenStateMixin, AutomaticKeepAliveClientMixin<ProfileScreen> {
  @override
  bool get wantKeepAlive => true;
  late TabController _tabController;

  // Profile data
  String _displayName = 'CineUser';
  String _handle = '@cineuser';
  String _localHandle = ''; // Used to check if we're viewing our own profile
  String _bio =
      'Movie buff 🎬 | Telugu Cinema Fan ❤️ | Reviews & Theatre Vibes';
  String _avatarUrl = '';
  final String _joinDate = 'Joined January 2025';
  String _dob = 'Not set';
  String _gender = 'Not set';
  String _accountType = 'User';
  String _licenseNumber = '';

  // Stats
  int _followersCount = 1247;
  int _followingCount = 342;
  bool _isFollowing = false;
  bool _isVerified = false;

  // Content lists (mock data)
  List<Map<String, dynamic>> _myPosts = [];
  List<Map<String, dynamic>> _likedPosts = [];
  List<Map<String, dynamic>> _myComments = [];
  List<Map<String, dynamic>> _sharedPosts = [];
  List<Map<String, dynamic>> _bookmarkedPosts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _displayName = widget.initialName ?? 'CineUser';
    _avatarUrl = widget.initialAvatar ?? 'https://i.pravatar.cc/300?img=12';
    if (widget.userHandle != null) _handle = widget.userHandle!;
    _checkVerification();
    _loadProfileData().then((_) => fetchAllData());
    // Check follow status independently so it always runs,
    // even when _loadProfileData() returns early after a successful profile fetch.
    _checkFollowStatus();
  }

  Future<void> _loadProfileData() async {
    final localH = await CacheUtility.getProfileValue('handle') ?? '@cineuser';
    _localHandle = localH;
    final targetHandle = widget.userHandle ?? localH;

    final targetIsOwn = widget.userHandle == null || widget.userHandle == localH;
    final expectedLength = targetIsOwn ? 6 : 2;
    if (mounted && _tabController.length != expectedLength) {
      setState(() {
        _tabController.dispose();
        _tabController = TabController(length: expectedLength, vsync: this);
      });
    }

    // 1. Try to load from backend first
    try {
      final response = await http
          .get(Uri.parse('${AppConstants.me}/$targetHandle'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            final fetchedName = data['name'];
            if (fetchedName != null && fetchedName != 'Unknown User' && fetchedName != 'CineSocial User') {
              _displayName = fetchedName;
            } else {
               _displayName = widget.initialName ?? fetchedName ?? 'Unknown User';
            }
            
            _handle = data['handle'] ?? targetHandle;
            _bio = data['bio'] ?? '';
            
            final fetchedAvatar = data['avatar'];
            if (fetchedAvatar != null && fetchedAvatar.isNotEmpty) {
               _avatarUrl = fetchedAvatar;
            } else {
               _avatarUrl = widget.initialAvatar ?? 'https://i.pravatar.cc/300?img=12';
            }
            
            _dob = data['dob'] ?? '';
            _gender = data['gender'] ?? '';
            _accountType = data['accountType'] ?? 'User';
            _licenseNumber = data['licenseNumber'] ?? '';
            _followersCount = data['followersCount'] ?? 0;
            _followingCount = data['followingCount'] ?? 0;
          });
        }

        // Only save to local cache if we are viewing our own profile
        if (widget.userHandle == null || widget.userHandle == localH) {
          await CacheUtility.saveProfileData({
            'name': data['name'] ?? 'CineUser',
            'handle': data['handle'] ?? '@cineuser',
            'bio': data['bio'] ?? '',
            'avatar': data['avatar'] ?? '',
            'dob': data['dob'] ?? '',
            'gender': data['gender'] ?? '',
            'accountType': data['accountType'] ?? 'User',
            'licenseNumber': data['licenseNumber'] ?? '',
          });
        }
        return; // Success, no need to fall back
      }
    } catch (e) {
      debugPrint('Failed to fetch profile from backend: $e');
    }

    // 2. Fallback to local cache if possible (only makes sense for local user)
    if (widget.userHandle == null || widget.userHandle == localH) {
      final name = await CacheUtility.getProfileValue('name');
      final handle = await CacheUtility.getProfileValue('handle');
      final bio = await CacheUtility.getProfileValue('bio');
      final avatar = await CacheUtility.getProfileValue('avatar');
      final dob = await CacheUtility.getProfileValue('dob');
      final gender = await CacheUtility.getProfileValue('gender');
      final accountType = await CacheUtility.getProfileValue('accountType');
      final licenseNumber = await CacheUtility.getProfileValue('licenseNumber');

      if (mounted) {
        setState(() {
          if (name != null) _displayName = name;
          if (handle != null) _handle = handle;
          if (bio != null) _bio = bio;
          if (avatar != null) _avatarUrl = avatar;
          if (dob != null) _dob = dob;
          if (gender != null) _gender = gender;
          if (accountType != null) _accountType = accountType;
          if (licenseNumber != null) _licenseNumber = licenseNumber;
        });
      }
    } else {
      // Mock data for unknown user target
      if (mounted) {
        setState(() {
          _displayName = "Cinema Fan";
          _handle = targetHandle;
          _avatarUrl = 'https://i.pravatar.cc/150?u=$targetHandle';
        });
      }
    }
  }

  /// Checks whether the local user is following the viewed profile.
  /// Called independently from initState so it always runs, even when
  /// _loadProfileData() exits early via `return` after a successful fetch.
  Future<void> _checkFollowStatus() async {
    // Only relevant when viewing someone else's profile
    if (widget.userHandle == null) return;

    // Wait until _localHandle is populated
    final localH = await CacheUtility.getProfileValue('handle') ?? '@cineuser';
    final targetHandle = widget.userHandle!;

    if (targetHandle == localH) return; // own profile

    try {
      final followRes = await HttpCacheService.get(
        Uri.parse('$baseUrl/api/users/$localH/following') ).timeout(const Duration(seconds: 6));

      if (followRes.statusCode == 200 && mounted) {
        final data = json.decode(followRes.body);
        final List following = data['following'] ?? [];
        // API stores the handle in 'userId' field (e.g. "@TollyTrends2026")
        final bool isF = following.any((u) => u['userId'] == targetHandle);
        if (mounted) setState(() => _isFollowing = isF);
      }
    } catch (e) {
      debugPrint('Failed to check following status: $e');
    }
  }

  bool _isFollowLoading = false;

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;

    // Show confirmation dialog when unfollowing
    if (_isFollowing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF16181C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: CacheUtility.getAvatarProvider(_avatarUrl) ),
                const SizedBox(height: 16),
                Text(
                  'Unfollow $_displayName?',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18 ) ),
                const SizedBox(height: 8),
                Text(
                  'Their posts will no longer appear in your feed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14) ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12) ),
                        child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white)) ) ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0055),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0 ),
                        child: Text('Unfollow', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)) ) ),
                  ] ),
              ] ) ) ) );
      if (confirm != true) return;
    }

    // Optimistic update
    final prevFollowing = _isFollowing;
    final prevCount = _followersCount;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = !_isFollowing;
      _followersCount += _isFollowing ? 1 : -1;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/$_handle/follow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': _localHandle}) );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            // Backend confirmed to return 'isFollowing' and 'followersCount'
            _isFollowing = data['isFollowing'] ?? !prevFollowing;
            _followersCount = data['followersCount'] ?? _followersCount;
          });
        }
      } else {
        // Revert
        if (mounted) setState(() { _isFollowing = prevFollowing; _followersCount = prevCount; });
      }
    } catch (e) {
      debugPrint('Follow err: $e');
      if (mounted) {
        setState(() { _isFollowing = prevFollowing; _followersCount = prevCount; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update follow status. Try again.',
                style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating ) );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _checkVerification() async {
    try {
      final handle =
          widget.userHandle ??
          await CacheUtility.getProfileValue('handle') ??
          _handle;
      final response = await HttpCacheService.get(
        Uri.parse('$baseUrl/api/users/profile/$handle') );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool verified = data['isVerified'] ?? false;
        if (mounted) {
          setState(() => _isVerified = verified);
        }
        // Sync with local cache only if our own profile
        if (widget.userHandle == null || widget.userHandle == _localHandle) {
          await CacheUtility.setUserVerified(verified);
        }
      }
    } catch (e) {
      debugPrint("Verification fetch error: $e");
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.9 ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.3) ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: 5 ),
              ] ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00F0FF), Color(0xFFFF0055)] ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                          blurRadius: 20 ),
                      ] ),
                    child: Icon(
                      _isVerified
                          ? Icons.verified
                          : Icons.verified_user_outlined,
                      color: Colors.white,
                      size: 40 ) ),
                  const SizedBox(height: 24),
                  Text(
                    _isVerified ? "Premium Active" : "CineSocial Blue",
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1 ) ),
                  const SizedBox(height: 8),
                  Text(
                    _isVerified
                        ? "Your subscription is currently active"
                        : "Elevate your cinematic presence",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500 ) ),
                  const SizedBox(height: 32),

                  // Features
                  _buildFeatureItem(
                    Icons.verified_user_outlined,
                    "Considered As Official Page" ),
                  _buildFeatureItem(
                    Icons.monetization_on_outlined,
                    "Insight views and Revenue Generation" ),
                  _buildFeatureItem(
                    Icons.check_circle_outline,
                    "Exclusive Blue Verification Tick" ),
                  _buildFeatureItem(
                    Icons.star_outline,
                    "Platinum Profile Badge" ),
                  _buildFeatureItem(
                    Icons.visibility_outlined,
                    "Priority in Feed & Comments" ),
                  _buildFeatureItem(
                    Icons.support_agent_outlined,
                    "24/7 Priority Support" ),

                  const SizedBox(height: 32),

                  // Pricing/Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isVerified
                          ? const Color(0xFF00F0FF).withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isVerified
                            ? const Color(0xFF00F0FF).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1) ) ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isVerified
                                  ? "Subscription Details"
                                  : "Monthly Plan",
                              style: GoogleFonts.outfit(
                                color: _isVerified
                                    ? const Color(0xFF00F0FF)
                                    : Colors.white70,
                                fontSize: 12,
                                fontWeight: _isVerified
                                    ? FontWeight.bold
                                    : FontWeight.normal ) ),
                            Text(
                              "₹75 / month",
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold ) ),
                            if (_isVerified)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Next Billing: March 27, 2026",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white38,
                                    fontSize: 10 ) ) ),
                          ] ),
                        Icon(
                          _isVerified
                              ? Icons.check_circle
                              : Icons.arrow_forward_ios,
                          color: const Color(0xFF00F0FF),
                          size: _isVerified ? 24 : 16 ),
                      ] ) ),

                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isVerified
                          ? () => Navigator.pop(context)
                          : () async {
                              // Navigate to Razorpay Payment Screen
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QRPaymentScreen(
                                    userId: _handle,
                                    amount: "75" ) ) );

                              if (result == true) {
                                if (context.mounted) Navigator.pop(context);
                                _showProcessingOverlay();
                                await Future.delayed(
                                  const Duration(seconds: 2) );
                                await _checkVerification(); // Refresh from backend
                                if (mounted && _isVerified) {
                                  _showSuccessSnackBar();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isVerified
                            ? Colors.white10
                            : const Color(0xFF00F0FF),
                        foregroundColor: _isVerified
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16) ),
                        side: _isVerified
                            ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
                            : null,
                        elevation: 0 ),
                      child: Text(
                        _isVerified ? "Close Details" : "Pay & Get Verified",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5 ) ) ) ),
                  const SizedBox(height: 16),
                  Text(
                    _isVerified
                        ? "CineSocial Premium User"
                        : "Secure payment via CineSocial Pay",
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white30 ) ),
                ] ) ) ) ) ) );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00F0FF), size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14 ) ),
        ] ) );
  }

  void _showProcessingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F0FF)) ) );
    Future.delayed(const Duration(seconds: 3), () {
      if (context.mounted) Navigator.pop(context);
    });
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.stars, color: Color(0xFF00F0FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Welcome to CineSocial Blue! You are now verified.",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold) ) ),
          ] ),
        backgroundColor: const Color(0xFF0F0F1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) ) );
  }

  // _loadCachedData removed as ScreenStateMixin handles it.

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchAllData() async {
    await handleApiState(
      cacheKey: 'profile_all_${widget.userHandle ?? "local"}',
      fetchData: () async {
        Future<List<dynamic>> safeFetch(String url) async {
          try {
            final res = await HttpCacheService
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 5));
            if (res.statusCode == 200) return jsonDecode(res.body);
          } catch (e) {
            debugPrint("SafeFetch failed for $url: $e");
          }
          return [];
        }

        final data = await Future.wait([
          safeFetch(AppConstants.posts),
          safeFetch(AppConstants.movies),
          safeFetch('$baseUrl/api/genre-movies'), // Fixed direct interpolation
          safeFetch(AppConstants.industryBuzz),
          safeFetch(AppConstants.reviews),
        ]);

        return {
          'posts': data[0],
          'movies': data[1],
          'genreMovies': data[2],
          'buzz': data[3],
          'reviews': data[4],
        };
      },
      onDataParsed: (data) {
        if (data is Map<String, dynamic>) {
          final targetHandle = widget.userHandle ?? _localHandle;
          final cacheName = _displayName;

          final cleanTarget = targetHandle.replaceAll('@', '').toLowerCase();
          final cleanLocal = _localHandle.replaceAll('@', '').toLowerCase();

          bool matchHandle(dynamic h) {
            if (h == null) return false;
            final cleanH = h.toString().replaceAll('@', '').toLowerCase();
            if (cleanH == cleanTarget) return true;
            if (cleanTarget == cleanLocal && cleanH == 'mobile_user_1') return true;
            return false;
          }

          final List rawPosts = data['posts'] ?? [];
          final List rawMovies = data['movies'] ?? [];
          final List rawGenreMovies = data['genreMovies'] ?? [];
          final List rawBuzz = data['buzz'] ?? [];
          final List rawReviews = data['reviews'] ?? [];

          final typedPosts = rawPosts
              .map((p) => {...p, 'type': 'post'})
              .toList();
          final typedMovies = rawMovies
              .map((m) => {...m, 'type': 'movie'})
              .toList();
          final typedGenreMovies = rawGenreMovies
              .map((m) => {...m, 'type': 'genre-movie'})
              .toList();
          final typedBuzz = rawBuzz.map((b) => {...b, 'type': 'buzz'}).toList();
          final typedReviews = rawReviews
              .map((r) => {...r, 'type': 'review'})
              .toList();

          final List allActivity = [
            ...typedPosts,
            ...typedMovies,
            ...typedGenreMovies,
            ...typedBuzz,
            ...typedReviews,
          ];

          if (mounted) {
            setState(() {
              // 1. My Posts (applies to 'post', 'movie', 'genre-movie', 'buzz', 'review')
              _myPosts = allActivity
                  .where((p) {
                    if (p['type'] == 'post' ||
                        p['type'] == 'movie' ||
                        p['type'] == 'genre-movie') {
                      return matchHandle(p['userHandle']);
                    }
                    if (p['type'] == 'buzz') {
                      return matchHandle(p['user']);
                    }
                    if (p['type'] == 'review') {
                      return matchHandle(p['user']);
                    }
                    return false;
                  })
                  .map((p) => Map<String, dynamic>.from(p))
                  .toList();

              // Sort newest first
              _myPosts.sort((a, b) {
                DateTime da = a['createdAt'] != null
                    ? DateTime.parse(a['createdAt'])
                    : DateTime.now();
                DateTime db = b['createdAt'] != null
                    ? DateTime.parse(b['createdAt'])
                    : DateTime.now();
                return db.compareTo(da);
              });

              // 2. Liked Posts/Movies/Buzz
              _likedPosts = allActivity
                  .where((p) {
                    final lb = p['likedBy'] as List? ?? [];
                    return lb.any(matchHandle);
                  })
                  .map((p) => Map<String, dynamic>.from(p))
                  .toList();

              _likedPosts.sort((a, b) {
                DateTime da = a['createdAt'] != null
                    ? DateTime.parse(a['createdAt'])
                    : DateTime.now();
                DateTime db = b['createdAt'] != null
                    ? DateTime.parse(b['createdAt'])
                    : DateTime.now();
                return db.compareTo(da);
              });

              // 3. My Comments
              _myComments = allActivity
                  .where((p) {
                    // For posts/movies
                    if (p['type'] == 'post' ||
                        p['type'] == 'movie' ||
                        p['type'] == 'genre-movie') {
                      final List comments = p['commentsList'] as List? ?? [];
                      return comments.any(
                        (c) =>
                            matchHandle(c['userHandle']) ||
                            (targetHandle == _localHandle &&
                                c['userName'] == cacheName) );
                    }
                    // For Buzz & Reviews
                    if (p['type'] == 'buzz' || p['type'] == 'review') {
                      final List comments =
                          (p['type'] == 'review'
                                  ? p['commentsList']
                                  : p['comments'])
                              as List? ??
                          [];
                      return comments.any(
                        (c) =>
                            matchHandle(c['user']) ||
                            (targetHandle == _localHandle &&
                                c['user'] == cacheName) );
                    }
                    return false;
                  })
                  .map((p) => Map<String, dynamic>.from(p))
                  .toList();

              _myComments.sort((a, b) {
                DateTime da = a['createdAt'] != null
                    ? DateTime.parse(a['createdAt'])
                    : DateTime.now();
                DateTime db = b['createdAt'] != null
                    ? DateTime.parse(b['createdAt'])
                    : DateTime.now();
                return db.compareTo(da);
              });

              // 4. Bookmarks
              _bookmarkedPosts = allActivity
                  .where((p) {
                    final bb = p['bookmarkedBy'] as List? ?? [];
                    return bb.any(matchHandle);
                  })
                  .map((p) => Map<String, dynamic>.from(p))
                  .toList();

              _bookmarkedPosts.sort((a, b) {
                DateTime da = a['createdAt'] != null
                    ? DateTime.parse(a['createdAt'])
                    : DateTime.now();
                DateTime db = b['createdAt'] != null
                    ? DateTime.parse(b['createdAt'])
                    : DateTime.now();
                return db.compareTo(da);
              });

              // 5. Reposts
              _sharedPosts = allActivity
                  .where((p) {
                    if (p['type'] == 'post') {
                      final rb = p['repostedBy'] as List? ?? [];
                      return rb.any(matchHandle);
                    }
                    return false;
                  })
                  .map((p) => Map<String, dynamic>.from(p))
                  .toList();

              _sharedPosts.sort((a, b) {
                DateTime da = a['createdAt'] != null
                    ? DateTime.parse(a['createdAt'])
                    : DateTime.now();
                DateTime db = b['createdAt'] != null
                    ? DateTime.parse(b['createdAt'])
                    : DateTime.now();
                return db.compareTo(da);
              });
            });
          }
        }
      } );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isOwnProfile =
        widget.userHandle == null ||
        widget.userHandle == _localHandle ||
        _localHandle.isEmpty;

    Widget content = buildScreenState(
      onRetry: () {
        _loadProfileData();
        fetchAllData();
      },
      buildLoading: Column(
        children: [
          _buildProfileHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (_, _) => const FeedCardSkeleton() ) ),
        ] ),
      buildSuccess: () => Column(
        children: [
          // Profile header (scrollable if needed)
          _buildProfileHeader(),
          _buildStatsRow(),
          _buildEditProfileButton(),
          // Tab bar
          if (isOwnProfile)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context ).textTheme.bodySmall?.color,
                labelStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 13 ),
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Reposts'),
                  Tab(text: 'Likes'),
                  Tab(text: 'Comments'),
                  Tab(text: 'Bookmarks'),
                  Tab(text: 'Following'),
                ] ) ),
          if (!isOwnProfile)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context ).textTheme.bodySmall?.color,
                labelStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 13 ),
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Reposts'),
                ] ) ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: isOwnProfile
                  ? [
                      _buildPostsTab(),
                      _buildRepostsTab(),
                      _buildLikesTab(),
                      _buildCommentsTab(),
                      _buildBookmarksTab(),
                      _buildFollowingTab(),
                    ]
                  : [
                      _buildPostsTab(),
                      _buildRepostsTab(),
                    ] ) ),
        ] ) );

    if (!isOwnProfile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: BackButton(color: Theme.of(context).colorScheme.primary),
          title: Text(
            _displayName,
            style: GoogleFonts.outfit(
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontWeight: FontWeight.bold ) ) ),
        body: content );
    }

    return content;
  }

  // =================== PROFILE HEADER ===================
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00F0FF),
                    width: 2.5 ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2 ),
                  ] ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundImage: CacheUtility.getAvatarProvider(_avatarUrl) ) ),

              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _displayName,
                          style: GoogleFonts.outfit(
                            color: Theme.of(
                              context ).textTheme.titleLarge?.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w800 ) ),
                        const SizedBox(width: 6),
                        // Verified badge
                        GestureDetector(
                          onTap: _showVerificationDialog,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _isVerified
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF00F0FF),
                                        Color(0xFFFF0055),
                                      ] )
                                  : null,
                              color: _isVerified ? null : Colors.white10 ),
                            child: Icon(
                              _isVerified
                                  ? Icons.verified
                                  : Icons.verified_user_outlined,
                              color: _isVerified
                                  ? Colors.white
                                  : Colors.white24,
                              size: 16 ) ) ),
                      ] ),
                    const SizedBox(height: 2),
                    Text(
                      _handle,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 14 ) ),
                    const SizedBox(height: 4),
                    // Badges Wrap
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Elite Critic badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3 ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00F0FF).withValues(alpha: 0.2),
                                const Color(0xFFFF0055).withValues(alpha: 0.2),
                              ] ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.4) ) ),
                          child: Text(
                            '✨ ELITE CRITIC',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1 ) ) ),
                        if (['Certified User', 'Production House', 'Event Manager'].contains(_accountType))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3 ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.4) ) ),
                            child: Text(
                              _accountType.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00F0FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1 ) ) ),
                      ] ),
                  ] ) ),

              // Theme Toggle Button
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.themeNotifier,
                builder: (context, currentMode, child) {
                  final isDark = currentMode == ThemeMode.dark;
                  return IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: Theme.of(context).iconTheme.color ),
                    tooltip: 'Toggle Theme',
                    onPressed: () {
                      ThemeController.toggleTheme(!isDark);
                    } );
                } ),
            ] ),
          const SizedBox(height: 14),
          // Bio
          Text(
            _bio,
            style: GoogleFonts.outfit(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 14,
              height: 1.4 ) ),
          const SizedBox(height: 8),
          // Info Row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildProfileInfoItem(Icons.calendar_today, _joinDate),
              if (_dob != 'Not set')
                _buildProfileInfoItem(Icons.cake_outlined, "Born $_dob"),
              if (_gender != 'Not set')
                _buildProfileInfoItem(
                  _gender == "Male"
                      ? Icons.male
                      : _gender == "Female"
                      ? Icons.female
                      : Icons.person_outline,
                  _gender ),
              if (['Certified User', 'Production House', 'Event Manager'].contains(_accountType) && _licenseNumber.isNotEmpty)
                _buildProfileInfoItem(Icons.badge_rounded, "Lic: $_licenseNumber"),
            ] ),
        ] ) );
  }

  Widget _buildProfileInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13) ),
      ] );
  }

  // =================== STATS ROW ===================
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showFollowingModal,
            child: Row(
              children: [
                Text(
                  '$_followingCount',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800 ) ),
                const SizedBox(width: 4),
                Text(
                  'Following',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14 ) ),
              ] ) ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: _showFollowersModal,
            child: Row(
              children: [
                Text(
                  _formatCount(_followersCount),
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800 ) ),
                const SizedBox(width: 4),
                Text(
                  'Followers',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14 ) ),
              ] ) ),
        ] ) );
  }

  Future<void> _showFollowingModal() async {
    _showConnectionModal('Following');
  }

  Future<void> _showFollowersModal() async {
    _showConnectionModal('Followers');
  }

  Future<void> _showConnectionModal(String type) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16181C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)) ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<http.Response>(
              future: HttpCacheService.get(
                Uri.parse('$baseUrl/api/users/$_handle/following') ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00F0FF) ) ) );
                }

                List<dynamic> connections = [];
                if (snapshot.hasData && snapshot.data!.statusCode == 200) {
                  final data = json.decode(snapshot.data!.body);
                  connections = type == 'Following'
                      ? (data['following'] ?? [])
                      : (data['followers'] ?? []);
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7 ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2) ) ),
                      const SizedBox(height: 16),
                      Text(
                        type,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold ) ),
                      const Divider(color: Colors.white10, height: 24),
                      if (connections.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              'No $type yet.',
                              style: GoogleFonts.outfit(color: Colors.white54) ) ) )
                      else
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: connections.length,
                            itemBuilder: (context, index) {
                              final user = connections[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4 ),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundImage:
                                      CacheUtility.getAvatarProvider(
                                        user['avatar'] ?? '' ) ),
                                title: Row(
                                  children: [
                                    Text(
                                      user['name'] ?? user['userId'],
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15 ) ),
                                    if (user['isVerified'] == true) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified,
                                        color: Color(0xFF00F0FF),
                                        size: 14 ),
                                    ],
                                  ] ),
                                subtitle: Text(
                                  user['userId'] ?? '',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white54,
                                    fontSize: 13 ) ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white10,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20) ),
                                    elevation: 0 ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(
                                          userHandle: user['userId'] ) ) );
                                  },
                                  child: Text(
                                    'View',
                                    style: GoogleFonts.outfit(fontSize: 12) ) ) );
                            } ) ),
                      const SizedBox(height: 20),
                    ] ) );
              } );
          } );
      } );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // =================== EDIT PROFILE BUTTON ===================
  Widget _buildEditProfileButton() {
    bool isOwnProfile =
        widget.userHandle == null ||
        widget.userHandle == _localHandle ||
        _localHandle.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          if (isOwnProfile) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _showEditProfileDialog,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20) ),
                  padding: const EdgeInsets.symmetric(vertical: 10) ),
                child: Text(
                  'Edit profile',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14 ) ) ) ),
            const SizedBox(width: 10),
            if (!_isVerified)
              OutlinedButton(
                onPressed: _showVerificationDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
                  backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20) ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14 ) ),
                child: Text(
                  'Get Verified (₹75)',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00F0FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 13 ) ) ),
            if (_isVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8 ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.3) ) ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00F0FF),
                      size: 14 ),
                    const SizedBox(width: 6),
                    Text(
                      'Active Plan: ₹75/mo',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00F0FF),
                        fontWeight: FontWeight.w700,
                        fontSize: 12 ) ),
                  ] ) ),
          ] else ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isFollowLoading ? null : _toggleFollow,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isFollowing
                        ? const Color(0xFFFF0055).withValues(alpha: 0.5)
                        : const Color(0xFF00F0FF).withValues(alpha: 0.5) ),
                  backgroundColor: _isFollowing
                      ? const Color(0xFFFF0055).withValues(alpha: 0.1)
                      : const Color(0xFF00F0FF).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20) ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 18 ) ),
                child: _isFollowLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _isFollowing
                              ? const Color(0xFFFF0055)
                              : const Color(0xFF00F0FF) ) )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isFollowing
                                ? Icons.person_remove_rounded
                                : Icons.person_add_rounded,
                            size: 16,
                            color: _isFollowing
                                ? const Color(0xFFFF0055)
                                : const Color(0xFF00F0FF) ),
                          const SizedBox(width: 6),
                          Text(
                            _isFollowing ? 'Following' : 'Follow',
                            style: GoogleFonts.outfit(
                              color: _isFollowing
                                  ? const Color(0xFFFF0055)
                                  : const Color(0xFF00F0FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 14 ) ),
                        ] ) ) ),
          ],
        ] ) );
  }

  // =================== POSTS TAB ===================
  Widget _buildPostsTab() =>
      _buildFeedTab(_myPosts, 'No posts yet', Icons.post_add_rounded);

  Widget _buildRepostsTab() =>
      _buildFeedTab(_sharedPosts, 'No reposts yet', Icons.repeat_rounded);

  Widget _buildFeedTab(
    List<Map<String, dynamic>> posts,
    String emptyMessage,
    IconData emptyIcon, {
    bool isCommentView = false,
  }) {
    if (posts.isEmpty) {
      return _buildEmptyState(emptyMessage, emptyIcon);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        if (post['type'] == 'post') {
          return RepaintBoundary(child: SocialFeedCard(
            postId: post['_id'].toString(),
            userName: (post['userHandle'] == _handle)
                ? _displayName
                : (post['userName'] ?? 'Unknown'),
            userHandle: post['userHandle'] ?? '@unknown',
            userAvatar: (post['userHandle'] == _handle)
                ? _avatarUrl
                : (post['userAvatar'] ?? ''),
            timeAgo: TimeUtility.getTimeAgo(
              post['createdAt'] ?? post['timeAgo'] ),
            text: post['text'],
            images:
                (post['images'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            videoUrl: post['videoUrl'],
            likes: post['likes'] ?? 0,
            comments: post['comments'] ?? 0,
            reposts: post['reposts'] ?? 0,
            isVerified: (post['userHandle'] == _handle)
                ? _isVerified
                : (post['isVerified'] ?? false),
            commentsList: post['commentsList'] ?? [],
            likedBy:
                (post['likedBy'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            bookmarkedBy:
                (post['bookmarkedBy'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            localHandle: _localHandle,
            onLikeChanged: (newCount, isLiked) {
              post['likes'] = newCount;
              final likedBy = List<String>.from(post['likedBy'] ?? []);
              if (isLiked) {
                if (!likedBy.contains(_handle)) likedBy.add(_handle);
              } else {
                likedBy.remove(_handle);
              }
              post['likedBy'] = likedBy;
            },
            onRepostChanged: (newCount, isReposted) {
              setState(() {
                post['reposts'] = newCount;
                final repostedBy = List<String>.from(post['repostedBy'] ?? []);
                if (isReposted) {
                  if (!repostedBy.contains(_localHandle)) {
                    repostedBy.add(_localHandle);
                  }
                } else {
                  repostedBy.remove(_localHandle);
                }
                post['repostedBy'] = repostedBy;

                final isOwn = widget.userHandle == null || widget.userHandle == _localHandle;
                if (isOwn) {
                  if (isReposted) {
                    if (!_sharedPosts.any((element) => element['_id'] == post['_id'])) {
                      _sharedPosts.add(post);
                      _sharedPosts.sort((a, b) {
                        DateTime da = a['createdAt'] != null
                            ? DateTime.parse(a['createdAt'])
                            : DateTime.now();
                        DateTime db = b['createdAt'] != null
                            ? DateTime.parse(b['createdAt'])
                            : DateTime.now();
                        return db.compareTo(da);
                      });
                    }
                  } else {
                    _sharedPosts.removeWhere((element) => element['_id'] == post['_id']);
                  }
                }
              });
            },
            onDelete: () => _deletePost(post['_id']),
            isCommentView: isCommentView ));
        } else if (post['type'] == 'movie' ||
            post['type'] == 'genre-movie' ||
            post['type'] == 'review') {
          return RepaintBoundary(child: _buildProfileMovieTile(post));
        } else if (post['type'] == 'buzz') {
          return RepaintBoundary(child: _buildProfileBuzzTile(post));
        }

        return RepaintBoundary(child: const SizedBox.shrink()); // Fallback
      } );
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181C),
        title: Text(
          'Delete Post?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold ) ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.outfit(color: Colors.white70) ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.grey) ) ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold ) ) ),
        ] ) );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.posts}/$postId') );
      if (response.statusCode == 200) {
        fetchAllData(); // Refresh feed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post deleted successfully'),
              backgroundColor: const Color(0xFF00F0FF) ) );
        }
      } else {
        throw Exception('Failed to delete');
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete post. Try again.'),
            backgroundColor: Colors.redAccent ) );
      }
    }
  }

  // =================== LIKES TAB ===================
  Widget _buildLikesTab() =>
      _buildFeedTab(_likedPosts, 'No liked posts', Icons.favorite_border);

  // =================== COMMENTS TAB ===================
  Widget _buildCommentsTab() => _buildFeedTab(
    _myComments,
    'No comments yet',
    Icons.chat_bubble_outline,
    isCommentView: true );

  // =================== BOOKMARKS TAB ===================
  Widget _buildBookmarksTab() => _buildFeedTab(
    _bookmarkedPosts,
    'No bookmarks yet',
    Icons.bookmark_border );

  // =================== FOLLOWING TAB ===================
  Widget _buildFollowingTab() {
    return FutureBuilder<http.Response>(
      future: HttpCacheService.get(Uri.parse('$baseUrl/api/users/$_handle/following')),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00F0FF)) );
        }

        List<dynamic> connections = [];
        if (snapshot.hasData && snapshot.data!.statusCode == 200) {
          final data = json.decode(snapshot.data!.body);
          connections = data['following'] ?? [];
        }

        if (connections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Colors.white24,
                  size: 52 ),
                const SizedBox(height: 14),
                Text(
                  'Not following anyone yet.',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 16 ) ),
              ] ) );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final user = connections[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 6 ),
              leading: CircleAvatar(
                radius: 24,
                backgroundImage: CacheUtility.getAvatarProvider(
                  user['avatar'] ?? '' ) ),
              title: Row(
                children: [
                  Text(
                    user['name'] ?? user['userId'],
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15 ) ),
                  if (user['isVerified'] == true) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF00F0FF),
                      size: 14 ),
                  ],
                ] ),
              subtitle: Text(
                user['userId'] ?? '',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13) ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20) ),
                  elevation: 0 ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(userHandle: user['userId']) ) );
                },
                child: Text('View', style: GoogleFonts.outfit(fontSize: 12)) ) );
          } );
      } );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 52),
          const SizedBox(height: 14),
          Text(
            message,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16) ),
        ] ) );
  }

  // =================== PROFILE COMPACT TILES ===================
  Widget _buildProfileMovieTile(Map<String, dynamic> movie) {
    String postLabel = 'Featured';
    if (movie['type'] == 'genre-movie') postLabel = 'Genre';
    if (movie['type'] == 'review') postLabel = 'Review';

    // Reviews usually have 'posterUrl' instead of 'image'
    final imageUrl = movie['image'] ?? movie['posterUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        final isHeroMovie = movie['type'] == 'movie';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (isHeroMovie) {
                return HeroMovieInfoScreen(movie: movie);
              } else {
                return MovieInfoScreen(
                  movie: movie,
                  isGenreMovie: movie['type'] == 'genre-movie' );
              }
            } ) ).then((_) => fetchAllData()); // Refresh state when coming back
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)) ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 60,
                height: 80,
                fit: BoxFit.cover, 
                errorWidget: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 80,
                  color: Colors.grey[900],
                  child: const Icon(Icons.movie, color: Colors.white30) ) ) ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (movie['title'] ?? movie['movieTitle']) ?? 'Unknown Movie',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        movie['rating']?.toString() ?? 'N/A',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13 ) ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2 ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4) ),
                        child: Text(
                          postLabel,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF00F0FF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold ) ) ),
                      const SizedBox(width: 8),
                      Text(
                        TimeUtility.getTimeAgo(movie['createdAt']),
                        style: GoogleFonts.outfit(
                          color: Colors.white24,
                          fontSize: 11 ) ),
                    ] ),
                  const SizedBox(height: 6),
                  Text(
                    (movie['tags'] ?? movie['genre']) ?? '',
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 12 ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis ),
                ] ) ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ] ) ) );
  }

  Widget _buildProfileBuzzTile(Map<String, dynamic> buzz) {
    final images = buzz['images'] as List?;
    final hasImage = images != null && images.isNotEmpty;

    final String timeAgo = TimeUtility.getTimeAgo(buzz['createdAt']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BuzzDetailsScreen(
              post: buzz,
              accentColor: const Color(0xFFFF0055) ) ) ).then((_) => fetchAllData()); // Refresh state
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(16),
          border: const Border(
            left: BorderSide(color: Color(0xFFFF0055), width: 4) ) ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: images.first.toString(),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover, 
                  errorWidget: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white30 ) ) ) ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flash_on,
                        color: Color(0xFFFF0055),
                        size: 14 ),
                      const SizedBox(width: 4),
                      Text(
                        'Industry Buzz',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFF0055),
                          fontSize: 12,
                          fontWeight: FontWeight.bold ) ),
                      const Spacer(),
                      Text(
                        timeAgo,
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 11 ) ),
                    ] ),
                  const SizedBox(height: 6),
                  Text(
                    buzz['content'] ?? '',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14 ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis ),
                ] ) ),
          ] ) ) );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _displayName);
    final bioController = TextEditingController(text: _bio);
    final licenseController = TextEditingController(text: _licenseNumber);
    String localDob = _dob;
    String localGender = _gender;
    String localAvatar = _avatarUrl;
    String localAccountType = _accountType;
    String? localLicenseError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24 ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 10 ),
                ] ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Edit Profile",
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5 ) ),
                    const SizedBox(height: 32),

                    // Avatar setup
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery );
                        if (image != null) {
                          try {
                            final bytes = await image.readAsBytes();
                            final base64String = base64Encode(bytes);
                            final mime = image.mimeType ?? 'image/jpeg';
                            setModalState(() {
                              localAvatar = 'data:$mime;base64,$base64String';
                            });
                          } catch (e) {
                            debugPrint('Failed to encode image: $e');
                          }
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00F0FF),
                                width: 2 ) ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: CacheUtility.getAvatarProvider(
                                localAvatar ) ) ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00F0FF),
                                shape: BoxShape.circle ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.black ) ) ),
                        ] ) ),
                    const SizedBox(height: 32),

                    // Name
                    _buildEditField("Display Name", nameController),
                    const SizedBox(height: 20),

                    // Bio
                    _buildEditField("Bio", bioController, maxLines: 3),
                    const SizedBox(height: 20),

                    // DOB
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(
                            const Duration(days: 365 * 18) ),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now() );
                        if (picked != null) {
                          setModalState(() {
                            localDob =
                                "${picked.day}/${picked.month}/${picked.year}";
                          });
                        }
                      },
                      child: _buildReadOnlyEditField("Date of Birth", localDob) ),
                    const SizedBox(height: 20),

                    // Gender
                    _buildGenderSelector(localGender, (val) {
                      setModalState(() => localGender = val);
                    }),
                    const SizedBox(height: 20),

                    // Account Type
                    _buildAccountTypeSelector(localAccountType, (val) {
                      setModalState(() {
                        localAccountType = val;
                        localLicenseError = null;
                      });
                    }),
                    const SizedBox(height: 20),

                    // License Number — only for professional types
                    if (['Certified User', 'Production House', 'Event Manager'].contains(localAccountType)) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'License Number',
                                style: GoogleFonts.outfit(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600 ) ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF0055).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFF0055).withValues(alpha: 0.4)) ),
                                child: Text(
                                  'REQUIRED',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFFF0055),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5 ) ) ),
                            ] ),
                          const SizedBox(height: 4),
                          Text(
                            'Mandatory for $localAccountType accounts',
                            style: GoogleFonts.outfit(
                              color: Colors.white30,
                              fontSize: 11,
                              fontStyle: FontStyle.italic ) ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: licenseController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            onChanged: (_) {
                              if (localLicenseError != null) {
                                setModalState(() => localLicenseError = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'e.g. LIC-2024-PROD-00123',
                              hintStyle: GoogleFonts.outfit(color: Colors.white24),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF00F0FF), size: 20),
                              errorText: localLicenseError,
                              errorStyle: GoogleFonts.outfit(color: const Color(0xFFFF0055), fontSize: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5) ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: localLicenseError != null
                                    ? const BorderSide(color: Color(0xFFFF0055), width: 1.5)
                                    : BorderSide.none ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14) ) ),
                        ] ),
                      const SizedBox(height: 32),
                    ] else
                      const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Validate license number for professional types
                          final isProfessional = ['Certified User', 'Production House', 'Event Manager']
                              .contains(localAccountType);
                          if (isProfessional && licenseController.text.trim().isEmpty) {
                            setModalState(() {
                              localLicenseError = 'License number is required for $localAccountType';
                            });
                            return;
                          }

                          final updatedData = {
                            'handle': _handle,
                            'name': nameController.text,
                            'bio': bioController.text,
                            'avatar': localAvatar,
                            'dob': localDob,
                            'gender': localGender,
                            'accountType': localAccountType,
                            'licenseNumber': isProfessional ? licenseController.text.trim() : '',
                          };

                          // 1. Save to backend
                          try {
                            await http
                                .post(
                                  Uri.parse(AppConstants.me),
                                  headers: {'Content-Type': 'application/json'},
                                  body: json.encode(updatedData) )
                                .timeout(const Duration(seconds: 10));
                          } catch (e) {
                            debugPrint('Failed to save profile to backend: $e');
                          }

                          // 2. Also save locally
                          await CacheUtility.saveProfileData(updatedData);

                          if (mounted) {
                            setState(() {
                              _displayName = updatedData['name']!;
                              _bio = updatedData['bio']!;
                              _avatarUrl = updatedData['avatar']!;
                              _dob = updatedData['dob']!;
                              _gender = updatedData['gender']!;
                              _accountType = updatedData['accountType']!;
                              _licenseNumber = updatedData['licenseNumber']!;
                            });
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F0FF),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16) ),
                          elevation: 0 ),
                        child: Text(
                          "Save Changes",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 16 ) ) ) ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.outfit(color: Colors.white38) ) ),
                  ] ) ) ) );
        } ) );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600 ) ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1) ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14 ) ) ),
      ] );
  }

  Widget _buildReadOnlyEditField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600 ) ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16) ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: GoogleFonts.outfit(color: Colors.white)),
              const Icon(Icons.calendar_month, color: Colors.white24, size: 20),
            ] ) ),
      ] );
  }

  Widget _buildGenderSelector(String current, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gender",
          style: GoogleFonts.outfit(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600 ) ),
        const SizedBox(height: 10),
        Row(
          children: ["Male", "Female", "Other"]
              .map(
                (g) => Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(g),
                    child: Container(
                      margin: EdgeInsets.only(right: g == "Other" ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: current == g
                            ? const Color(0xFF00F0FF).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: current == g
                              ? const Color(0xFF00F0FF)
                              : Colors.white.withValues(alpha: 0.1) ) ),
                      child: Center(
                        child: Text(
                          g,
                          style: GoogleFonts.outfit(
                            color: current == g ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 13 ) ) ) ) ) ) )
              .toList() ),
      ] );
  }

  Widget _buildAccountTypeSelector(String current, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Account Type",
          style: GoogleFonts.outfit(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600 ) ),
        const SizedBox(height: 10),
        Column(
          children: ["User", "Certified User", "Production House", "Event Manager"]
              .map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GestureDetector(
                    onTap: () => onSelect(type),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: current == type
                            ? const Color(0xFF00F0FF).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: current == type
                              ? const Color(0xFF00F0FF)
                              : Colors.white.withValues(alpha: 0.1) ) ),
                      child: Center(
                        child: Text(
                          type,
                          style: GoogleFonts.outfit(
                            color: current == type ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 13 ) ) ) ) ) ) )
              .toList() ),
      ] );
  }
}

// =================== POST CARD (My Posts) ===================
// =================== LIKED POST CARD ===================
// =================== COMMENT CARD ===================
// =================== SHARED POST CARD ===================

