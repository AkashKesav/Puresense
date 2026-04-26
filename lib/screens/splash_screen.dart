import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _particleController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _taglineFade;
  late final List<_Particle> _particles;
  final _random = Random();
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Generate scattered particles
    _particles = List.generate(
        40,
        (_) => _Particle(
              x: _random.nextDouble(),
              y: _random.nextDouble(),
              size: _random.nextDouble() * 3 + 1,
              speed: _random.nextDouble() * 0.3 + 0.1,
              opacity: _random.nextDouble() * 0.6 + 0.1,
              delay: _random.nextDouble(),
            ));

    _fadeController.forward();

    // Navigate after 1.8s
    _navigationTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/connect');
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Radial gradient glow
          Center(
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB300).withAlpha(18),
                    const Color(0xFFFFB300).withAlpha(5),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),

          // Floating particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gold shimmer wordmark
                  Shimmer.fromColors(
                    baseColor: const Color(0xFFFFB300),
                    highlightColor: const Color(0xFFFFD700),
                    period: const Duration(milliseconds: 2000),
                    child: Text(
                      'PureSense',
                      style: GoogleFonts.inter(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tagline
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'Precision metal analysis',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withAlpha(130),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Subtle loading indicator
                  FadeTransition(
                    opacity: _taglineFade,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          const Color(0xFFFFB300).withAlpha(120),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Particle model ───
class _Particle {
  final double x, y, size, speed, opacity, delay;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.delay,
  });
}

// ─── Particle painter ───
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final adjustedProgress = (progress + p.delay) % 1.0;
      final y = (p.y + adjustedProgress * p.speed) % 1.0;
      final fadeMultiplier = sin(adjustedProgress * pi);

      final paint = Paint()
        ..color = const Color(0xFFFFB300).withAlpha(
          (p.opacity * fadeMultiplier * 255).toInt().clamp(0, 255),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
