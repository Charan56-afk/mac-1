import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'utils.dart';
import 'package:flutter_application_1/constants.dart';

class DirectorsCutScreen extends StatefulWidget {
  const DirectorsCutScreen({super.key});

  @override
  State<DirectorsCutScreen> createState() => _DirectorsCutScreenState();
}

class _DirectorsCutScreenState extends State<DirectorsCutScreen> {
  final TextEditingController _scriptController = TextEditingController();
  final ScrollController _railScrollController =
      ScrollController(); // Added for timeline sync

  // State for dropdowns
  String _selectedCameraCue = 'Wide Shot';
  String _selectedStyle = 'Cinematic';
  String _selectedSoundscape = 'None';

  final List<String> _cameraCues = [
    'Wide Shot',
    'Close-Up',
    'Medium Shot',
    'Dutch Angle',
    'Low Angle',
    'High Angle',
    'Over the Shoulder',
  ];

  final List<String> _styles = [
    'Cinematic',
    'Cyberpunk',
    'Noir',
    'Watercolor',
    'Anime',
    'Wes Anderson',
    'Gritty Realism',
  ];

  final List<String> _soundscapes = [
    'None',
    'Neon Rain',
    'Noir Jazz',
    'Cinematic Bass',
    'Anime Wind',
    'Synth-wave',
    'Ethereal Chimes',
  ];

  bool _isGenerating = false;
  double _timelineProgress = 0.0; // Reset to 0 when starting
  int _activeFrameIndex = -1;

  // --- UNIFIED AI ENGINE STATE (all 4 run automatically) ---
  int _klingCredits = 10;
  double _cameraPan = 0.0;
  double _cameraZoom = 1.0;
  double _cameraTilt = 0.0;
  String _lumaColorPalette = 'Neon';
  String _lumaScenario = 'Urban';
  bool _characterConsistency = true;

  final List<String> _colorPalettes = [
    'Neon',
    'Warm Gold',
    'Cool Arctic',
    'Monochrome',
    'Vivid Sunset',
    'Deep Teal',
  ];
  final List<String> _scenarios = [
    'Urban',
    'Forest',
    'Space',
    'Underwater',
    'Desert',
    'Rooftop',
    'Rainstorm',
  ];

  final List<Map<String, dynamic>> _storyboardFrames = [];

  // --- SAVED SESSIONS ---
  List<Map<String, dynamic>> _savedSessions =
      []; // [{script, frames, timestamp}]

  XFile? _vibeSeedImage;

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  Future<void> _loadSavedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('dc_saved_sessions');
    if (raw != null) {
      final decoded = json.decode(raw) as List;
      setState(() {
        _savedSessions = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  Future<void> _persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dc_saved_sessions', json.encode(_savedSessions));
  }

  void _archiveCurrentFrames() {
    if (_storyboardFrames.isEmpty) return;
    final session = {
      'script': _scriptController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      'frames': List<Map<String, dynamic>>.from(_storyboardFrames),
    };
    setState(() {
      _savedSessions.insert(0, session); // newest first
      _storyboardFrames.clear();
    });
    _persistSessions();
  }

  void _showSavedSessions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(
                  0xFF1A1A1E,
                ).withValues(alpha: 0.65), // Glassmorphic modal
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          color: Color(0xFF00F0FF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Saved Director\'s Cut',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_savedSessions.length} sessions',
                          style: GoogleFonts.outfit(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _savedSessions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.movie_creation_outlined,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No saved sessions yet',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Generated frames are auto-saved\nwhen you start a new scene',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white24,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _savedSessions.length,
                            itemBuilder: (c, i) {
                              final session = _savedSessions[i];
                              final frames = (session['frames'] as List)
                                  .cast<Map<String, dynamic>>();
                              final ts = DateTime.tryParse(
                                session['timestamp'] ?? '',
                              );
                              final label = ts != null
                                  ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                                  : 'Unknown';
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0D0D14,
                                      ).withValues(alpha: 0.5), // Glass item
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            12,
                                            14,
                                            8,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  session['script'] ??
                                                      'Untitled Scene',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                label,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white38,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height: 100,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.fromLTRB(
                                              14,
                                              0,
                                              14,
                                              12,
                                            ),
                                            itemCount: frames.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(width: 8),
                                            itemBuilder: (c2, j) {
                                              final url =
                                                  frames[j]['imageUrl'] ??
                                                  frames[j]['videoUrl'] ??
                                                  '';
                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: url,
                                                  width: 150,
                                                  height: 90,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, _, _) =>
                                                      Container(
                                                        width: 150,
                                                        color: const Color(
                                                          0xFF1A1A2E,
                                                        ),
                                                        child: const Icon(
                                                          Icons.movie,
                                                          color: Colors.white24,
                                                          size: 30,
                                                        ),
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickVibeSeed() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _vibeSeedImage = image;
      });
    }
  }

  Future<void> _generateStoryboard() async {
    if (_scriptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please enter a scene description first.",
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFFF0055),
        ),
      );
      return;
    }

    // Archive old frames before generating new ones
    _archiveCurrentFrames();

    setState(() {
      _isGenerating = true;
    });

    // All 4 engines run in parallel — up to 2 min
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⚡ All 4 engines generating in parallel… (up to 2 min)',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          duration: const Duration(minutes: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.directorsCut}/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'script': _scriptController.text.trim(),
              'cameraCue': _selectedCameraCue,
              'style': _selectedStyle,
              'soundscape': _selectedSoundscape,
              'hasVibeSeed': _vibeSeedImage != null,
              'cameraSettings': {
                'pan': _cameraPan,
                'zoom': _cameraZoom,
                'tilt': _cameraTilt,
              },
              'lumaSettings': {
                'colorPalette': _lumaColorPalette,
                'scenario': _lumaScenario,
              },
              'characterConsistency': _characterConsistency,
            }),
          )
          .timeout(const Duration(minutes: 15));

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          final clips = data['data']['clips'] as List<dynamic>;
          final script = _scriptController.text.trim();
          setState(() {
            for (final clip in clips) {
              final String? vUrl = clip['videoUrl'] as String?;
              final String? iUrl = clip['imageUrl'] as String?;

              // Resolve relative URLs to full URLs using baseUrl
              final fullVUrl = (vUrl != null && !vUrl.startsWith('http'))
                  ? '$baseUrl$vUrl'
                  : vUrl;
              final fullIUrl = (iUrl != null && !iUrl.startsWith('http'))
                  ? '$baseUrl$iUrl'
                  : iUrl;

              _storyboardFrames.add({
                'videoUrl': fullVUrl,
                'imageUrl': fullIUrl,
                'script': script,
                'cameraCue': _selectedCameraCue,
                'style': _selectedStyle,
                'soundscape': _selectedSoundscape,
                'engine': clip['engine'] as String? ?? 'AI',
                'role': clip['role'] as String? ?? '',
              });
            }
            _isGenerating = false;
            if (_klingCredits > 0) _klingCredits--;
            // Set first frame as active for the new vision
            if (_storyboardFrames.isNotEmpty && _activeFrameIndex == -1) {
              _activeFrameIndex = 0;
              _timelineProgress = 0.5 / _storyboardFrames.length;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎬 ${clips.length} Vision Clips Ready from all engines!',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF00F0FF),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        final errBody = json.decode(response.body);
        throw Exception(
          errBody['error'] ?? 'Server error ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Generation failed: $e',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF0055),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _openPlayer({int initialPage = 0}) {
    showDialog(
      context: context,
      builder: (context) => _StoryboardPlayerDialog(
        frames: _storyboardFrames,
        initialPage: initialPage,
      ),
    );
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _railScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              Color(0xFF1A1B41), // Deep indigo
              Color(0xFF0F0F1A), // Very dark navy
              Colors.black,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF1A1A1E,
                    ).withValues(alpha: 0.5), // Glassmorphic panel
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.05),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- HEADER ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Padding(
                                    padding: EdgeInsets.only(
                                      right: 8.0,
                                      top: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "DIRECTOR'S ",
                                          style: GoogleFonts.outfit(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                            color: Colors.white,
                                            shadows: [
                                                Shadow(
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          "CUT",
                                          style: GoogleFonts.outfit(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                            color: const Color(
                                              0xFFFF5A00,
                                            ), // Vibrant Orange
                                            shadows: [
                                              const Shadow(
                                                color: Color(0xFFFF5A00),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _showSavedSessions,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00F0FF,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00F0FF,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.photo_library_outlined,
                                      color: Color(0xFF00F0FF),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Saved${_savedSessions.isNotEmpty ? ' (${_savedSessions.length})' : ''}',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF00F0FF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Split Color Divider Line
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 2,
                                color: const Color(0xFF00F0FF), // Neon Cyan
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 2,
                                color: const Color(
                                  0xFFFF5A00,
                                ), // Vibrant Orange
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- ALL ENGINES ACTIVE BANNER ---
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00FF88).withValues(alpha: 0.15),
                                const Color(0xFF00F0FF).withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFF00FF88,
                              ).withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00FF88,
                                ).withValues(alpha: 0.1),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bolt,
                                color: Color(0xFF00FF88),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'All engines are active to use',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF00FF88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00FF88),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- STORYBOARD RAIL ---
                        if (_storyboardFrames.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "STORYBOARD RAIL",
                                style: GoogleFonts.outfit(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              GestureDetector(
                                onTap: _openPlayer,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_fill,
                                      color: Color(0xFF00F0FF),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Play Sequence",
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF00F0FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height:
                                140, // Height for 16:9 landscape aspect ratio
                            child: ReorderableListView.builder(
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    final double animValue = Curves.easeInOut
                                        .transform(animation.value);
                                    final double scale = lerpDouble(
                                      1,
                                      1.05,
                                      animValue,
                                    )!;
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: child,
                                );
                              },
                              scrollController: _railScrollController, // Linked
                              scrollDirection: Axis.horizontal,
                              itemCount: _storyboardFrames.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = _storyboardFrames.removeAt(
                                    oldIndex,
                                  );
                                  _storyboardFrames.insert(newIndex, item);

                                  // Keep active frame index in sync
                                  if (_activeFrameIndex == oldIndex) {
                                    _activeFrameIndex = newIndex;
                                  } else if (oldIndex < _activeFrameIndex &&
                                      newIndex >= _activeFrameIndex) {
                                    _activeFrameIndex--;
                                  } else if (oldIndex > _activeFrameIndex &&
                                      newIndex <= _activeFrameIndex) {
                                    _activeFrameIndex++;
                                  }
                                  if (_storyboardFrames.isNotEmpty) {
                                    _timelineProgress =
                                        (_activeFrameIndex /
                                            _storyboardFrames.length) +
                                        (0.5 / _storyboardFrames.length);
                                  }
                                });
                              },
                              itemBuilder: (context, index) {
                                final frame = _storyboardFrames[index];
                                final isActive = index == _activeFrameIndex;

                                return Container(
                                  key: ValueKey(
                                    'rail_${frame['imageUrl']}_${frame['role']}_$index',
                                  ),
                                  width: 240, // Wider thumbnail
                                  margin: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isActive
                                          ? const Color(
                                              0xFFFF5A00,
                                            ) // Orange active border
                                          : Colors.white10,
                                      width: isActive ? 2 : 1,
                                    ),
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFF5A00,
                                              ).withValues(alpha: 0.2),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _activeFrameIndex = index;
                                        _timelineProgress =
                                            (index / _storyboardFrames.length) +
                                            (0.5 / _storyboardFrames.length);
                                      });
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ), // Account for border
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Base Image / thumbnail
                                          CachedNetworkImage(
                                            imageUrl: frame['imageUrl'] ?? '',
                                            fit: BoxFit.cover,
                                            errorWidget: (ctx, url, error) => Container(
                                              color: const Color(0xFF1A1A2E),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.white24,
                                                    size: 32,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Load Failed\nCheck Server IP",
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white24,
                                                      fontSize: 8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Video play icon overlay
                                          if (frame['videoUrl'] != null)
                                            Center(
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.65),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                            ),

                                          // Dark Gradient Overlay for Text
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    12,
                                                    24,
                                                    12,
                                                    12,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.black.withValues(
                                                      alpha: 0.9,
                                                    ),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                              child: Text(
                                                frame['script'],
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Audio Indicator (Top Right)
                                          if (frame['soundscape'] != 'None')
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: const Icon(
                                                Icons.queue_music,
                                                color: Color(0xFF00F0FF),
                                                size: 16,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // --- VIDEO GENERATION COMING SOON ---
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D0D14).withValues(
                                    alpha: 0.4,
                                  ), // Glassmorphic banner
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF5A00,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.videocam_outlined,
                                        color: Color(0xFFFF5A00),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Video Generation',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'AI video clips powered by 4 engines',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white38,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF5A00,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFF5A00,
                                          ).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        'Coming Soon',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFFF5A00),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // --- CONTROLS SECTION (Horizontal Layout) ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Script Input
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  // Header for Script
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF00F0FF,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Color(0xFF00F0FF),
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "SCRIPT",
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Text Area
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "SCRIPT",
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white54,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const Icon(
                                                Icons.chevron_right,
                                                color: Colors.white54,
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextField(
                                          controller: _scriptController,
                                          maxLines: 4,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                "A futuristic detective walks through a neon-lit rainstorm...",
                                            hintStyle: GoogleFonts.outfit(
                                              color: Colors.white24,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(16),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 32),

                            // Right Column: Settings Rows
                            Expanded(
                              flex: 7,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF15151A,
                                  ), // Slightly darker well
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Styles
                                    _buildSelectorRow(
                                      title: "VISUAL STYLE",
                                      items: _styles,
                                      selectedValue: _selectedStyle,
                                      onSelected: (val) =>
                                          setState(() => _selectedStyle = val),
                                      iconType: Icons.image_outlined,
                                    ),
                                    const SizedBox(height: 24),

                                    // Camera
                                    _buildSelectorRow(
                                      title: "CAMERA CUES",
                                      items: _cameraCues,
                                      selectedValue: _selectedCameraCue,
                                      onSelected: (val) => setState(
                                        () => _selectedCameraCue = val,
                                      ),
                                      iconType: Icons.videocam_outlined,
                                      isCircular:
                                          true, // Make these circular to match design
                                    ),
                                    const SizedBox(height: 24),

                                    // Audio
                                    _buildSelectorRow(
                                      title: "AUDIO",
                                      items: _soundscapes,
                                      selectedValue: _selectedSoundscape,
                                      onSelected: (val) => setState(
                                        () => _selectedSoundscape = val,
                                      ),
                                      iconType: Icons.headset,
                                      isCircular: true,
                                    ),
                                    const SizedBox(height: 24),

                                    // Camera Motion (powers Runway)
                                    Row(
                                      children: [
                                        Text(
                                          "CAMERA MOTION",
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF00F0FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.videocam,
                                          color: Color(0xFF00F0FF),
                                          size: 12,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          "via Runway",
                                          style: GoogleFonts.outfit(
                                            color: Colors.white24,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildCameraSlider(
                                      "PAN",
                                      _cameraPan,
                                      -1.0,
                                      1.0,
                                      (v) => setState(() => _cameraPan = v),
                                    ),
                                    _buildCameraSlider(
                                      "ZOOM",
                                      _cameraZoom,
                                      0.5,
                                      2.0,
                                      (v) => setState(() => _cameraZoom = v),
                                    ),
                                    _buildCameraSlider(
                                      "TILT",
                                      _cameraTilt,
                                      -1.0,
                                      1.0,
                                      (v) => setState(() => _cameraTilt = v),
                                    ),
                                    const SizedBox(height: 20),

                                    // Color & Scenario (powers Luma)
                                    Row(
                                      children: [
                                        Text(
                                          "COLOR & SCENARIO",
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFFF5A00),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.color_lens,
                                          color: Color(0xFFFF5A00),
                                          size: 12,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          "via Luma",
                                          style: GoogleFonts.outfit(
                                            color: Colors.white24,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLumaChips(
                                      _lumaColorPalette,
                                      _colorPalettes,
                                      (v) =>
                                          setState(() => _lumaColorPalette = v),
                                      const Color(0xFFFF5A00),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLumaChips(
                                      _lumaScenario,
                                      _scenarios,
                                      (v) => setState(() => _lumaScenario = v),
                                      const Color(0xFFFF5A00),
                                    ),
                                    const SizedBox(height: 20),

                                    // Character Lock (powers DomoAI)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      "CHARACTER LOCK",
                                                      style: GoogleFonts.outfit(
                                                        color: const Color(
                                                          0xFFFF00CC,
                                                        ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.person_pin,
                                                    color: Color(0xFFFF00CC),
                                                    size: 12,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    "via DomoAI",
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white24,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                "Same character across all shots",
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white38,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: _characterConsistency,
                                          activeThumbColor: const Color(
                                            0xFFFF00CC,
                                          ),
                                          activeTrackColor: const Color(
                                            0xFFFF00CC,
                                          ).withValues(alpha: 0.35),
                                          onChanged: (v) => setState(
                                            () => _characterConsistency = v,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Vibe Transfer (Special case)
                                    Row(
                                      children: [
                                        Text(
                                          "VIBE TRANSFER",
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.water_drop_outlined,
                                          color: Colors.white54,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 60,
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: _pickVibeSeed,
                                            child: Container(
                                              width: 60,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.white24,
                                                  style: BorderStyle.solid,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          if (_vibeSeedImage != null)
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: kIsWeb
                                                      ? CachedNetworkImage(
                                                          imageUrl: _vibeSeedImage!.path,
                                                          width: 100,
                                                          height: 60,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Image.file(
                                                          File(
                                                            _vibeSeedImage!
                                                                .path,
                                                          ),
                                                          width: 100,
                                                          height: 60,
                                                          fit: BoxFit.cover,
                                                        ),
                                                ),
                                                Positioned(
                                                  right: 4,
                                                  top: 4,
                                                  child: GestureDetector(
                                                    onTap: () => setState(
                                                      () =>
                                                          _vibeSeedImage = null,
                                                    ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                    ),
                                                  ),
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
                          ],
                        ),
                        const SizedBox(height: 32),
                        // --- TIMELINE EDITOR ---
                        Text(
                          "TIMELINE EDITOR",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1A1A22,
                                ).withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00F0FF,
                                  ).withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Left Track Labels
                                  Container(
                                    width: 40,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildTrackIcon(
                                          Icons.videocam_outlined,
                                          const Color(0xFF00F0FF),
                                        ),
                                        const Spacer(),
                                        _buildTrackIcon(
                                          Icons.music_note_outlined,
                                          const Color(0xFFFF5A00),
                                        ),
                                        const Spacer(),
                                        _buildTrackIcon(
                                          Icons.auto_awesome_outlined,
                                          const Color(0xFFFF00CC),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Main Scrubber Area
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final maxWidth = constraints.maxWidth;
                                        final playheadX =
                                            maxWidth * _timelineProgress;

                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // 1. Time Ruler (Scrubbing Zone)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              right: 0,
                                              height: 30,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.05),
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: List.generate(
                                                    10,
                                                    (i) => Container(
                                                      width: 1,
                                                      height: 5,
                                                      color: Colors.white24,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // 2. Track Lanes (Background)
                                            Positioned(
                                              top: 30,
                                              left: 0,
                                              right: 0,
                                              bottom: 0,
                                              child: Column(
                                                children: [
                                                  _buildTrackLane(
                                                    const Color(
                                                      0xFF00F0FF,
                                                    ).withValues(alpha: 0.03),
                                                  ),
                                                  _buildTrackLane(
                                                    const Color(
                                                      0xFFFF5A00,
                                                    ).withValues(alpha: 0.03),
                                                  ),
                                                  _buildTrackLane(
                                                    const Color(
                                                      0xFFFF00CC,
                                                    ).withValues(alpha: 0.03),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 3. CLIP BLOCKS Reorderable Visualization
                                            if (_storyboardFrames.isNotEmpty)
                                              Positioned(
                                                top: 35,
                                                left: 0,
                                                right: 0,
                                                height: 80,
                                                child: ReorderableListView.builder(
                                                  proxyDecorator: (child, index, animation) { return AnimatedBuilder(animation: animation, builder: (context, child) { final double animValue = Curves.easeInOut.transform(animation.value); final double scale = lerpDouble(1, 1.1, animValue)!; return Transform.scale(scale: scale, child: child); }, child: child); },
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  onReorder: (oldIndex, newIndex) {
                                                    setState(() {
                                                      if (newIndex > oldIndex) {
                                                        newIndex -= 1;
                                                      }
                                                      final item =
                                                          _storyboardFrames
                                                              .removeAt(
                                                                oldIndex,
                                                              );
                                                      _storyboardFrames.insert(
                                                        newIndex,
                                                        item,
                                                      );

                                                      // Keep active frame index in sync
                                                      if (_activeFrameIndex ==
                                                          oldIndex) {
                                                        _activeFrameIndex =
                                                            newIndex;
                                                      } else if (oldIndex <
                                                              _activeFrameIndex &&
                                                          newIndex >=
                                                              _activeFrameIndex) {
                                                        _activeFrameIndex--;
                                                      } else if (oldIndex >
                                                              _activeFrameIndex &&
                                                          newIndex <=
                                                              _activeFrameIndex) {
                                                        _activeFrameIndex++;
                                                      }
                                                      _timelineProgress =
                                                          (_activeFrameIndex /
                                                              _storyboardFrames
                                                                  .length) +
                                                          (0.5 /
                                                              _storyboardFrames
                                                                  .length);
                                                    });
                                                    _syncRailToFrame(
                                                      _activeFrameIndex,
                                                    );
                                                  },
                                                  itemCount:
                                                      _storyboardFrames.length,
                                                  itemBuilder: (context, index) {
                                                    final isActive =
                                                        index ==
                                                        _activeFrameIndex;
                                                    final blockWidth =
                                                        maxWidth /
                                                        _storyboardFrames
                                                            .length;

                                                    return SizedBox(
                                                      key: ValueKey(
                                                        'tl_${_storyboardFrames[index]['imageUrl']}_${_storyboardFrames[index]['role']}_$index',
                                                      ),
                                                      width: blockWidth,
                                                      child: Container(
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 1,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF00F0FF,
                                                                ).withValues(
                                                                  alpha: 0.25,
                                                                )
                                                              : Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.05,
                                                                    ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          border: Border.all(
                                                            color: isActive
                                                                ? const Color(
                                                                    0xFF00F0FF,
                                                                  )
                                                                : Colors
                                                                      .white10,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                3,
                                                              ),
                                                          child: Opacity(
                                                            opacity: isActive
                                                                ? 1.0
                                                                : 0.4,
                                                            child: CachedNetworkImage(
                                                              imageUrl: _storyboardFrames[index]['imageUrl'] ??
                                                                  '',
                                                              fit: BoxFit.cover,
                                                              errorWidget: (_, _, _) => const Center(
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .broken_image_outlined,
                                                                      size: 10,
                                                                      color: Colors
                                                                          .white24,
                                                                    ),
                                                                    Text(
                                                                      "!",
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            8,
                                                                        color: Colors
                                                                            .white24,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                            else
                                              Center(
                                                child: Text(
                                                  "No vision shots yet.",
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white12,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),

                                            // 4. Vertical Playhead Line (Behind the ruler handle but across tracks)
                                            Positioned(
                                              left: playheadX - 1,
                                              top: 0,
                                              bottom: 0,
                                              child: IgnorePointer(
                                                child: Container(
                                                  width: 2,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        const Color(
                                                          0xFF00F0FF,
                                                        ).withValues(
                                                          alpha: 0.0,
                                                        ),
                                                        const Color(0xFF00F0FF),
                                                        const Color(
                                                          0xFF00F0FF,
                                                        ).withValues(
                                                          alpha: 0.0,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // 5. SCRUBBER OVERLAY (Top Ruler Area)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              right: 0,
                                              height: 35,
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onPanUpdate: (details) =>
                                                    _handleScrub(
                                                      details.localPosition.dx,
                                                      maxWidth,
                                                    ),
                                                onPanDown: (details) =>
                                                    _handleScrub(
                                                      details.localPosition.dx,
                                                      maxWidth,
                                                    ),
                                                onTapUp: (details) =>
                                                    _handleScrub(
                                                      details.localPosition.dx,
                                                      maxWidth,
                                                    ),
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Positioned(
                                                      left: playheadX - 10,
                                                      top: 0,
                                                      child:
                                                          _buildPlayheadHandle(
                                                            true,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- BOTTOM ACTION BAR ---
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00F0FF),
                                      Color(0xFFFF0055),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00F0FF,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isGenerating
                                      ? null
                                      : _generateStoryboard,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: _isGenerating
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.movie_creation,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "GENERATE VISION CLIP",
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                  color: Colors.white,
                                                  shadows: [
                                                    const Shadow(
                                                      color: Colors.black45,
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              // Added Expanded to ensure it gets remaining space up to button size.
                              flex: 4,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.1),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.share_outlined,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "SHARE PITCH DECK",
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Icon(
                                      Icons.person_add_outlined,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for horizontal icon selectors
  Widget _buildSelectorRow({
    required String title,
    required List<String> items,
    required String selectedValue,
    required Function(String) onSelected,
    required IconData iconType,
    bool isCircular = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.add, color: Colors.white54, size: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selectedValue == item;

              return GestureDetector(
                onTap: () => onSelected(item),
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00F0FF).withValues(alpha: 0.1)
                        : Colors.transparent,
                    shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: isCircular ? null : BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00F0FF)
                          : Colors.white10,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconType,
                        color: isSelected
                            ? const Color(0xFF00F0FF)
                            : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: isSelected
                              ? const Color(0xFF00F0FF)
                              : Colors.white54,
                          fontSize: 8,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Camera slider (Runway) ---
  Widget _buildCameraSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF00F0FF),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(1),
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // --- Luma color/scenario chips ---
  Widget _buildLumaChips(
    String selected,
    List<String> options,
    ValueChanged<String> onSelect,
    Color accent,
  ) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.map((o) {
          final sel = selected == o;
          return GestureDetector(
            onTap: () => onSelect(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? accent : Colors.white12,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Text(
                o,
                style: GoogleFonts.outfit(
                  color: sel ? accent : Colors.white38,
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- TIMELINE REDESIGN HELPERS ---

  Widget _buildTrackIcon(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Icon(icon, color: color.withValues(alpha: 0.6), size: 16),
    );
  }

  Widget _buildTrackLane(Color color) {
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.02)),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayheadHandle(bool isTop) {
    return Container(
      width: 20,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF),
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(4) : Radius.zero,
          bottom: isTop ? Radius.zero : const Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  void _handleScrub(double localX, double maxWidth) {
    if (_storyboardFrames.isEmpty) return;
    setState(() {
      _timelineProgress = (localX / maxWidth).clamp(0.0, 1.0);
      _activeFrameIndex = (_timelineProgress * _storyboardFrames.length)
          .floor();
      if (_activeFrameIndex >= _storyboardFrames.length) {
        _activeFrameIndex = _storyboardFrames.length - 1;
      }
    });
    _syncRailToFrame(_activeFrameIndex);
  }

  void _syncRailToFrame(int index) {
    if (!_railScrollController.hasClients) return;
    final double offset = index * 256.0; // 240 width + 16 margin
    _railScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
} // end _DirectorsCutScreenState

// Per-frame video player widget (plays real MP4 URLs from AI engines)
// ──────────────────────────────────────────────────────────────────────
class _FrameVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final String? imageUrl;
  final bool autoPlay;

  const _FrameVideoPlayer({
    required this.videoUrl,
    required this.imageUrl,
    this.autoPlay = false,
  });

  @override
  State<_FrameVideoPlayer> createState() => _FrameVideoPlayerState();
}

class _FrameVideoPlayerState extends State<_FrameVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) return;
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl!),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (widget.autoPlay) _controller!.play();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we have a working video controller, show the video
    if (_initialized && _controller != null) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _controller!.value.isPlaying
                ? _controller!.pause()
                : _controller!.play();
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
            // Pause indicator
            if (!_controller!.value.isPlaying)
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Loading / fallback: show image + spinner
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: widget.imageUrl!,
            fit: BoxFit.contain,
            errorWidget: (ctx, url, error) => Container(
              color: const Color(0xFF0D0D14),
              child: const Icon(Icons.movie, color: Colors.white24, size: 60),
            ),
          )
        else
          Container(
            color: const Color(0xFF0D0D14),
            child: const Icon(Icons.movie, color: Colors.white24, size: 60),
          ),
        // Show loading spinner only if we're initialising a video (not error)
        if (widget.videoUrl != null && !_hasError && !_initialized)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00F0FF),
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Full-screen storyboard player dialog
// ──────────────────────────────────────────────────────────────────────
class _StoryboardPlayerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> frames;
  final int initialPage;

  const _StoryboardPlayerDialog({required this.frames, this.initialPage = 0});

  @override
  State<_StoryboardPlayerDialog> createState() =>
      _StoryboardPlayerDialogState();
}

class _StoryboardPlayerDialogState extends State<_StoryboardPlayerDialog> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    _currentIndex = widget.initialPage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Page Viewer (one frame per page) ──
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.frames.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final frame = widget.frames[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video player (or fallback image)
                    _FrameVideoPlayer(
                      videoUrl: frame['videoUrl'] as String?,
                      imageUrl: frame['imageUrl'] as String?,
                      autoPlay: index == _currentIndex,
                    ),

                    // Vignette gradient (bottom)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Metadata overlay (bottom)
                    Positioned(
                      bottom: 40,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Engine badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00F0FF,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF00F0FF,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              frame['engine'] ?? '',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00F0FF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Text(
                            'SHOT ${index + 1}',
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            frame['script'] ?? '',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildMetaChip(
                                Icons.videocam,
                                frame['cameraCue'],
                              ),
                              const SizedBox(width: 8),
                              _buildMetaChip(Icons.palette, frame['style']),
                              if (frame['soundscape'] != 'None') ...[
                                const SizedBox(width: 8),
                                _buildMetaChip(
                                  Icons.queue_music,
                                  frame['soundscape'],
                                  color: const Color(0xFF00F0FF),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── 2. Top Navigation ──
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  '${_currentIndex + 1} / ${widget.frames.length}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 48), // balance close button
              ],
            ),
          ),

          // ── 3. Swipe hint (bottom center) ──
          if (widget.frames.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.frames.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentIndex ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? const Color(0xFF00F0FF)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    IconData icon,
    String? label, {
    Color color = Colors.white70,
  }) {
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

