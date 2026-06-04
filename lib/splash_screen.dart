// lib/splash_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CineSocial — Splash Screen with Custom Film Strip Logo
// No SVG file needed — pure Flutter CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _cyan = Color(0xFF00F0FF);
  static const Color _pink = Color(0xFFFF0055);
  static const Color _dark = Color(0xFF050510);

  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _taglineCtrl;
  late AnimationController _loadCtrl;
  late AnimationController _ringCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _loadProgress;
  late Animation<double> _ringRotate;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _generateParticles();
    _setupAnimations();
    _startSequence();
  }

  void _generateParticles() {
    for (int i = 0; i < 28; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 2.5 + 1,
          speed: _random.nextDouble() * 0.25 + 0.08,
          opacity: _random.nextDouble() * 0.5 + 0.2,
          isCyan: _random.nextBool(),
        ),
      );
    }
  }

  void _setupAnimations() {
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _ringRotate = Tween<double>(begin: 0, end: 2 * pi).animate(_ringCtrl);

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _loadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _loadProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _loadCtrl, curve: Curves.easeInOut));
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _textCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _taglineCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _loadCtrl.forward();

    // Reduced the final wait drastically
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _loadCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _dark,
      body: Stack(
        children: [
          // Grid background
          CustomPaint(size: size, painter: _GridPainter(_cyan)),

          // Floating particles
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, _) => CustomPaint(
              size: size,
              painter: _ParticlePainter(
                _particles,
                _particleCtrl.value,
                _cyan,
                _pink,
              ),
            ),
          ),

          // Radial glow
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _cyan.withValues(alpha: 0.09 * _pulse.value),
                      _pink.withValues(alpha: 0.05 * _pulse.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Spinning dashed rings
          AnimatedBuilder(
            animation: _ringCtrl,
            builder: (_, _) => Center(
              child: Transform.rotate(
                angle: _ringRotate.value,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _cyan.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ringCtrl,
            builder: (_, _) => Center(
              child: Transform.rotate(
                angle: -_ringRotate.value * 0.7,
                child: Container(
                  width: 178,
                  height: 178,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _pink.withValues(alpha: 0.09),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── LOGO ───────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, _) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, _) => Container(
                          width: 114,
                          height: 114,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _dark,
                            border: Border.all(
                              color: _cyan.withValues(alpha: _pulse.value),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _cyan.withValues(alpha: 0.45 * _pulse.value),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: _pink.withValues(alpha: 0.2 * _pulse.value),
                                blurRadius: 50,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Inner pink ring
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
color: _pink.withValues(
                                       alpha: 0.35 * _pulse.value,
                                     ),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Film strip + play logo
                              CustomPaint(
                                size: const Size(54, 54),
                                painter: _FilmStripLogoPainter(_cyan, _pink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ── CINESOCIAL TEXT ────────────────────────────────────────
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, _) => SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_cyan, _pink],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          'CINESOCIAL',
                          style: GoogleFonts.orbitron(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── TAGLINE ────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _taglineCtrl,
                  builder: (_, _) => SlideTransition(
                    position: _taglineSlide,
                    child: FadeTransition(
                      opacity: _taglineOpacity,
                      child: Text(
                        "Tollywood's Own Social Universe",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 1,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // ── LOADING BAR ────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _taglineCtrl,
                  builder: (_, _) => FadeTransition(
                    opacity: _taglineOpacity,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 180,
                          child: AnimatedBuilder(
                            animation: _loadCtrl,
                            builder: (_, _) => Column(
                              children: [
                                Stack(
                                  children: [
                                    // Track
                                    Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.07),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // Fill
                                    FractionallySizedBox(
                                      widthFactor: _loadProgress.value,
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [_cyan, _pink],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _cyan.withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${(_loadProgress.value * 100).toInt()}%',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    color: _cyan.withValues(alpha: 0.55),
                                    letterSpacing: 2,
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
              ],
            ),
          ),

          // Version badge
          AnimatedBuilder(
            animation: _taglineCtrl,
            builder: (_, _) => FadeTransition(
              opacity: _taglineOpacity,
              child: Positioned(
                bottom: 28,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'v1.0.0+1 • MARCH 2026',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.18),
                      letterSpacing: 2,
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

// ── Film Strip + Play Button Logo Painter ─────────────────────────────────────
class _FilmStripLogoPainter extends CustomPainter {
  final Color cyan;
  final Color pink;

  _FilmStripLogoPainter(this.cyan, this.pink);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Film strip holes (top row) ──────────────────────────────────────────
    final holePaint = Paint()
      ..color = cyan.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    const holeSize = 5.0;
    const holeRadius = 1.0;
    final holeY = 2.0;
    final holeSpacing = w / 5;

    for (int i = 0; i < 5; i++) {
      final hx = i * holeSpacing + (holeSpacing - holeSize) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(hx, holeY, holeSize, holeSize),
          const Radius.circular(holeRadius),
        ),
        holePaint,
      );
    }

    // ── Film strip holes (bottom row) ──────────────────────────────────────
    final holeYBottom = h - holeSize - 2;
    for (int i = 0; i < 5; i++) {
      final hx = i * holeSpacing + (holeSpacing - holeSize) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(hx, holeYBottom, holeSize, holeSize),
          const Radius.circular(holeRadius),
        ),
        holePaint,
      );
    }

    // ── Film strip body outline ─────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = cyan.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, holeSize + 2, w, h - (holeSize + 2) * 2),
        const Radius.circular(2),
      ),
      borderPaint,
    );

    // ── Play triangle (cyan → pink gradient) ───────────────────────────────
    final cx = w / 2;
    final cy = h / 2;
    const triangleW = 20.0;
    const triangleH = 18.0;

    final path = Path()
      ..moveTo(cx - triangleW / 2, cy - triangleH / 2)
      ..lineTo(cx + triangleW / 2, cy)
      ..lineTo(cx - triangleW / 2, cy + triangleH / 2)
      ..close();

    final gradientPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [cyan, pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromLTWH(
              cx - triangleW / 2,
              cy - triangleH / 2,
              triangleW,
              triangleH,
            ),
          )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, gradientPaint);
  }

  @override
  bool shouldRepaint(_FilmStripLogoPainter old) => false;
}

// ── Grid painter ──────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ── Particle model ────────────────────────────────────────────────────────────
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final bool isCyan;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.isCyan,
  });
}

// ── Particle painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color cyan;
  final Color pink;

  _ParticlePainter(this.particles, this.progress, this.cyan, this.pink);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = (p.isCyan ? cyan : pink).withValues(
          alpha: p.opacity * (0.5 + 0.5 * progress),
        )
        ..style = PaintingStyle.fill;

      final dy = (p.y - progress * p.speed) % 1.0;
      canvas.drawCircle(
        Offset(p.x * size.width, dy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

