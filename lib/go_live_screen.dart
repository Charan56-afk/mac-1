import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'utils.dart'; // to get serverIp and CacheUtility

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCamera = 0; 
  bool _cameraReady = false;
  bool _cameraPermissionDenied = false;

  // WebSockets
  WebSocket? _socket;
  String _streamId = '';
  bool _isBroadcasting = false;
  bool _isMuted = false;
  bool _flashOn = false;

  // Broadcast setup
  final _titleController = TextEditingController();
  String? _thumbnailBase64;
  String _displayName = 'Broadcaster';
  String _avatarUrl = '';
  String _accountType = 'User';
  bool _checkingAccess = true;

  // Verification flow for Certified/Production/Event managers
  bool _isVerified = false;
  int _verificationStep = 1; // 1: Credentials, 2: OTP
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  String _generatedOtp = '';
  String? _otpError;
  String? _credentialsError;
  // Live stats
  int _viewerCount = 0;
  int _likeCount = 0;
  int _broadcastSeconds = 0;
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _chatScroll = ScrollController();

  // Timers
  Timer? _durationTimer;
  Timer? _frameTimer;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _likeController;
  late Animation<double> _pulseAnim;
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
      duration: const Duration(milliseconds: 300),
    );
    _loadUserInfo();
    // Do not call _initCamera() immediately in initState anymore,
    // we will initialize the camera after credentials + OTP verification is successful!
  }

  Future<void> _loadUserInfo() async {
    final name = await CacheUtility.getProfileValue('name');
    final avatar = await CacheUtility.getProfileValue('avatar');
    final type = await CacheUtility.getProfileValue('accountType');
    final handle = await CacheUtility.getProfileValue('handle');
    if (mounted) {
      setState(() {
        if (name != null) _displayName = name;
        if (avatar != null) _avatarUrl = avatar;
        if (type != null) _accountType = type;
        if (handle != null) {
          _usernameController.text = handle;
        }
        _checkingAccess = false;
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraPermissionDenied = true);
        return;
      }
      
      // Default to front camera for livestream
      int defaultIdx = 0;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.front) {
          defaultIdx = i;
          break;
        }
      }
      
      _selectedCamera = defaultIdx;
      await _startCamera(defaultIdx);
    } catch (e) {
      debugPrint('Camera init error: $e');
      setState(() => _cameraPermissionDenied = true);
    }
  }

  Future<void> _startCamera(int idx) async {
    if (_cameras.isEmpty || idx >= _cameras.length) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Dispose old controller first to release hardware resources and prevent camera locks
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      final controller = CameraController(
        _cameras[idx],
        ResolutionPreset.max, // Use maximum available resolution for crystal clear premium video quality
        enableAudio: !_isMuted,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _cameraReady = true;
        });
      } else {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('Camera start error: $e');
      if (mounted) {
        setState(() {
          _cameraReady = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    final currentDir = _cameras[_selectedCamera].lensDirection;
    int nextIdx = _selectedCamera;
    
    // Find the camera with the opposite direction
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection != currentDir) {
        nextIdx = i;
        break;
      }
    }
    
    if (nextIdx != _selectedCamera) {
      _selectedCamera = nextIdx;
      setState(() => _cameraReady = false);
      await _startCamera(nextIdx);
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      if (_flashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  Future<void> _startBroadcast() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a broadcast title first!')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    _streamId = 'stream_${DateTime.now().millisecondsSinceEpoch}';

    // ── Connect WebSocket ──
    try {
      final ip = serverIp;
      _socket = await WebSocket.connect('ws://$ip:5000').timeout(
        const Duration(seconds: 5),
      );

      _socket!.listen(
        (message) {
          final data = json.decode(message);
          if (data['type'] == 'stats_update') {
            setState(() {
              _viewerCount = data['viewersCount'];
              _likeCount = data['likes'];
            });
          } else if (data['type'] == 'chat_message') {
            setState(() {
              _chatMessages.add({
                'user': data['comment']['username'],
                'msg': data['comment']['message'],
              });
            });
            _scrollChat();
          }
        },
        onError: (err) {
          debugPrint('WS Stream error: $err');
        },
        onDone: () {
          debugPrint('WS Closed by server');
        },
      );

      // Create stream
      _wsSend({
        'type': 'create_stream',
        'streamId': _streamId,
        'title': title,
        'host': _displayName,
        'hostAvatar': _avatarUrl,
      });

      setState(() {
        _isBroadcasting = true;
      });

      // Broadcast duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _broadcastSeconds++);
      });

      // Frame streaming timer (every 400ms takes a frame and streams)
      _frameTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        if (!_isBroadcasting || _cameraController == null || !_cameraController!.value.isInitialized) return;
        try {
          final file = await _cameraController!.takePicture();
          final bytes = await file.readAsBytes();
          final base64String = base64Encode(bytes);
          
          _wsSend({
            'type': 'video_frame',
            'streamId': _streamId,
            'frame': base64String,
          });
        } catch (e) {
          debugPrint('Failed to stream frame: $e');
        }
      });

    } catch (e) {
      debugPrint('WS Connection failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to start stream server connection: $e')),
      );
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

  void _endBroadcast() {
    _wsSend({'type': 'end_stream', 'streamId': _streamId});
    
    _frameTimer?.cancel();
    _durationTimer?.cancel();
    _socket?.close();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sensors_off, color: Color(0xFFFF0055), size: 48),
              const SizedBox(height: 16),
              Text(
                'Broadcast Finished',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Duration: ${_formatDuration(_broadcastSeconds)}\nReal Viewers: $_viewerCount\nTotal Likes: $_likeCount',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // exit Go Live screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F0FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Close Studio',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    _likeController.dispose();
    _cameraController?.dispose();
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _chatScroll.dispose();
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF0055)),
        ),
      );
    }
    
    final bool isAuthorized = _accountType == 'Certified User' ||
        _accountType == 'Production House' ||
        _accountType == 'Event Manager';
        
    if (!isAuthorized) {
      return _buildAccessDeniedUI();
    }

    if (!_isVerified) {
      return _buildVerificationFlowUI();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraPermissionDenied
          ? _buildNoCameraUI()
          : _cameraReady
              ? _isBroadcasting
                  ? _buildLiveStudio()
                  : _buildSetupScreen()
              : const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF0055)),
                ),
    );
  }

  Widget _buildVerificationFlowUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          'BROADCASTER AUTH',
          style: GoogleFonts.spaceMono(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A15),
              Color(0xFF050510),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),
                    child: child,
                  ),
                );
              },
              child: _verificationStep == 1
                  ? _buildCredentialsForm()
                  : _buildOtpForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialsForm() {
    return Container(
      key: const ValueKey('credentials_form'),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF00F0FF),
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Sign In to Broadcast',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Verification required for $_accountType',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_credentialsError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0055).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF0055).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF0055), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _credentialsError!,
                      style: GoogleFonts.outfit(color: const Color(0xFFFF0055), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'USERNAME / HANDLE',
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF00F0FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '@username',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.black26,
              prefixIcon: const Icon(Icons.alternate_email, color: Colors.white54),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PASSWORD / ACCESS KEY',
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF00F0FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter account password',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.black26,
              prefixIcon: const Icon(Icons.lock_rounded, color: Colors.white54),
              suffixIcon: Tooltip(
                message: 'Hint: cinesocial123',
                child: const Icon(Icons.help_outline, color: Colors.white54),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hint: Use password "cinesocial123" to authenticate.',
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _validateCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.4),
            ),
            child: Text(
              'CONTINUE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm() {
    return Container(
      key: const ValueKey('otp_form'),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00F0FF).withValues(alpha: 0.2),
                  const Color(0xFF9D00FF).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.key, color: Color(0xFF00F0FF), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CineSocial OTP (Simulated)',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF00F0FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your verification code is: $_generatedOtp',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Two-Factor Authentication',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the 6-digit verification code sent to your registered CineSocial device.',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_otpError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0055).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF0055).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF0055), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _otpError!,
                      style: GoogleFonts.outfit(color: const Color(0xFFFF0055), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '6-DIGIT CODE',
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF00F0FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otpController,
            style: GoogleFonts.spaceMono(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
              filled: true,
              fillColor: Colors.black26,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _verificationStep = 1;
                    _otpError = null;
                  });
                },
                child: Text(
                  'Change credentials',
                  style: GoogleFonts.outfit(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: _generateAndShowOtp,
                child: Text(
                  'Resend OTP',
                  style: GoogleFonts.outfit(color: const Color(0xFF00F0FF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _validateOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.4),
              elevation: 4,
            ),
            child: Text(
              'VERIFY & ACCESS STUDIO',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _validateCredentials() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      setState(() {
        _credentialsError = 'Please enter your username or handle.';
      });
      return;
    }

    if (password != 'cinesocial123') {
      setState(() {
        _credentialsError = 'Incorrect password/access key. (Hint: cinesocial123)';
      });
      return;
    }

    setState(() {
      _credentialsError = null;
      _generateAndShowOtp();
      _verificationStep = 2;
    });
  }

  void _generateAndShowOtp() {
    final rand = Random();
    final code = 100000 + rand.nextInt(900000);
    setState(() {
      _generatedOtp = code.toString();
      _otpController.clear();
      _otpError = null;
    });
  }

  void _validateOtp() {
    final otpVal = _otpController.text.trim();
    if (otpVal != _generatedOtp) {
      setState(() {
        _otpError = 'Invalid code. Please enter the correct 6-digit OTP code.';
      });
      return;
    }

    setState(() {
      _otpError = null;
    });
    _onVerificationSuccess();
  }

  void _onVerificationSuccess() {
    setState(() {
      _isVerified = true;
    });
    _initCamera();
  }

  Widget _buildAccessDeniedUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A15),
              Color(0xFF050510),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFFF0055),
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Access Restricted',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Going Live is only available for Certified Users, Production Houses, and Event Managers.',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0055),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Go Back',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  Widget _buildNoCameraUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Go Live', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography, color: Colors.white24, size: 72),
              const SizedBox(height: 24),
              Text(
                'Camera Access Denied',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please allow Camera & Microphone access in your device settings to go live.',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0055),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Stack(
      children: [
        // Camera preview background
        SizedBox.expand(
          child: CameraPreview(_cameraController!),
        ),

        // Dark gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xEE000000),
              ],
              stops: [0, 0.25, 0.65, 1],
            ),
          ),
        ),

        // Top bar
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      'Live Broadcast Setup',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _flipCamera,
                      icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom setup panel
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail picker
                  GestureDetector(
                    onTap: _pickThumbnail,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: _thumbnailBase64 != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                base64Decode(_thumbnailBase64!.split(',').last),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate, color: Colors.white38, size: 24),
                                const SizedBox(width: 10),
                                Text(
                                  'Add Thumbnail (optional)',
                                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Title input
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Enter broadcast title...',
                      hintStyle: GoogleFonts.outfit(color: Colors.white30),
                      prefixIcon: const Icon(Icons.edit, color: Colors.white30, size: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFF0055), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Go Live button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _startBroadcast,
                      icon: const Icon(Icons.sensors, size: 20),
                      label: Text(
                        'Start Broadcast Now',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0055),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final mime = image.mimeType ?? 'image/jpeg';
      setState(() {
        _thumbnailBase64 = 'data:$mime;base64,${base64Encode(bytes)}';
      });
    }
  }

  Widget _buildLiveStudio() {
    return Stack(
      children: [
        // Full-screen camera preview
        SizedBox.expand(
          child: CameraPreview(_cameraController!),
        ),

        // Gradient overlays
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xBB000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xDD000000),
              ],
              stops: [0, 0.2, 0.5, 1],
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

              // ── BOTTOM CONTROLS ──
              _buildBottomControls(),
            ],
          ),
        ),
      ],
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

          // Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDuration(_broadcastSeconds),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 8),

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
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Flip camera
          _circleBtn(Icons.flip_camera_android, _flipCamera),
          const SizedBox(width: 8),

          // Mute
          _circleBtn(
            _isMuted ? Icons.mic_off : Icons.mic,
            () {
              setState(() {
                _isMuted = !_isMuted;
                // Reinitialize camera with mute setting
                _startCamera(_selectedCamera);
              });
            },
            color: _isMuted ? const Color(0xFFFF0055) : Colors.white24,
          ),
          const SizedBox(width: 8),

          // Flash (back camera only)
          if (_cameraController != null && 
              _cameras.isNotEmpty && 
              _cameras[_selectedCamera].lensDirection == CameraLensDirection.back)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _circleBtn(
                _flashOn ? Icons.flash_on : Icons.flash_off,
                _toggleFlash,
                color: _flashOn ? Colors.amber : Colors.white24,
              ),
            ),

          // Close
          _circleBtn(Icons.close, () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                title: Text('End Broadcast?', style: GoogleFonts.outfit(color: Colors.white)),
                content: Text('Your live stream will end for all viewers.', style: GoogleFonts.outfit(color: Colors.white54)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _endBroadcast();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055)),
                    child: Text('End', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildChatFeed() {
    return SizedBox(
      height: 260,
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
                  radius: 14,
                  backgroundColor: _randomColor(msg['user']!),
                  child: Text(
                    msg['user']![0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Like count display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFF0055), size: 20),
                const SizedBox(width: 6),
                Text(
                  _formatCount(_likeCount),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // END BROADCAST button
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  title: Text('End Broadcast?', style: GoogleFonts.outfit(color: Colors.white)),
                  content: Text('Your live stream will end for all viewers.', style: GoogleFonts.outfit(color: Colors.white54)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _endBroadcast();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055)),
                      child: Text('End', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0055),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0055).withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                'End Broadcast',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // Viewers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatCount(_viewerCount),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white24}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
