import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';

/// Full-screen overlay shown when there is NO internet connection.
/// Automatically dismisses with a "Back Online" toast when connection returns.
/// Behaviour mirrors Instagram's no-internet screen.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  bool _wasOffline = false;
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the wifi-off icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen for connectivity changes
    ConnectivityService.instance.isOnline.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    final online = ConnectivityService.instance.isOnline.value;

    if (!online) {
      // Going offline
      _wasOffline = true;
      _showBackOnline = false;
      _backOnlineTimer?.cancel();
      if (mounted) setState(() {});
    } else if (_wasOffline && online) {
      // Coming back online — show toast then dismiss
      _wasOffline = false;
      _showBackOnline = true;
      if (mounted) setState(() {});

      _backOnlineTimer?.cancel();
      _backOnlineTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showBackOnline = false);
      });
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.isOnline.removeListener(_onConnectivityChanged);
    _pulseController.dispose();
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, isOnline, child) {
        return Stack(
          children: [
            // The actual app underneath
            widget.child,

            // Full-screen no-internet overlay
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: isOnline
                  ? const SizedBox.shrink(key: ValueKey('online'))
                  : _NoInternetOverlay(
                      key: const ValueKey('offline'),
                      pulseAnim: _pulseAnim,
                    ),
            ),

            // "Back Online" toast at the top
            if (_showBackOnline)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                child: _BackOnlineToast(),
              ),
          ],
        );
      },
    );
  }
}

// ── No Internet Overlay ────────────────────────────────────────────────────────

class _NoInternetOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _NoInternetOverlay({super.key, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A0A0F),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing icon
                ScaleTransition(
                  scale: pulseAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF12121A),
                      border: Border.all(
                        color: const Color(0xFFFF3333).withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3333).withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 52,
                      color: Color(0xFFFF3333),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Title
                Text(
                  'No Internet Connection',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 14),

                // Subtitle
                Text(
                  'Check your Wi-Fi or mobile data\nand try again.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: const Color(0xFF888899),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),

                // Animated dots — "waiting to reconnect..."
                const _WaitingDots(),
                const SizedBox(height: 12),
                Text(
                  'Waiting for connection...',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF555566),
                  ),
                ),

                const SizedBox(height: 48),

                // Manual retry button
                GestureDetector(
                  onTap: () => ConnectivityService.instance.recheck(),
                  child: Container(
                    height: 52,
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: const Color(0xFFFF3333).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      color: const Color(0xFFFF3333).withValues(alpha: 0.08),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFFFF3333),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Try Again',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF3333),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated "..." waiting indicator ─────────────────────────────────────────

class _WaitingDots extends StatefulWidget {
  const _WaitingDots();

  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots> {
  int _dotCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i < _dotCount ? 10 : 6,
          height: i < _dotCount ? 10 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _dotCount
                ? const Color(0xFFFF3333)
                : const Color(0xFF333344),
          ),
        );
      }),
    );
  }
}

// ── "Back Online" toast ───────────────────────────────────────────────────────

class _BackOnlineToast extends StatefulWidget {
  const _BackOnlineToast();

  @override
  State<_BackOnlineToast> createState() => _BackOnlineToastState();
}

class _BackOnlineToastState extends State<_BackOnlineToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF00C853),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C853).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Back Online! 🎉',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

