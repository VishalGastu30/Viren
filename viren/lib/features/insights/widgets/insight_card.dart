import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/database_providers.dart';
import '../../../core/database/providers/journal_providers.dart';
import '../../../core/insights/ask_viren_launcher.dart';
import '../../../core/market/live_price_cache.dart';
import '../../../core/navigation/deep_link_service.dart';
import '../../../core/theme/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InsightCard — Individual feed card in the Insights tab.
// Phase 3: ConsumerWidget, star toggle, Ask Viren button.
// ─────────────────────────────────────────────────────────────────────────────

class InsightCard extends ConsumerWidget {
  final Alert alert;
  final bool isStarred;
  final bool showAskViren;
  final bool isExpanded;

  const InsightCard({
    required this.alert,
    this.isStarred = false,
    this.showAskViren = true,
    this.isExpanded = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = _typeColor(alert.alertType);
    final typeLabel = _typeLabel(alert.alertType);
    final timeAgo = _timeAgo(alert.createdAt);
    final starred = ref.watch(isAlertStarredProvider(alert.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (alert.relatedInstrument != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alert.relatedInstrument!,
                    style: TextStyle(
                      color: DesignTokens.textMediumContrast,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text(
                timeAgo,
                style: TextStyle(
                  color: DesignTokens.textMediumContrast
                      .withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.textHighContrast,
                ),
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                        height: 1.5,
                      ),
                  maxLines: isExpanded ? null : 3,
                  overflow: isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
                ),
                if (!isExpanded && alert.description.length > 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tap to expand',
                      style: TextStyle(
                        fontSize: 10,
                        color: typeColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tap to collapse',
                      style: TextStyle(
                        fontSize: 10,
                        color: typeColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Confidence bar
          const SizedBox(height: 12),
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(1),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (alert.confidence / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          // ── Action row ────────────────────────────────────
          const SizedBox(height: 12),
          Row(
            children: [
              if (showAskViren)
                _ActionChip(
                  label: 'Ask Viren',
                  icon: Icons.bolt_rounded,
                  color: DesignTokens.obsidianTeal,
                  onTap: () => _onAskViren(context, ref),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => _toggleStar(ref),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    starred
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    size: 18,
                    color: starred
                        ? DesignTokens.ashGold
                        : DesignTokens.textMediumContrast
                            .withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStar(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final isCurrentlyStarred = ref.read(isAlertStarredProvider(alert.id));

    await (db.update(db.alerts)
          ..where((a) => a.id.equals(alert.id)))
        .write(AlertsCompanion(
      snoozedUntil: drift.Value(
        isCurrentlyStarred ? null : DateTime(9999, 1, 1),
      ),
    ));
  }

  Future<void> _onAskViren(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final holdings = await db.select(db.holdings).get();

    final prompt = AskVirenLauncher.buildPrompt(
      alert: alert,
      holdings: holdings,
      currentPrices: Map.fromEntries(
        ref.read(livePriceCacheProvider).quotes.entries.map(
          (e) => MapEntry(e.key, e.value.currentPrice),
        ),
      ),
    );

    // Write to deepLinkProvider.
    // VirenRouter listens to this and calls _navigateToAssistant(prompt).
    ref.read(deepLinkProvider.notifier).navigate(
          DeepLinkTarget(tab: kTabAssistant, payload: prompt),
        );
  }

  Color _typeColor(String alertType) {
    switch (alertType) {
      case 'CIRCUIT_BREAKER':
      case 'STOP_LOSS_HIT':
      case 'DRAWDOWN_ALERT':
        return DesignTokens.crimsonWarning;
      case 'NEWS_RELEVANT':
      case 'MACRO_EVENT':
        return const Color(0xFF6C7FE8);
      case 'RECOVERY_ALERT':
      case 'DCA_OPPORTUNITY':
      case 'DCA_SIGNAL':
        return DesignTokens.obsidianTeal;
      case 'PORTFOLIO_MILESTONE':
      case 'WEEKLY_DIGEST':
      case 'CONSISTENCY_STREAK':
      case 'MORNING_BRIEFING':
        return DesignTokens.ashGold;
      case 'CONCENTRATION_DRIFT':
      case 'MOMENTUM_ALERT':
        return const Color(0xFFE8A23A);
      case 'BEHAVIOUR_WARNING':
        return const Color(0xFFB06FE8);
      case 'ACCUMULATION_PATTERN':
        return DesignTokens.obsidianTeal;
      default:
        return DesignTokens.textMediumContrast;
    }
  }

  String _typeLabel(String alertType) {
    switch (alertType) {
      case 'CIRCUIT_BREAKER':      return 'CIRCUIT BREAKER';
      case 'STOP_LOSS_HIT':        return 'STOP LOSS';
      case 'PRICE_TARGET_HIT':     return 'TARGET HIT';
      case 'NEWS_RELEVANT':        return 'NEWS';
      case 'MACRO_EVENT':          return 'MACRO';
      case 'DRAWDOWN_ALERT':       return 'DRAWDOWN';
      case 'RECOVERY_ALERT':       return 'RECOVERY';
      case 'DCA_OPPORTUNITY':      return 'DCA SIGNAL';
      case 'PORTFOLIO_MILESTONE':  return 'MILESTONE';
      case 'WEEKLY_DIGEST':        return 'WEEKLY';
      case 'MORNING_BRIEFING':     return 'MORNING';
      case 'BEHAVIOUR_WARNING':    return 'BEHAVIOUR';
      case 'INACTIVITY_ALERT':     return 'REMINDER';
      case 'CONCENTRATION_DRIFT':  return 'RISK SIGNAL';
      case 'MOMENTUM_ALERT':       return 'MOMENTUM';
      case 'ACCUMULATION_PATTERN': return 'PATTERN';
      case 'CONSISTENCY_STREAK':   return 'STREAK';
      case 'MACRO_STATE':          return '';
      default: return alertType.replaceAll('_', ' ');
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }
}

// ── Action Chip ──────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
