import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class MonthlySparkline extends StatefulWidget {
  final List<double> dataPoints;
  
  const MonthlySparkline({
    super.key,
    required this.dataPoints,
  });

  @override
  State<MonthlySparkline> createState() => _MonthlySparklineState();
}

class _MonthlySparklineState extends State<MonthlySparkline> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: AnimationPresets.durationChartDraw == Duration.zero ? const Duration(milliseconds: 1) : AnimationPresets.durationChartDraw);
    _animation = CurvedAnimation(parent: _controller, curve: AnimationPresets.entrance);
    
    // Slight delay so PageView entrance animation finishes first
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
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
          size: const Size.fromHeight(80), // Fixed height, flexible width
          painter: _SparklinePainter(
            dataPoints: widget.dataPoints,
            progress: _animation.value,
          ),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> dataPoints;
  final double progress;

  _SparklinePainter({required this.dataPoints, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    final double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final double widthStep = size.width / (dataPoints.length - 1);
    
    final Path path = Path();
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * widthStep;
      // Invert Y because canvas Y grows downwards
      final y = size.height - ((dataPoints[i] - minVal) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Path metrics to animate the drawing
    final ui.PathMetrics pathMetrics = path.computeMetrics();
    final Path extractedPath = Path();

    for (ui.PathMetric metric in pathMetrics) {
      final double extractLength = metric.length * progress;
      extractedPath.addPath(
        metric.extractPath(0.0, extractLength),
        Offset.zero,
      );
    }

    final paint = Paint()
      ..color = DesignTokens.ashGold // Ash Gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extractedPath, paint);

    // Optional gradient fill below line for premium feel
    if (progress == 1.0) {
        final fillPath = Path.from(path);
        fillPath.lineTo(size.width, size.height);
        fillPath.lineTo(0, size.height);
        fillPath.close();

        final fillPaint = Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            Offset(0, size.height),
            [
              DesignTokens.ashGold.withValues(alpha: 0.2),
              DesignTokens.ashGold.withValues(alpha: 0.0),
            ],
          );
        canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
