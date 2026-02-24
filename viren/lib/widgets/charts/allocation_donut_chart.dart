import 'dart:math';
import 'package:flutter/material.dart';
import '../../mock_data/holdings_mock.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class AllocationDonutChart extends StatefulWidget {
  const AllocationDonutChart({super.key});

  @override
  State<AllocationDonutChart> createState() => _AllocationDonutChartState();
}

class _AllocationDonutChartState extends State<AllocationDonutChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AnimationPresets.durationChartDraw == Duration.zero ? const Duration(milliseconds: 1) : AnimationPresets.durationChartDraw,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AnimationPresets.entrance,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size.square(200),
          painter: _DonutPainter(
            holdings: HoldingsMock.holdings,
            progress: _animation.value,
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<Holding> holdings;
  final double progress;

  _DonutPainter({required this.holdings, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;
    
    // Background track
    final trackPaint = Paint()
      ..color = DesignTokens.graphiteSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, trackPaint);

    double currentAngle = -pi / 2; // Start from top
    
    // Colors matching theme but slightly distinct for visual separation
    final colors = [
      DesignTokens.obsidianTeal,
      DesignTokens.ashGold,
      const Color(0xFF0F766E), // Darker teal
      const Color(0xFF8B7A44), // Darker gold
      const Color(0xFF1F484C), // Deep moss
      DesignTokens.textMediumContrast,
    ];

    for (int i = 0; i < holdings.length; i++) {
      final sweepAngle = (holdings[i].percentOfPortfolio / 100) * 2 * pi * progress;
      
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round; // Soft edges

      // Draw a tiny gap between segments
      final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
      canvas.drawArc(rect, currentAngle, sweepAngle - 0.05, false, paint);

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
