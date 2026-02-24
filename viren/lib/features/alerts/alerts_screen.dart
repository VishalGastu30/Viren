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


class _InsightCard extends StatelessWidget {
  final Alert alert;

  const _InsightCard({required this.alert});

  Color _getSeverityColor() {
    switch (alert.severity) {
      case AlertSeverity.info:
        return DesignTokens.textMediumContrast;
      case AlertSeverity.success:
        return DesignTokens.obsidianTeal;
      case AlertSeverity.warning:
        return DesignTokens.ashGold; // Ash Gold
      case AlertSeverity.critical:
        return DesignTokens.crimsonWarning; // Crimson
    }
  }

  IconData _getSeverityIcon() {
     switch (alert.severity) {
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

  @override
  Widget build(BuildContext context) {
    final color = _getSeverityColor();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
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
                alert.time,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alert.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
