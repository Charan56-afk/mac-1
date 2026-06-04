import 'package:flutter/material.dart';

class ShimmerLoader extends StatefulWidget {
  final Widget child;

  const ShimmerLoader({super.key, required this.child});

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFF12121A), // Dark card background
      end: const Color(0xFF1E1E2E), // Lighter shimmer
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                _colorAnimation.value ?? const Color(0xFF12121A),
                _colorAnimation.value?.withValues(alpha: 0.8) ??
                    const Color(0xFF1E1E2E),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// ── PRE-BUILT SKELETONS ─────────────────────────────────────────

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // Color doesn't matter, mask will cover it
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double radius;

  const ShimmerCircle({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

// 1. MovieCardSkeleton (Horizontal card with poster + text)
class MovieCardSkeleton extends StatelessWidget {
  const MovieCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 80, height: 120, borderRadius: 12),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const ShimmerBox(width: 150, height: 18),
                  const SizedBox(height: 12),
                  const ShimmerBox(width: 100, height: 14),
                  const SizedBox(height: 12),
                  const ShimmerBox(width: double.infinity, height: 12),
                  const SizedBox(height: 6),
                  const ShimmerBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. BuzzTileSkeleton (Vertical card 200px wide)
class BuzzTileSkeleton extends StatelessWidget {
  const BuzzTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 200, height: 110, borderRadius: 16),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160, height: 16),
                  SizedBox(height: 8),
                  ShimmerBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. FeedCardSkeleton (Social post with avatar + image + text)
class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const ShimmerCircle(radius: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 120, height: 14),
                      const SizedBox(height: 6),
                      const ShimmerBox(width: 80, height: 10),
                    ],
                  ),
                ],
              ),
            ),
            const ShimmerBox(
              width: double.infinity,
              height: 250,
              borderRadius: 0,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(width: double.infinity, height: 12),
                  const SizedBox(height: 6),
                  const ShimmerBox(width: 200, height: 12),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const ShimmerCircle(radius: 12),
                      const SizedBox(width: 16),
                      const ShimmerCircle(radius: 12),
                      const SizedBox(width: 16),
                      const ShimmerCircle(radius: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. HeroCarouselSkeleton (Large hero banner)
class HeroCarouselSkeleton extends StatelessWidget {
  final double height;

  const HeroCarouselSkeleton({super.key, this.height = 400});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Container(
        height: height,
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(width: 200, height: 32),
              const SizedBox(height: 12),
              const ShimmerBox(width: 250, height: 14),
              const SizedBox(height: 8),
              const ShimmerBox(width: 150, height: 14),
              const SizedBox(height: 24),
              Row(
                children: [
                  const ShimmerBox(width: 120, height: 45, borderRadius: 22),
                  const SizedBox(width: 16),
                  const ShimmerBox(width: 45, height: 45, borderRadius: 22),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

