import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../core/theme/design_tokens.dart';
import '../core/animations/animation_presets.dart';
class ConfidenceMetric {
  final double strategicConsistency;
  final double timeDiscipline;
  final double emotionalStability;
  final String strategicNote;
  final String timeNote;
  final String emotionalNote;

  const ConfidenceMetric({
    required this.strategicConsistency,
    required this.timeDiscipline,
    required this.emotionalStability,
    required this.strategicNote,
    required this.timeNote,
    required this.emotionalNote,
  });
}

/// Three slow-moving arc meters representing the investor confidence profile.
class ConfidenceMeterWidget extends StatelessWidget {
  final ConfidenceMetric metric;

  const ConfidenceMeterWidget({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Behaviour Score', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('Monthly', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text('A slow-moving measure of your trading psychology.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ArcMeter(label: 'Strategy', value: metric.strategicConsistency, color: DesignTokens.obsidianTeal),
              _ArcMeter(label: 'Discipline', value: metric.timeDiscipline, color: DesignTokens.ashGold),
              _ArcMeter(label: 'Stability', value: metric.emotionalStability, color: DesignTokens.obsidianTeal),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcMeter extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ArcMeter({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AnimationPresets.durationChartDraw,
      curve: AnimationPresets.entrance,
      builder: (ctx, v, _) => Column(
        children: [
          SizedBox(
            width: 84,
            height: 56,
            child: CustomPaint(
              painter: _ArcPainter(value: v, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(v * 100).round()}',
            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double value;
  final Color color;

  _ArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.88;
    final radius = size.width * 0.44;
    const startAngle = math.pi;
    const sweepMax = math.pi;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepMax, false,
      Paint()
        ..color = DesignTokens.graphiteBase
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle, sweepMax * value, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}
