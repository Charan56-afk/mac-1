import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as ytiframe;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter_application_1/utils.dart';
import 'package:google_fonts/google_fonts.dart';

/// Twitter/X-style auto-playing video player for the CineFeed.
///
/// - Uses media_kit for all network/Cloudinary videos (reliable cross-platform)
/// - Uses YoutubePlayerIframe for YouTube on web
/// - Uses youtube_explode_dart to extract stream URL for YouTube on mobile
/// - Auto-plays **muted** when ≥50% visible
/// - Auto-pauses when < 20% visible
/// - Loops, slim progress bar, tap to play/pause, tap speaker to mute/unmute
/// - Fast Forward (10s) and Rewind (10s) via buttons or double-tap
class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool isReel;

  const FeedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = true,
    this.isReel = false,
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  mk.Player? _player;
  VideoController? _mkController;
  ytiframe.YoutubePlayerController? _ytController;
  vp.VideoPlayerController? _vpController;

  bool _initialized = false;
  bool _initFailed = false;
  bool _isMuted = true;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  bool _disposed = false;
  bool _isYouTubeWeb = false;
  int? _videoWidth;
  int? _videoHeight;

  Timer? _hideControlsTimer;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;

  final Key _visibilityKey = UniqueKey();

  // ── Global mute state shared across ALL FeedVideoPlayer instances ──
  // When the user unmutes one video, the next video also plays with sound.
  static final ValueNotifier<bool> globalMuted = ValueNotifier(true);

  void _onGlobalMuteChanged() {
    if (_disposed || !mounted) return;
    // Only sync when global becomes UNMUTED (sound turned on by another video).
    // Individual muting of a video is local and does not affect others.
    if (globalMuted.value == true) return;
    if (_isMuted == false) return; // already unmuted, nothing to do
    setState(() => _isMuted = false);
    if (_isYouTubeWeb && _ytController != null) {
      _ytController!.unMute();
    } else {
      _player?.setVolume(100);
    }
  }

  @override
  void initState() {
    super.initState();
    // Reels always start unmuted; regular feed cards respect global state
    _isMuted = widget.isReel ? false : globalMuted.value;
    globalMuted.addListener(_onGlobalMuteChanged);
    // Initialize player eagerly — no frame delay, so videos load ASAP
    _initPlayer(playImmediately: false);
  }

  static String _resolveVideoUrl(String url) {
    if (url.contains('player.cloudinary.com/embed')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final cloudName = uri.queryParameters['cloud_name'];
        final publicId = uri.queryParameters['public_id'];
        if (cloudName != null && publicId != null) {
          return 'https://res.cloudinary.com/$cloudName/video/upload/$publicId.mp4';
        }
      }
    }
    return url;
  }

  Future<void> _initPlayer({bool playImmediately = true}) async {
    if (_initialized || _disposed) return;
    _initialized = true;

    String finalPlayUrl = '';
    try {
      final url = _resolveVideoUrl(widget.videoUrl);
      final bool isYouTube = url.contains('youtube.com') || url.contains('youtu.be');

      if (kIsWeb && isYouTube) {
        _isYouTubeWeb = true;
        String videoId = url;
        try { videoId = yt.VideoId.parseVideoId(url) ?? url; } catch (_) {}

        _ytController = ytiframe.YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: playImmediately,
          params: ytiframe.YoutubePlayerParams(
            showControls: false,
            mute: !widget.isReel,
            loop: true,
          ),
        );

        _ytController!.listen((event) {
          if (_disposed || !mounted) return;
          final playing = event.playerState == ytiframe.PlayerState.playing;
          if (playing != _isPlaying) setState(() => _isPlaying = playing);
        });
        if (mounted) setState(() => _isMuted = !widget.isReel);
        return;
      }

      finalPlayUrl = url;
      if (isYouTube) {
        final cached = CacheUtility.getCachedYtUrl(url);
        if (cached != null) {
          finalPlayUrl = cached;
        } else {
          final ytExplode = yt.YoutubeExplode();
          try {
            final videoId = yt.VideoId.parseVideoId(url) ?? url;
            final manifest = await ytExplode.videos.streamsClient.getManifest(videoId);
            finalPlayUrl = manifest.muxed.withHighestBitrate().url.toString();
            CacheUtility.cacheYtUrl(url, finalPlayUrl);
          } catch (_) {} finally { ytExplode.close(); }
        }
      }

      _player = mk.Player();
      _mkController = VideoController(_player!);

      _playingSub = _player!.stream.playing.listen((playing) {
        if (_disposed || !mounted) return;
        if (playing != _isPlaying) setState(() => _isPlaying = playing);
      });

      _player!.stream.width.distinct().listen((w) {
        if (mounted && !_disposed && w != _videoWidth) setState(() => _videoWidth = w);
      });

      _player!.stream.height.distinct().listen((h) {
        if (mounted && !_disposed && h != _videoHeight) setState(() => _videoHeight = h);
      });

      _errorSub = _player!.stream.error.listen((err) {
        debugPrint('FeedVideoPlayer error: $err');
        if (mounted && !_disposed) setState(() => _initFailed = true);
      });

      // Use globalMuted so new players respect the user's last mute preference
      final shouldMute = widget.isReel ? false : globalMuted.value;
      await _player!.setVolume(shouldMute ? 0 : 100);
      if (mounted) setState(() => _isMuted = shouldMute);
      await _player!.setPlaylistMode(mk.PlaylistMode.loop);
      await _player!.open(mk.Media(finalPlayUrl), play: playImmediately);

      if (mounted) setState(() => _initFailed = false);
    } catch (e) {
      debugPrint('FeedVideoPlayer MediaKit initialization failed: $e, falling back to standard video_player');
      try {
        final shouldMute = widget.isReel ? false : globalMuted.value;
        _vpController = vp.VideoPlayerController.networkUrl(Uri.parse(finalPlayUrl));
        await _vpController!.initialize();
        await _vpController!.setLooping(true);
        await _vpController!.setVolume(shouldMute ? 0.0 : 1.0);
        if (playImmediately) {
          await _vpController!.play();
        }
        _vpController!.addListener(() {
          if (_disposed || !mounted) return;
          final playing = _vpController!.value.isPlaying;
          if (playing != _isPlaying) {
            setState(() => _isPlaying = playing);
          }
        });
        if (mounted) {
          setState(() {
            _isMuted = shouldMute;
            _initialized = true;
            _initFailed = false;
          });
        }
      } catch (fallbackError) {
        debugPrint('FeedVideoPlayer Fallback Error: $fallbackError');
        if (mounted && !_disposed) setState(() => _initFailed = true);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    globalMuted.removeListener(_onGlobalMuteChanged);
    _hideControlsTimer?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _player?.dispose();
    _player = null;
    _mkController = null;
    _ytController?.close();
    _ytController = null;
    _vpController?.dispose();
    _vpController = null;
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_disposed) return;
    if (info.visibleFraction >= 0.40) {
      // Play when 40% or more of the video is visible (lower threshold = faster start)
      if (!_initialized) {
        _initPlayer(playImmediately: true);
      } else {
        if (_isYouTubeWeb) { 
          _ytController?.playVideo(); 
        } else if (_player != null) { 
          _player?.play(); 
        } else if (_vpController != null) {
          _vpController?.play();
        }
      }
    } else if (info.visibleFraction < 0.15) {
      // Pause when less than 15% is visible (keeps video running longer during fast scroll)
      if (_isYouTubeWeb) { 
        _ytController?.pauseVideo(); 
      } else if (_player != null) { 
        _player?.pause(); 
      } else if (_vpController != null) {
        _vpController?.pause();
      }
    }
  }

  void _togglePlay() {
    if (_disposed) return;
    if (!_initialized) { _initPlayer(playImmediately: true); return; }

    if (_isYouTubeWeb && _ytController != null) {
      if (_isPlaying) { _ytController!.pauseVideo(); } else { _ytController!.playVideo(); }
      _flashControls();
      return;
    }

    if (_player != null) {
      if (_isPlaying) { _player!.pause(); } else { _player!.play(); }
    } else if (_vpController != null) {
      if (_vpController!.value.isPlaying) { _vpController!.pause(); } else { _vpController!.play(); }
    }
    _flashControls();
  }

  void _toggleMute() {
    if (_disposed) return;
    final newMuted = !_isMuted;
    setState(() => _isMuted = newMuted);
    if (_isYouTubeWeb && _ytController != null) {
      if (newMuted) { _ytController!.mute(); } else { _ytController!.unMute(); }
    } else if (_player != null) {
      _player?.setVolume(newMuted ? 0 : 100);
    } else if (_vpController != null) {
      _vpController?.setVolume(newMuted ? 0.0 : 1.0);
    }
    // Only broadcast globally when UNMUTING (turning sound ON).
    // Muting a single video is a local action and doesn't silence others.
    if (!newMuted) {
      globalMuted.value = false;
    }
    _flashControls();
  }

  Future<void> _seekRelative(Duration offset) async {
    if (_disposed) return;
    if (_isYouTubeWeb && _ytController != null) {
      final double currentTime = await _ytController!.currentTime;
      _ytController!.seekTo(seconds: currentTime + offset.inSeconds.toDouble(), allowSeekAhead: true);
    } else if (_player != null) {
      final currentPos = _player!.state.position;
      _player!.seek(currentPos + offset);
    } else if (_vpController != null) {
      final currentPos = _vpController!.value.position;
      _vpController!.seekTo(currentPos + offset);
    }
    _flashControls();
  }

  void _flashControls() {
    if (_disposed) return;
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_disposed) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isReel) {
      return VisibilityDetector(
        key: _visibilityKey,
        onVisibilityChanged: _onVisibilityChanged,
        child: Container(width: double.infinity, height: double.infinity, color: Colors.black, child: _buildContent()),
      );
    }

    double currentAspectRatio = 16 / 9;
    if (_videoWidth != null && _videoHeight != null && _videoHeight! > 0) {
      currentAspectRatio = _videoWidth! / _videoHeight!;
      if (currentAspectRatio < 0.5) currentAspectRatio = 0.5;
      if (currentAspectRatio > 2.5) currentAspectRatio = 2.5;
    } else if (_vpController != null && _vpController!.value.isInitialized) {
      currentAspectRatio = _vpController!.value.aspectRatio;
    }

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          color: Colors.black,
          child: AspectRatio(aspectRatio: currentAspectRatio, child: _buildContent()),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_initFailed) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40), SizedBox(height: 8), Text('Video unavailable', style: TextStyle(color: Colors.white38, fontSize: 13))],));
    }

    if (!_initialized || (!_isYouTubeWeb && _mkController == null && _vpController == null)) {
      return GestureDetector(
        onTap: _initPlayer,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              color: const Color(0xFF111111),
              child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorWidget: (c, u, e) => const Center(child: Icon(Icons.movie_outlined, color: Colors.white12, size: 48)))
                  : const Center(child: Icon(Icons.movie_outlined, color: Colors.white12, size: 48)),
            ),
            if (_initialized && !_initFailed) const CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2)
            else Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54, border: Border.all(color: Colors.white70, width: 2)), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32)),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video surface
        if (!_isFullscreen)
          if (_isYouTubeWeb && _ytController != null)
            Stack(fit: StackFit.expand, children: [ytiframe.YoutubePlayer(controller: _ytController!), Positioned.fill(child: PointerInterceptor(child: const ColoredBox(color: Colors.transparent)))])
          else if (_mkController != null)
            Video(controller: _mkController!, controls: null, fit: BoxFit.contain)
          else if (_vpController != null && _vpController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _vpController!.value.aspectRatio,
                child: vp.VideoPlayer(_vpController!),
              ),
            ),

        // 2. Gesture Seek Zones (Overlaid on video)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _seekRelative(const Duration(seconds: -5)),
                onTap: _togglePlay,
              ),
            ),
            Expanded(flex: 2, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _togglePlay)),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _seekRelative(const Duration(seconds: 5)),
                onTap: _togglePlay,
              ),
            ),
          ],
        ),

        // 3. Pause overlay
        if (!_isPlaying)
          IgnorePointer(
            child: Container(color: Colors.black38, child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56))),
          ),

        // 4. Controls Row
        Positioned(
          bottom: widget.isReel ? null : 10,
          top: widget.isReel ? 50 : null,
          right: 10,
          child: Row(
            children: [
              // Rewind Button (10s back)
              GestureDetector(
                onTap: () => _seekRelative(const Duration(seconds: -10)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.fast_rewind_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              // Fast Forward Button (10s forward)
              GestureDetector(
                onTap: () => _seekRelative(const Duration(seconds: 10)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleMute,
                child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle), child: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 18)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _isFullscreen = true);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        if (_isYouTubeWeb && _ytController != null) {
                          return FullScreenYoutubeViewer(ytController: _ytController!);
                        } else if (_player != null && _mkController != null) {
                          return FullScreenMediaKitViewer(
                            player: _player!,
                            controller: _mkController!,
                          );
                        } else if (_vpController != null) {
                          return FullScreenStandardViewer(vpController: _vpController!);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ).then((_) {
                    if (mounted) setState(() => _isFullscreen = false);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 5. Slim progress bar — isolated widget so only it repaints at stream rate
        if (!_isYouTubeWeb && _player != null)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _ProgressBar(player: _player!),
          )
        else if (_vpController != null)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: vp.VideoProgressIndicator(
              _vpController!,
              allowScrubbing: false,
              colors: const vp.VideoProgressColors(
                playedColor: Color(0xFF00F0FF),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
      ],
    );
  }
}

class FullScreenYoutubeViewer extends StatefulWidget {
  final ytiframe.YoutubePlayerController ytController;
  const FullScreenYoutubeViewer({
    super.key,
    required this.ytController,
  });
  @override
  State<FullScreenYoutubeViewer> createState() => _FullScreenYoutubeViewerState();
}

class _FullScreenYoutubeViewerState extends State<FullScreenYoutubeViewer> {
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    widget.ytController.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = event.playerState == ytiframe.PlayerState.playing;
          _totalDuration = event.metaData.duration;
        });
      }
    });

    widget.ytController.videoStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentPosition = state.position;
        });
      }
    });

    widget.ytController.playVideo();
    _startControlsTimer();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controlsTimer?.cancel();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _seekRelative(Duration offset) {
    final target = _currentPosition + offset;
    final clamped = target < Duration.zero 
        ? Duration.zero 
        : (target > _totalDuration ? _totalDuration : target);
    widget.ytController.seekTo(seconds: clamped.inSeconds.toDouble(), allowSeekAhead: true);
  }

  void _togglePlay() {
    if (_isPlaying) {
      widget.ytController.pauseVideo();
    } else {
      widget.ytController.playVideo();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        widget.ytController.mute();
      } else {
        widget.ytController.unMute();
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ytiframe.YoutubePlayer(controller: widget.ytController),
                    Positioned.fill(
                      child: PointerInterceptor(
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  color: Colors.black38,
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                _seekRelative(const Duration(seconds: -10));
                                _startControlsTimer();
                              },
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                color: const Color(0xFF00F0FF),
                                size: 72,
                              ),
                              onPressed: () {
                                _togglePlay();
                                _startControlsTimer();
                              },
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                _seekRelative(const Duration(seconds: 10));
                                _startControlsTimer();
                              },
                            ),
                          ],
                        ),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF00F0FF),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFF00F0FF),
                                  overlayColor: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                ),
                                child: Slider(
                                  value: _currentPosition.inMilliseconds.toDouble().clamp(0, _totalDuration.inMilliseconds.toDouble()),
                                  min: 0.0,
                                  max: _totalDuration.inMilliseconds.toDouble() > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0,
                                  onChanged: (val) {
                                    setState(() {
                                      _currentPosition = Duration(milliseconds: val.toInt());
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    widget.ytController.seekTo(seconds: val / 1000, allowSeekAhead: true);
                                    _startControlsTimer();
                                  },
                                ),
                              ),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      _toggleMute();
                                      _startControlsTimer();
                                    },
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenMediaKitViewer extends StatefulWidget {
  final mk.Player player;
  final VideoController controller;
  const FullScreenMediaKitViewer({
    super.key,
    required this.player,
    required this.controller,
  });
  @override
  State<FullScreenMediaKitViewer> createState() => _FullScreenMediaKitViewerState();
}

class _FullScreenMediaKitViewerState extends State<FullScreenMediaKitViewer> {
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _playingSub = widget.player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _positionSub = widget.player.stream.position.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
    _durationSub = widget.player.stream.duration.listen((dur) {
      if (mounted) setState(() => _totalDuration = dur);
    });

    widget.player.play();
    _startControlsTimer();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controlsTimer?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _seekRelative(Duration offset) {
    final target = _currentPosition + offset;
    final clamped = target < Duration.zero 
        ? Duration.zero 
        : (target > _totalDuration ? _totalDuration : target);
    widget.player.seek(clamped);
  }

  void _togglePlay() {
    if (_isPlaying) {
      widget.player.pause();
    } else {
      widget.player.play();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.player.setVolume(_isMuted ? 0 : 100);
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Center(
              child: Video(
                      controller: widget.controller,
                      controls: null,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
          
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  color: Colors.black38,
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                _seekRelative(const Duration(seconds: -10));
                                _startControlsTimer();
                              },
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                color: const Color(0xFF00F0FF),
                                size: 72,
                              ),
                              onPressed: () {
                                _togglePlay();
                                _startControlsTimer();
                              },
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                _seekRelative(const Duration(seconds: 10));
                                _startControlsTimer();
                              },
                            ),
                          ],
                        ),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF00F0FF),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFF00F0FF),
                                  overlayColor: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                ),
                                child: Slider(
                                  value: _currentPosition.inMilliseconds.toDouble().clamp(0, _totalDuration.inMilliseconds.toDouble()),
                                  min: 0.0,
                                  max: _totalDuration.inMilliseconds.toDouble() > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0,
                                  onChanged: (val) {
                                    setState(() {
                                      _currentPosition = Duration(milliseconds: val.toInt());
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    widget.player.seek(Duration(milliseconds: val.toInt()));
                                    _startControlsTimer();
                                  },
                                ),
                              ),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      _toggleMute();
                                      _startControlsTimer();
                                    },
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenStandardViewer extends StatefulWidget {
  final vp.VideoPlayerController vpController;
  const FullScreenStandardViewer({
    super.key,
    required this.vpController,
  });
  @override
  State<FullScreenStandardViewer> createState() => _FullScreenStandardViewerState();
}

class _FullScreenStandardViewerState extends State<FullScreenStandardViewer> {
  bool _initialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    widget.vpController.addListener(_listener);
    _totalDuration = widget.vpController.value.duration;
    _isPlaying = widget.vpController.value.isPlaying;
    _initialized = widget.vpController.value.isInitialized;
    widget.vpController.play();
    _startControlsTimer();
  }

  void _listener() {
    if (!mounted) return;
    setState(() {
      _isPlaying = widget.vpController.value.isPlaying;
      _currentPosition = widget.vpController.value.position;
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controlsTimer?.cancel();
    widget.vpController.removeListener(_listener);
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _seekRelative(Duration offset) {
    final target = _currentPosition + offset;
    final clamped = target < Duration.zero 
        ? Duration.zero 
        : (target > _totalDuration ? _totalDuration : target);
    widget.vpController.seekTo(clamped);
  }

  void _togglePlay() {
    if (_isPlaying) {
      widget.vpController.pause();
    } else {
      widget.vpController.play();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.vpController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Center(
              child: !_initialized
                  ? const CircularProgressIndicator(color: Color(0xFF00F0FF))
                  : AspectRatio(
                      aspectRatio: widget.vpController.value.aspectRatio,
                      child: vp.VideoPlayer(widget.vpController),
                    ),
            ),
          ),
          
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  color: Colors.black38,
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                _seekRelative(const Duration(seconds: -10));
                                _startControlsTimer();
                              },
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                color: const Color(0xFF00F0FF),
                                size: 72,
                              ),
                              onPressed: () {
                                _togglePlay();
                                _startControlsTimer();
                              },
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                _seekRelative(const Duration(seconds: 10));
                                _startControlsTimer();
                              },
                            ),
                          ],
                        ),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF00F0FF),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFF00F0FF),
                                  overlayColor: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                ),
                                child: Slider(
                                  value: _currentPosition.inMilliseconds.toDouble().clamp(0, _totalDuration.inMilliseconds.toDouble()),
                                  min: 0.0,
                                  max: _totalDuration.inMilliseconds.toDouble() > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0,
                                  onChanged: (val) {
                                    setState(() {
                                      _currentPosition = Duration(milliseconds: val.toInt());
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    widget.vpController.seekTo(Duration(milliseconds: val.toInt()));
                                    _startControlsTimer();
                                  },
                                ),
                              ),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      _toggleMute();
                                      _startControlsTimer();
                                    },
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Isolated progress bar — only THIS widget repaints at the stream emission rate.
/// The parent FeedVideoPlayer build() is NOT triggered.
class _ProgressBar extends StatelessWidget {
  final mk.Player player;
  const _ProgressBar({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, posSnap) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (context, durSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;
            final progress = dur.inMilliseconds > 0
                ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                : 0.0;
            return LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
              minHeight: 2,
            );
          },
        );
      },
    );
  }
}

