import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _parallaxAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Extended for slow reveal
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: AnimationPresets.entrance),
      ),
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: AnimationPresets.entrance),
      ),
    );

    _parallaxAnimation = Tween<double>(begin: -30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().then((_) {
      // Navigate to onboarding
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
           Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: AnimationPresets.durationSlow,
              )
           );
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      body: Stack(
        children: [
          // Nebula Parallax Background Mock
          AnimatedBuilder(
            animation: _parallaxAnimation,
            builder: (context, child) {
              return Positioned(
                top: _parallaxAnimation.value,
                left: _parallaxAnimation.value * 1.5,
                right: -50,
                bottom: -50,
                child: Opacity(
                  opacity: 0.15,
                  child: CustomPaint(
                    painter: _NebulaPainter(),
                  ),
                ),
              );
            },
          ),
          // Logo Reveal
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VIREN',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: DesignTokens.textHighContrast,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 40,
                    height: 1,
                    color: DesignTokens.obsidianTeal,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NebulaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignTokens.obsidianTeal.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Draw some abstract soft blobs to represent a "nebula"
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 150, paint);
    
    paint.color = DesignTokens.ashGold.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), 200, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
