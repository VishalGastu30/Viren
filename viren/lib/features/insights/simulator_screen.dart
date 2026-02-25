import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../mock_data/portfolio_mock.dart';

class SimulatorScreen extends StatelessWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulated no-action portfolio path (passive index-like return)
    final noActionValues = List.generate(7, (i) => 1250000.0 * (1 + i * 0.022));
    final actualValues = PortfolioMock.monthlySparks;

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('If You Did Nothing', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A neutral comparison.', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'This simulator compares your actual moves against a hypothetical where no trades were placed after your initial investment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast, height: 1.6),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DesignTokens.borderSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Viren does not tell you what was better. It shows what happened.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast),
              ),
            ),
            const SizedBox(height: 36),

            // Chart
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AnimationPresets.durationChartDraw,
              curve: AnimationPresets.entrance,
              builder: (context, progress, _) => SizedBox(
                height: 260,
                child: CustomPaint(
                  painter: _SimulatorChartPainter(
                    actualValues: actualValues,
                    noActionValues: noActionValues,
                    progress: progress,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Legend
            Row(children: [
              _LegendDot(color: DesignTokens.obsidianTeal, label: 'Actual Portfolio'),
              const SizedBox(width: 24),
              _LegendDot(color: DesignTokens.textMediumContrast, label: 'No-Action Baseline'),
            ]),

            const SizedBox(height: 36),

            // Callouts
            _SimulatorCallout(
              icon: Icons.show_chart_rounded,
              color: DesignTokens.obsidianTeal,
              title: 'Actual Return',
              value: '+14.04%',
              description: 'Your portfolio over 7 months, including all trades and rebalancing.',
            ),
            const SizedBox(height: 16),
            _SimulatorCallout(
              icon: Icons.timeline_rounded,
              color: DesignTokens.textMediumContrast,
              title: 'No-Action Return',
              value: '+15.4%',
              description: 'If you had held your initial allocation with no changes across the same period.',
            ),
            const SizedBox(height: 16),
            _SimulatorCallout(
              icon: Icons.compare_arrows_rounded,
              color: DesignTokens.ashGold,
              title: 'Difference',
              value: '-1.36%',
              description: 'Your active decisions resulted in 1.36% less return than doing nothing. This is within normal variation for active management.',
            ),

            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesignTokens.graphiteSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: DesignTokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What this does not tell you', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _NeutralPoint('Risk taken on the no-action path vs. your actual rebalancing.'),
                  _NeutralPoint('Whether your decisions built conviction or clarity, regardless of return.'),
                  _NeutralPoint('Future periods. This is backwards-looking only.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
    ]);
  }
}

class _SimulatorCallout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String description;

  const _SimulatorCallout({required this.icon, required this.color, required this.title, required this.value, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
              ]),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4)),
            ],
          )),
        ],
      ),
    );
  }
}

class _NeutralPoint extends StatelessWidget {
  final String text;
  const _NeutralPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.remove_rounded, size: 14, color: DesignTokens.textMediumContrast),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4))),
        ],
      ),
    );
  }
}

// ─── Simulator Chart Painter ──────────────────────────────────────────────────

class _SimulatorChartPainter extends CustomPainter {
  final List<double> actualValues;
  final List<double> noActionValues;
  final double progress;

  _SimulatorChartPainter({
    required this.actualValues,
    required this.noActionValues,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final allValues = [...actualValues, ...noActionValues];
    final minVal = allValues.reduce(math.min);
    final maxVal = allValues.reduce(math.max);
    final range = maxVal - minVal;
    if (range == 0) return;

    final n = actualValues.length;
    final stepX = size.width / (n - 1);

    double xOf(int i) => i * stepX;
    double yOf(double v) => size.height - ((v - minVal) / range * size.height * 0.85) - size.height * 0.05;

    // Draw actual line
    _drawLine(canvas, size, actualValues, progress, xOf, yOf, DesignTokens.obsidianTeal, strokeWidth: 2.0);

    // Draw no-action dashed line
    _drawDashedLine(canvas, noActionValues, progress, xOf, yOf, DesignTokens.textMediumContrast);
  }

  void _drawLine(Canvas canvas, Size size, List<double> values, double progress, double Function(int) xOf, double Function(double) yOf, Color color, {required double strokeWidth}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final n = values.length;
    final totalPoints = (n - 1) * 100;
    final drawnPoints = (totalPoints * progress).round();

    final path = Path();
    bool started = false;

    for (int segment = 0; segment < n - 1; segment++) {
      for (int j = 0; j <= 100; j++) {
        final globalPoint = segment * 100 + j;
        if (globalPoint > drawnPoints) break;
        final t = j / 100.0;
        final x = xOf(segment) + t * (xOf(segment + 1) - xOf(segment));
        final y = yOf(values[segment] + t * (values[segment + 1] - values[segment]));
        if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
      }
    }
    canvas.drawPath(path, paint);

    // Draw fill
    if (started && progress > 0) {
      final fillPath = Path()..addPath(path, Offset.zero);
      final endX = xOf(0) + (xOf(n - 1) - xOf(0)) * progress;
      fillPath.lineTo(endX, size.height);
      fillPath.lineTo(xOf(0), size.height);
      fillPath.close();
      canvas.drawPath(fillPath, Paint()
        ..shader = LinearGradient(
            colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill);
    }
  }

  void _drawDashedLine(Canvas canvas, List<double> values, double progress, double Function(int) xOf, double Function(double) yOf, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashLen = 8.0;
    const gapLen = 5.0;
    double dashRemain = dashLen;
    bool drawing = true;

    final n = values.length;
    for (int i = 0; i < n - 1; i++) {
      final pct = (i + 1) / (n - 1);
      if (pct > progress) break;
      double x1 = xOf(i), y1 = yOf(values[i]);
      double x2 = xOf(i + 1), y2 = yOf(values[i + 1]);
      double segLen = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
      double cx = x1, cy = y1;
      double consumed = 0;
      while (consumed < segLen) {
        final step = math.min(dashRemain, segLen - consumed);
        final t = step / segLen;
        final nx = cx + t * (x2 - x1);
        final ny = cy + t * (y2 - y1);
        if (drawing) { canvas.drawLine(Offset(cx, cy), Offset(nx, ny), paint); }
        cx = nx; cy = ny; consumed += step;
        dashRemain -= step;
        if (dashRemain <= 0) {
          drawing = !drawing;
          dashRemain = drawing ? dashLen : gapLen;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SimulatorChartPainter old) =>
      old.progress != progress || old.actualValues != actualValues;
}
