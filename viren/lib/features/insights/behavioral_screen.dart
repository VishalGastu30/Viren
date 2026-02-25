import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../mock_data/behavioral_mock.dart';

class BehavioralScreen extends StatelessWidget {
  const BehavioralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('Behavioural Patterns', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patterns Viren Noticed',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Observed from your trade history. No judgment. No prescription. Just patterns.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.textMediumContrast, height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _ConfidenceMeterStrip(metric: BehavioralMock.metric),
                  const SizedBox(height: 32),
                  Text('Detected Patterns', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final pattern = BehavioralMock.patterns[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: AnimationPresets.durationSlow + AnimationPresets.staggerItem(index),
                  curve: AnimationPresets.entrance,
                  builder: (context, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: _BehaviorPatternCard(pattern: pattern),
                  ),
                );
              },
              childCount: BehavioralMock.patterns.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Confidence Meter Strip ───────────────────────────────────────────────────

class _ConfidenceMeterStrip extends StatelessWidget {
  final ConfidenceMetric metric;
  const _ConfidenceMeterStrip({required this.metric});

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
          Text('Investor Profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('A slow-moving measure. Updated monthly.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
          const SizedBox(height: 20),
          _MeterRow(label: 'Strategy Consistency', value: metric.strategicConsistency, note: metric.strategicNote),
          const SizedBox(height: 16),
          _MeterRow(label: 'Time Discipline', value: metric.timeDiscipline, note: metric.timeNote),
          const SizedBox(height: 16),
          _MeterRow(label: 'Emotional Stability', value: metric.emotionalStability, note: metric.emotionalNote),
        ],
      ),
    );
  }
}

class _MeterRow extends StatelessWidget {
  final String label;
  final double value;
  final String note;

  const _MeterRow({required this.label, required this.value, required this.note});

  @override
  Widget build(BuildContext context) {
    final color = value > 0.75 ? DesignTokens.obsidianTeal : value > 0.5 ? DesignTokens.ashGold : DesignTokens.crimsonWarning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('${(value * 100).round()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
        ]),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: AnimationPresets.durationChartDraw,
          curve: AnimationPresets.entrance,
          builder: (ctx, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              backgroundColor: DesignTokens.graphiteBase,
              color: color,
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4)),
      ],
    );
  }
}

// ─── Behavior Pattern Card ────────────────────────────────────────────────────

class _BehaviorPatternCard extends StatefulWidget {
  final BehavioralPattern pattern;
  const _BehaviorPatternCard({required this.pattern});

  @override
  State<_BehaviorPatternCard> createState() => _BehaviorPatternCardState();
}

class _BehaviorPatternCardState extends State<_BehaviorPatternCard> {
  bool _isExpanded = false;

  IconData get _patternIcon {
    switch (widget.pattern.type) {
      case BehaviorPatternType.overtrading: return Icons.swap_horiz_rounded;
      case BehaviorPatternType.panicBuying: return Icons.trending_down_rounded;
      case BehaviorPatternType.longInactivity: return Icons.hourglass_empty_rounded;
      case BehaviorPatternType.convictionDrift: return Icons.gps_off_rounded;
      case BehaviorPatternType.excessiveProfit: return Icons.call_missed_outgoing_rounded;
    }
  }

  Color get _patternColor {
    if (widget.pattern.confidence > 0.8) return DesignTokens.ashGold;
    if (widget.pattern.confidence > 0.6) return DesignTokens.textMediumContrast;
    return DesignTokens.textMediumContrast;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _patternColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_patternIcon, color: _patternColor, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.pattern.title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(widget.pattern.dateRange, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, fontSize: 11)),
                    ],
                  )),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: AnimationPresets.durationFast,
                    curve: AnimationPresets.entrance,
                    child: const Icon(Icons.expand_more_rounded, color: DesignTokens.textMediumContrast, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Confidence bar
              Row(children: [
                Text('Confidence', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, fontSize: 11)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: widget.pattern.confidence,
                      backgroundColor: DesignTokens.graphiteBase,
                      color: _patternColor,
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(widget.pattern.confidence * 100).round()}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _patternColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0, width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(widget.pattern.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast, height: 1.6)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DesignTokens.graphiteBase,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Why it matters', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text(widget.pattern.why, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
                        ],
                      ),
                    ),
                    if (widget.pattern.relatedSymbols.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: widget.pattern.relatedSymbols.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: DesignTokens.obsidianTeal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(s, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.obsidianTeal, fontSize: 11)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
                crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: AnimationPresets.durationNormal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
