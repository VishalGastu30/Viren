import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class CandlestickData {
  final double open;
  final double high;
  final double low;
  final double close;
  final DateTime date;

  const CandlestickData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.date,
  });
}

class CandlestickChart extends StatefulWidget {
  final List<CandlestickData> data;

  const CandlestickChart({
    super.key,
    required this.data,
  });

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this, 
       duration: AnimationPresets.durationChartDraw == Duration.zero ? const Duration(milliseconds: 1) : AnimationPresets.durationChartDraw,
    );
    _animation = CurvedAnimation(parent: _controller, curve: AnimationPresets.entrance);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CandlestickChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _controller.forward(from: 0);
    }
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
          size: const Size(double.infinity, 240),
          painter: _CandlestickPainter(
            data: widget.data,
            progress: _animation.value,
          ),
        );
      },
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<CandlestickData> data;
  final double progress;

  _CandlestickPainter({
    required this.data,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minPrice = data.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    final maxPrice = data.map((e) => e.high).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    final candleWidth = (size.width / data.length) * 0.6;
    final spacing = (size.width / data.length) * 0.4;

    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      final isBullish = candle.close >= candle.open;

      final color = isBullish ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;
      
      final paint = Paint()
        ..color = color.withValues(alpha: progress)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = color.withValues(alpha: progress)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final x = (i * (candleWidth + spacing)) + (spacing / 2);

      // Y coordinates (inverted because Flutter canvas Y goes down)
      final highY = size.height - (((candle.high - minPrice) / priceRange) * size.height);
      final lowY = size.height - (((candle.low - minPrice) / priceRange) * size.height);
      final openY = size.height - (((candle.open - minPrice) / priceRange) * size.height);
      final closeY = size.height - (((candle.close - minPrice) / priceRange) * size.height);

      // Apply vertical stagger animation progress based on the index position relative to progress
      final itemProgressThreshold = i / data.length;
      if (progress < itemProgressThreshold) continue; // Don't draw if not reached in stagger

      // Draw wick
      canvas.drawLine(
        Offset(x + candleWidth / 2, highY),
        Offset(x + candleWidth / 2, lowY),
        strokePaint,
      );

      // Draw body
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          x,
          isBullish ? closeY : openY,
          x + candleWidth,
          isBullish ? openY : closeY,
        ),
        const Radius.circular(2),
      );

      // Protect against 0 height rects (doji)
      if (rect.height < 1.0) {
        canvas.drawLine(
           Offset(x, openY), 
           Offset(x + candleWidth, openY), 
           strokePaint..strokeWidth = 1.0
        );
      } else {
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data;
  }
}
