import 'package:flutter/material.dart';

import '../../mock_data/alerts_mock.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late List<Alert> _sortedAlerts;

  @override
  void initState() {
    super.initState();
    // Sort logic: Critical -> Warning -> Success -> Info
    _sortedAlerts = List.from(AlertsMock.insights)..sort((a, b) {
      const order = {
        AlertSeverity.critical: 0,
        AlertSeverity.warning: 1,
        AlertSeverity.success: 2,
        AlertSeverity.info: 3,
      };
      return order[a.severity]!.compareTo(order[b.severity]!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text(
          'Alerts',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 100, left: 24, right: 24),
        itemCount: _sortedAlerts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final alert = _sortedAlerts[index];
          return _AnimatedInsightCard(
            alert: alert,
            index: index,
          );
        },
      ),
    );
  }
}

class _AnimatedInsightCard extends StatelessWidget {
  final Alert alert;
  final int index;

  const _AnimatedInsightCard({required this.alert, required this.index});

  @override
  Widget build(BuildContext context) {
    // Determine curve based on severity
    Curve animationCurve;
    switch (alert.severity) {
      case AlertSeverity.critical:
        animationCurve = Curves.elasticOut; // Pulse/bounce for critical
        break;
      case AlertSeverity.warning:
        animationCurve = Curves.easeOutBack;
        break;
      default:
        animationCurve = AnimationPresets.entrance; // Standard fade for info/success
        break;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 100)), // Stagger
      curve: animationCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Transform.scale(
              scale: alert.severity == AlertSeverity.critical ? 0.95 + (0.05 * value) : 1.0,
              child: child,
            ),
          ),
        );
      },
      child: _InsightCard(alert: alert),
    );
  }
}


class _InsightCard extends StatefulWidget {
  final Alert alert;

  const _InsightCard({required this.alert});

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _isExpanded = false;

  Color _getSeverityColor() {
    switch (widget.alert.severity) {
      case AlertSeverity.info:
        return DesignTokens.textMediumContrast;
      case AlertSeverity.success:
        return DesignTokens.obsidianTeal;
      case AlertSeverity.warning:
        return DesignTokens.ashGold;
      case AlertSeverity.critical:
        return DesignTokens.crimsonWarning;
    }
  }

  IconData _getSeverityIcon() {
     switch (widget.alert.severity) {
      case AlertSeverity.info:
        return Icons.info_outline_rounded;
      case AlertSeverity.success:
        return Icons.check_circle_outline_rounded;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.critical:
        return Icons.error_outline_rounded;
    }
  }

  void _dismiss() {
    setState(() { widget.alert.isDismissed = true; });
  }

  void _snooze() {
    setState(() { widget.alert.isSnoozed = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alert.isDismissed || widget.alert.isSnoozed) {
      return const SizedBox.shrink(); 
    }

    final color = _getSeverityColor();
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withValues(alpha: _isExpanded ? 0.3 : 0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getSeverityIcon(),
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.alert.time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  ),
                ),
                const Spacer(),
                if (widget.alert.relatedSymbol != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.alert.relatedSymbol!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.obsidianTeal, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.alert.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.alert.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Text('Confidence', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, fontSize: 11)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: widget.alert.confidence,
                    backgroundColor: DesignTokens.graphiteBase,
                    color: color,
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(widget.alert.confidence * 100).round()}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
            
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0, width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DesignTokens.graphiteBase,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Historical Context', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Text(widget.alert.historicalContext, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _snooze,
                        icon: const Icon(Icons.snooze_rounded, size: 16),
                        label: const Text('Snooze'),
                        style: TextButton.styleFrom(
                          foregroundColor: DesignTokens.textMediumContrast,
                          textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _dismiss,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Dismiss'),
                        style: TextButton.styleFrom(
                          foregroundColor: DesignTokens.textMediumContrast,
                          textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: AnimationPresets.durationNormal,
            ),
          ],
        ),
      ),
    );
  }
}

