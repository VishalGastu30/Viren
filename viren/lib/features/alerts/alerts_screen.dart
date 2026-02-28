import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Animation trigger delay
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
      body: ref.watch(activeAlertsProvider).when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.notifications_none_rounded, size: 64, color: DesignTokens.textMediumContrast),
                   const SizedBox(height: 16),
                   Text('Peace and quiet.', style: Theme.of(context).textTheme.titleMedium),
                   const SizedBox(height: 8),
                   Text('No active investment alerts at the moment.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }

          final sorted = List<Alert>.from(alerts)..sort((a, b) {
            const order = {
              db_enums.AlertSeverity.critical: 0,
              db_enums.AlertSeverity.warning: 1,
              db_enums.AlertSeverity.success: 2,
              db_enums.AlertSeverity.info: 3,
            };
            final aPrio = order[a.severity] ?? 3;
            final bPrio = order[b.severity] ?? 3;
            return aPrio.compareTo(bPrio);
          });

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 16, bottom: 100, left: 24, right: 24),
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final alert = sorted[index];
              return _AnimatedInsightCard(
                alert: alert,
                index: index,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading alerts: $err')),
      ),
    );
  }
}

class _AnimatedInsightCard extends StatelessWidget {
  final Alert alert; // Alert from Drift
  final int index;

  const _AnimatedInsightCard({required this.alert, required this.index});

  @override
  Widget build(BuildContext context) {
    // Determine curve based on severity
    Curve animationCurve;
    switch (alert.severity) {
      case db_enums.AlertSeverity.critical:
        animationCurve = Curves.elasticOut; // Pulse/bounce for critical
        break;
      case db_enums.AlertSeverity.warning:
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
              scale: alert.severity == db_enums.AlertSeverity.critical ? 0.95 + (0.05 * value) : 1.0,
              child: child,
            ),
          ),
        );
      },
      child: _InsightCard(alert: alert),
    );
  }
}


class _InsightCard extends ConsumerStatefulWidget {
  final Alert alert; // Alert from Drift

  const _InsightCard({required this.alert});

  @override
  ConsumerState<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<_InsightCard> {
  bool _isExpanded = false;

  Color _getSeverityColor() {
    switch (widget.alert.severity) {
      case db_enums.AlertSeverity.info:
        return DesignTokens.textMediumContrast;
      case db_enums.AlertSeverity.success:
        return DesignTokens.obsidianTeal;
      case db_enums.AlertSeverity.warning:
        return DesignTokens.ashGold;
      case db_enums.AlertSeverity.critical:
        return DesignTokens.crimsonWarning;
    }
  }

  IconData _getSeverityIcon() {
     switch (widget.alert.severity) {
      case db_enums.AlertSeverity.info:
        return Icons.info_outline_rounded;
      case db_enums.AlertSeverity.success:
        return Icons.check_circle_outline_rounded;
      case db_enums.AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case db_enums.AlertSeverity.critical:
        return Icons.error_outline_rounded;
    }
  }

  void _dismiss() {
    ref.read(alertRepositoryProvider).dismiss(widget.alert.id);
  }

  void _snooze() {
    // Snooze for 24 hours by default for now
    ref.read(alertRepositoryProvider).snooze(widget.alert.id, DateTime.now().add(const Duration(hours: 24)));
  }

  @override
  Widget build(BuildContext context) {
    // Reactive stream naturally removes dismissed items from the list,
    // so we don't need a local isDismissed check if we are watching the stream.
    // However, if we wanted manual override, we'd add it here.

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
                  '${widget.alert.createdAt.hour}:${widget.alert.createdAt.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  ),
                ),
                const Spacer(),
                if (widget.alert.relatedInstrument != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.alert.relatedInstrument!,
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
                    value: widget.alert.confidence / 100.0,
                    backgroundColor: DesignTokens.graphiteBase,
                    color: color,
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(widget.alert.confidence).round()}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
                        Text('Machine-derived evidence stored in Vault.', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
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

