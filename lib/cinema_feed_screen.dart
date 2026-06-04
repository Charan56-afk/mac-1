import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:async';
import 'services/http_cache_service.dart';
import 'utils.dart';
import 'widgets/social_feed_card.dart';
import 'widgets/insta_feed_card.dart';
import 'widgets/reels_feed_card.dart';
import 'widgets/account_search_tile.dart';
import 'create_post_screen.dart';
import 'profile_screen.dart';
import 'package:flutter_application_1/constants.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';


/// A social feed screen similar to Twitter/X, displaying posts about cinema.
///
/// Features two tabs: "For You" and "Following". Displays a mix of text,
/// image, and video posts using [SocialFeedCard].
/// Currently uses mock data but is set up to fetch from an API endpoint.
class CinemaFeedScreen extends StatefulWidget {
  const CinemaFeedScreen({super.key});

  @override
  State<CinemaFeedScreen> createState() => _CinemaFeedScreenState();
}

class _CinemaFeedScreenState extends State<CinemaFeedScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _forYouPosts = [];
  List<Map<String, dynamic>> _followingPosts = [];
  bool _isLoading = true;
  bool _isVerified = false;
  String _localUserHandle = '@cineuser';
  String _localUserName = 'CineUser';
  String _localUserAvatar = '';
  Set<String> _followingSet = {};

  late TabController _tabController;
  final ValueNotifier<double> _headerOffsetNotifier = ValueNotifier(0.0);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Real-time account search state
  List<Map<String, dynamic>> _searchedAccounts = [];
  bool _isSearchingAccounts = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserInfo().then((_) => _fetchFollowing());
    _loadCachedData();
    _fetchPosts();
  }

  Future<void> _loadUserInfo() async {
    final handle = await CacheUtility.getProfileValue('handle');
    final name = await CacheUtility.getProfileValue('name');
    final avatar = await CacheUtility.getProfileValue('avatar');
    final verified = await CacheUtility.isUserVerified();
    if (mounted) {
      setState(() {
        if (handle != null) _localUserHandle = handle;
        if (name != null) _localUserName = name;
        if (avatar != null) _localUserAvatar = avatar;
        _isVerified = verified;
      });
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedPosts = await CacheUtility.getFromCache('cine_feed_posts');
      final cachedReels = await CacheUtility.getFromCache('cine_feed_reels');
      if (mounted) {
        setState(() {
          if (cachedPosts != null) {
            final List<dynamic> data = cachedPosts;
            _forYouPosts = data
                .where((e) => e['feedType'] == 'foryou')
                .map((e) => Map<String, dynamic>.from(e))
                .toList()..shuffle();
          }
          if (cachedReels != null) {
            final List<dynamic> data = cachedReels;
            _followingPosts = data
                .map((e) => Map<String, dynamic>.from(e))
                .toList()..shuffle();
          }
          if (cachedPosts != null || cachedReels != null) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Feed cache load error: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _searchDebounce?.cancel();
    _headerOffsetNotifier.dispose();
    super.dispose();
  }

  /// Called whenever the search field changes.
  /// Debounces 400ms then hits the backend user-search endpoint.
  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchedAccounts = [];
        _isSearchingAccounts = false;
      });
      return;
    }
    setState(() => _isSearchingAccounts = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final res = await http
            .get(Uri.parse('$baseUrl/api/users/search?q=${Uri.encodeComponent(query.trim())}'))
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final List<dynamic> data = json.decode(res.body);
          if (mounted) {
            setState(() {
              _searchedAccounts = data
                  .map((u) => {
                        'userHandle': u['handle'] ?? u['userHandle'] ?? '',
                        'userName': u['name'] ?? u['userName'] ?? 'Unknown',
                        'userAvatar': u['avatar'] ?? u['userAvatar'] ?? '',
                        'isVerified': u['isVerified'] ?? false,
                        'followersCount': u['followersCount'] ?? 0,
                        'bio': u['bio'] ?? '',
                      })
                  .where((u) => (u['userHandle'] as String).isNotEmpty)
                  .toList()
                  .cast<Map<String, dynamic>>();
              _isSearchingAccounts = false;
            });
          }
        } else {
          // Fallback: filter from locally loaded posts
          if (mounted) {
            setState(() {
            _searchedAccounts = _getLocalFilteredAccounts(query);
            _isSearchingAccounts = false;
          });
          }
        }
      } catch (_) {
        // Network error — fall back to local post authors
        if (mounted) {
          setState(() {
          _searchedAccounts = _getLocalFilteredAccounts(query);
          _isSearchingAccounts = false;
        });
        }
      }
    });
  }

  /// Fallback: extract unique authors from loaded posts
  List<Map<String, dynamic>> _getLocalFilteredAccounts(String query) {
    final allPosts = [..._forYouPosts, ..._followingPosts];
    final Map<String, Map<String, dynamic>> seen = {};
    for (final post in allPosts) {
      final handle = post['userHandle']?.toString() ?? '';
      if (handle.isEmpty) continue;
      seen.putIfAbsent(handle, () => {
        'userHandle': handle,
        'userName': post['userName'] ?? 'Unknown',
        'userAvatar': post['userAvatar'] ?? '',
        'isVerified': post['isVerified'] ?? false,
        'followersCount': 0,
        'bio': '',
      });
    }
    final q = query.toLowerCase();
    return seen.values
        .where((a) =>
            a['userName'].toString().toLowerCase().contains(q) ||
            a['userHandle'].toString().toLowerCase().contains(q))
        .toList();
  }

  // Removed _getFilteredAccounts() — replaced by _onSearchChanged + _getLocalFilteredAccounts

  Future<void> _fetchPosts({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetch posts and reels in parallel using low-latency caching service
      final results = await Future.wait([
        HttpCacheService.get(Uri.parse(AppConstants.posts), forceRefresh: forceRefresh).timeout(const Duration(seconds: 10)),
        HttpCacheService.get(Uri.parse(AppConstants.reels), forceRefresh: forceRefresh).timeout(const Duration(seconds: 10)),
      ]);
      final postsResponse = results[0];
      final reelsResponse = results[1];

      if (mounted) {
        setState(() {
          if (postsResponse.statusCode == 200) {
            final List<dynamic> data = json.decode(postsResponse.body);
            _forYouPosts = data
                .where((e) => e['feedType'] == 'foryou')
                .map((e) => Map<String, dynamic>.from(e))
                .toList()..shuffle();
            CacheUtility.saveToCache('cine_feed_posts', data);
          } else {
            _forYouPosts = [];
          }

          if (reelsResponse.statusCode == 200) {
            final List<dynamic> data = json.decode(reelsResponse.body);
            _followingPosts = data
                .map((e) => Map<String, dynamic>.from(e))
                .toList()..shuffle();
            CacheUtility.saveToCache('cine_feed_reels', data);
          } else {
            _followingPosts = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching feeds: $e');
      if (mounted) {
        setState(() {
          _forYouPosts = [];
          _followingPosts = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fetches the local user's following list ONCE per session.
  /// Cards receive initialIsFollowing instead of each making their own API call.
  Future<void> _fetchFollowing() async {
    if (_localUserHandle == '@cineuser') return;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/users/$_localUserHandle/following'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final List following = data['following'] ?? [];
        setState(() {
          _followingSet = following
              .map((u) => u['userId']?.toString() ?? '')
              .where((h) => h.isNotEmpty)
              .toSet();
        });
      }
    } catch (e) {
      debugPrint('Follow list fetch error: $e');
    }
  }

  Future<void> _showUploadReelModal() async {
    final textController = TextEditingController();
    PlatformFile? selectedVideo;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload New Reel',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.video,
                          withData: kIsWeb,
                        );
                        if (result != null) {
                          setModalState(() {
                            selectedVideo = result.files.first;
                          });
                        }
                      } catch (e) {
                        debugPrint('Error picking video: $e');
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: selectedVideo == null
                              ? Colors.white24
                              : const Color(0xFF00F0FF),
                        ),
                      ),
                      child: selectedVideo == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.videocam_rounded, color: Colors.white54, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to choose a local video',
                                  style: GoogleFonts.outfit(color: Colors.white54),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Color(0xFF00F0FF), size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  selectedVideo!.name,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F0FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (selectedVideo == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a video first')));
                                return;
                              }
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() => isSubmitting = true);
                              
                              try {
                                final uri = Uri.parse('${AppConstants.reels}/upload');
                                final request = http.MultipartRequest('POST', uri);
                                
                                request.fields['userName'] = _localUserName;
                                request.fields['userHandle'] = _localUserHandle;
                                request.fields['userAvatar'] = _localUserAvatar;
                                request.fields['caption'] = textController.text.trim();
                                request.fields['isVerified'] = _isVerified.toString();

                                final mimeType = lookupMimeType(kIsWeb ? selectedVideo!.name : (selectedVideo!.path ?? selectedVideo!.name)) ?? 'video/mp4';
                                final typeSplit = mimeType.split('/');
                                
                                if (kIsWeb) {
                                  request.files.add(
                                    http.MultipartFile.fromBytes(
                                      'file',
                                      selectedVideo!.bytes!,
                                      filename: selectedVideo!.name,
                                      contentType: MediaType(typeSplit[0], typeSplit[1]),
                                    ),
                                  );
                                } else {
                                  request.files.add(
                                    await http.MultipartFile.fromPath(
                                      'file',
                                      selectedVideo!.path!,
                                      filename: selectedVideo!.name,
                                      contentType: MediaType(typeSplit[0], typeSplit[1]),
                                    ),
                                  );
                                }

                                final streamed = await request.send().timeout(const Duration(seconds: 120));
                                if (streamed.statusCode == 201 || streamed.statusCode == 200) {
                                  navigator.pop();
                                  if (mounted) {
                                    _fetchPosts();
                                  }
                                  messenger.showSnackBar(const SnackBar(content: Text('Reel uploaded successfully!')));
                                } else {
                                  final responseData = await streamed.stream.bytesToString();
                                  debugPrint('Server error: $responseData');
                                  messenger.showSnackBar(SnackBar(content: Text('Upload failed (Status ${streamed.statusCode})')));
                                }
                              } catch (e) {
                                debugPrint('Upload error: $e');
                                messenger.showSnackBar(const SnackBar(content: Text('Server busy. Please try again later.')));
                              } finally {
                                if (mounted) {
                                  setModalState(() => isSubmitting = false);
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Post Reel',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePost(String postId, {bool isReel = false}) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181C),
        title: Text(
          'Delete Post?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final endpoint = isReel ? '${AppConstants.reels}/$postId' : '${AppConstants.posts}/$postId';
      final response = await http.delete(
        Uri.parse(endpoint),
      );
      if (response.statusCode == 200) {
        _fetchPosts(); // Refresh feed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Post deleted successfully',
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: const Color(0xFF00F0FF),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete');
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete post. Try again.',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double headerHeight = topPadding + kToolbarHeight + 60.0 + (_searchQuery.isEmpty ? 48.0 : 0.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content Layer
          Positioned.fill(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Update ValueNotifier directly — NO setState, so cards don't rebuild
                      if (notification is UserScrollNotification && !notification.metrics.axisDirection.toString().contains('horizontal')) {
                        if (notification.direction == ScrollDirection.reverse && _headerOffsetNotifier.value == 0) {
                          _headerOffsetNotifier.value = -headerHeight;
                        } else if (notification.direction == ScrollDirection.forward && _headerOffsetNotifier.value < 0) {
                          _headerOffsetNotifier.value = 0.0;
                        }
                      }
                      return false;
                    },
                    child: _searchQuery.isNotEmpty
                        ? _buildSearchResults(headerHeight)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _isVerified 
                                  ? _buildFeedList(_forYouPosts, headerHeight)
                                  : _buildStandardFeedList(_forYouPosts, headerHeight),
                              _buildReelsFeedList(_followingPosts, headerHeight),
                            ],
                          ),
                  ),
          ),
          // Only this subtree rebuilds on scroll — cards are untouched
          ValueListenableBuilder<double>(
            valueListenable: _headerOffsetNotifier,
            builder: (context, offset, _) => AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              top: offset,
              left: 0,
              right: 0,
              child: _buildHeader(topPadding),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildHeader(double topPadding) {
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C10).withValues(alpha: 0.97),
        border: Border(
          bottom: BorderSide(
            color: _isVerified
                ? const Color(0xFF00F0FF).withValues(alpha: 0.25)
                : Colors.blueAccent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: (_isVerified ? const Color(0xFF00F0FF) : Colors.blueAccent)
                .withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title Row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white54, size: 20),
                ),
                const SizedBox(width: 12),

                if (_isVerified) ...[
                  // Neon CINEFEED gradient text
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00F0FF), Color(0xFFB06EFF)],
                    ).createShader(bounds),
                    child: Text(
                      'CINEFEED',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Golden PRO badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      'PRO',
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ] else
                  Text(
                    'CinemaFeed',
                    style: GoogleFonts.grandHotel(color: Colors.white, fontSize: 32),
                  ),

                const Spacer(),

                // Minimal Add Post/Reel button
                GestureDetector(
                  onTap: () async {
                    if (_tabController.index == 1) {
                      await _showUploadReelModal();
                    } else {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                      );
                      if (result == true) {
                        _fetchPosts();
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),

                // Notification bell (PRO only)
                if (_isVerified)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        color: Color(0xFF00F0FF), size: 20),
                  ),
              ],
            ),
          ),

          // ── Search Bar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF16181C),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: (_isVerified ? const Color(0xFF00F0FF) : Colors.blueAccent)
                      .withValues(alpha: _searchQuery.isNotEmpty ? 0.8 : 0.25),
                  width: _searchQuery.isNotEmpty ? 1.5 : 1,
                ),
                boxShadow: _searchQuery.isNotEmpty
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                          blurRadius: 12,
                        )
                      ]
                    : [],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                onChanged: (val) => _onSearchChanged(val),
                decoration: InputDecoration(
                  hintText: _isVerified
                      ? '✦ Search the CineFeed PRO universe…'
                      : 'Search posts, accounts...',
                  hintStyle: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _isVerified ? const Color(0xFF00F0FF) : Colors.white54,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white54, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  isCollapsed: false,
                ),
              ),
            ),
          ),

          // ── Tab Bar ───────────────────────────────────────────────────
          if (_searchQuery.isEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: (index) {
                  // Tapping the already-active tab refreshes the feed
                  if (index == _tabController.index) {
                    _fetchPosts(forceRefresh: true);
                  }
                },
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    width: 3,
                    color: _isVerified ? const Color(0xFF00F0FF) : Colors.blueAccent,
                  ),
                  insets: const EdgeInsets.symmetric(horizontal: 30),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14),
                tabs: [
                  Tab(text: AppLocalizations.of(context).forYou),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppLocalizations.of(context).cineVerse),
                        if (_isVerified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0055).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFFFF0055).withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              'LIVE',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFF0055),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(double headerHeight) {
    if (_isSearchingAccounts) {
      return Padding(
        padding: EdgeInsets.only(top: headerHeight + 40),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2),
        ),
      );
    }

    if (_searchedAccounts.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: headerHeight + 60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, color: Colors.white24, size: 50),
              const SizedBox(height: 12),
              Text(
                "No accounts found for '$_searchQuery'",
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: headerHeight + 8, bottom: 40),
      itemCount: _searchedAccounts.length,
      itemBuilder: (context, index) {
        final acc = _searchedAccounts[index];
        final handle = acc['userHandle'] as String;
        final isOwnAccount = handle == _localUserHandle;
        return AccountSearchTile(
          account: acc,
          localHandle: _localUserHandle,
          isOwnAccount: isOwnAccount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                userHandle: handle,
                initialName: acc['userName'] as String?,
                initialAvatar: acc['userAvatar'] as String?,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the list view for the Premium feed.
  Widget _buildFeedList(List<Map<String, dynamic>> posts, double headerHeight) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.cloud_off, color: Colors.white24, size: 50),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty ? "No results found for '$_searchQuery'" : "No posts available",
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00F0FF),
      backgroundColor: const Color(0xFF16181C),
      onRefresh: () => _fetchPosts(forceRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 1500,
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return SizedBox(height: headerHeight);
          final post = posts[index - 1];
          return RepaintBoundary(
            child: SocialFeedCard(
              postId: post['_id'].toString(),
              userName: (post['userHandle'] == _localUserHandle)
                  ? _localUserName
                  : (post['userName'] ?? 'Unknown'),
              userHandle: post['userHandle'] ?? '@unknown',
              userAvatar: (post['userHandle'] == _localUserHandle)
                  ? _localUserAvatar
                  : (post['userAvatar'] ?? ''),
              timeAgo: post['createdAt']?.toString() ?? post['timeAgo'] ?? '',
              text: post['text'],
              images:
                  (post['images'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              videoUrl: post['videoUrl'],
              thumbnailUrl: post['thumbnailUrl'],
              likes: int.tryParse(post['likes']?.toString() ?? '') ?? 0,
              comments: int.tryParse(post['comments']?.toString() ?? '') ?? 0,
              reposts: int.tryParse(post['reposts']?.toString() ?? '') ?? 0,
              isVerified: (post['userHandle'] == _localUserHandle) ? _isVerified : (post['isVerified'] ?? false),
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
              localHandle: _localUserHandle,
              initialIsFollowing: _followingSet.contains(post['userHandle']),
              onLikeChanged: (newCount, isLiked) {
                // Update data map directly — no setState so other cards don't rebuild
                post['likes'] = newCount;
                final likedBy = List<String>.from(post['likedBy'] ?? []);
                if (isLiked) {
                  if (!likedBy.contains(_localUserHandle)) likedBy.add(_localUserHandle);
                } else {
                  likedBy.remove(_localUserHandle);
                }
                post['likedBy'] = likedBy;
              },
              onRepostChanged: (newCount, isReposted) {
                post['reposts'] = newCount;
              },
              onDelete: () => _deletePost(post['_id'], isReel: false),
            ),
          );
        },
      ),
    );
  }

  /// Builds the list view for the non-verified user feed.
  Widget _buildStandardFeedList(List<Map<String, dynamic>> posts, double headerHeight) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline, color: Colors.white24, size: 50),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? "No results found for '$_searchQuery'" : "Follow creators or wait for posts\nto show up here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E1B4B),
      onRefresh: () => _fetchPosts(forceRefresh: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 1500,
        itemCount: posts.length + 1,
        padding: const EdgeInsets.only(bottom: 100),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == 0) return SizedBox(height: headerHeight);
          final post = posts[index - 1];
          return RepaintBoundary(
            child: InstaFeedCard(
              postId: post['_id'].toString(),
              userName: (post['userHandle'] == _localUserHandle)
                  ? _localUserName
                  : (post['userName'] ?? 'Unknown'),
              userHandle: post['userHandle'] ?? '@unknown',
              userAvatar: (post['userHandle'] == _localUserHandle)
                  ? _localUserAvatar
                  : (post['userAvatar'] ?? ''),
              timeAgo: post['createdAt']?.toString() ?? post['timeAgo'] ?? '',
              text: post['text'],
              images:
                  (post['images'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              videoUrl: post['videoUrl'],
              thumbnailUrl: post['thumbnailUrl'],
              likes: int.tryParse(post['likes']?.toString() ?? '') ?? 0,
              comments: int.tryParse(post['comments']?.toString() ?? '') ?? 0,
              reposts: int.tryParse(post['reposts']?.toString() ?? '') ?? 0,
              isVerified: false,
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
              localHandle: _localUserHandle,
              initialIsFollowing: _followingSet.contains(post['userHandle']),
              onLikeChanged: (newCount, isLiked) {
                post['likes'] = newCount;
                final likedBy = List<String>.from(post['likedBy'] ?? []);
                if (isLiked) {
                  if (!likedBy.contains(_localUserHandle)) likedBy.add(_localUserHandle);
                } else {
                  likedBy.remove(_localUserHandle);
                }
                post['likedBy'] = likedBy;
              },
              onRepostChanged: (newCount, isReposted) {
                post['reposts'] = newCount;
              },
              onDelete: () => _deletePost(post['_id'], isReel: true),
            ),
          );
        },
      ),
    );
  }

  /// Builds a TikTok/Reels style full-screen vertical scroller feed
  Widget _buildReelsFeedList(List<Map<String, dynamic>> posts, double headerHeight) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.movie_creation_outlined, color: Colors.white24, size: 50),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty ? "No reels found for '$_searchQuery'" : "No reels available",
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00F0FF),
      backgroundColor: const Color(0xFF16181C),
      onRefresh: () => _fetchPosts(forceRefresh: true),
      child: PageView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: PageScrollPhysics()),
        scrollDirection: Axis.vertical,
        allowImplicitScrolling: true,
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return ReelsFeedCard(
              postId: post['_id'].toString(),
              userName: (post['userHandle'] == _localUserHandle) ? _localUserName : (post['userName'] ?? 'Unknown'),
              userHandle: post['userHandle'] ?? '@unknown',
              userAvatar: (post['userHandle'] == _localUserHandle) ? _localUserAvatar : (post['userAvatar'] ?? ''),
              timeAgo: post['createdAt']?.toString() ?? post['timeAgo'] ?? '',
              text: post['text'],
              images: (post['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              videoUrl: post['videoUrl'],
              thumbnailUrl: post['thumbnailUrl'],
              likes: int.tryParse(post['likes']?.toString() ?? '') ?? 0,
              comments: int.tryParse(post['comments']?.toString() ?? '') ?? 0,
              reposts: int.tryParse(post['reposts']?.toString() ?? '') ?? 0,
              isVerified: (post['userHandle'] == _localUserHandle) ? _isVerified : (post['isVerified'] ?? false),
              commentsList: post['commentsList'] ?? [],
              likedBy: (post['likedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              bookmarkedBy: (post['bookmarkedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              localHandle: _localUserHandle,
              initialIsFollowing: _followingSet.contains(post['userHandle']),
              onLikeChanged: (newCount, isLiked) {
                post['likes'] = newCount;
                final likedBy = List<String>.from(post['likedBy'] ?? []);
                if (isLiked) {
                  if (!likedBy.contains(_localUserHandle)) likedBy.add(_localUserHandle);
                } else {
                  likedBy.remove(_localUserHandle);
                }
                post['likedBy'] = likedBy;
              },
              onRepostChanged: (newCount, isReposted) {
                post['reposts'] = newCount;
              },
              onDelete: () => _deletePost(post['_id'], isReel: true),
            );
        },
      ),
    );
  }
}

