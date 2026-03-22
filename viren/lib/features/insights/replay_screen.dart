import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/app_database.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/theme/design_tokens.dart';
import 'widgets/insight_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReplayScreen — Complete historical insight archive.
//
// Shows ALL alerts ever generated (including dismissed ones),
// grouped by month, newest first.
//
// This is a read-only screen — no swipe actions, no dismiss.
// Dismissed cards are shown with reduced opacity to indicate
// they were acted on or cleared.
//
// Entry point: Journal screen "View All History" button.
// ─────────────────────────────────────────────────────────────────────────────

// Provider: all alerts including dismissed, ordered newest first
final allAlertsHistoryProvider = StreamProvider<List<Alert>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.alerts)
        ..where((a) => a.alertType.isNotValue('MACRO_STATE') &
            a.alertType.isNotValue('OVERNIGHT_DATA') &
            a.alertType.isNotValue('USER_STOP_LOSS') &
            a.alertType.isNotValue('USER_PRICE_TARGET'))
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
      .watch();
});

class ReplayScreen extends ConsumerWidget {
  const ReplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(allAlertsHistoryProvider);

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        title: Text(
          'History',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: historyAsync.maybeWhen(
              data: (alerts) => Center(
                child: Text(
                  '${alerts.length} total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                      ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) return _buildEmptyState(context);
          return _buildHistory(context, alerts);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: DesignTokens.obsidianTeal),
        ),
        error: (_, __) => _buildEmptyState(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              size: 48,
              color: DesignTokens.textMediumContrast.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No history yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Insights will appear here as Viren detects them.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context, List<Alert> alerts) {
    // Group by "Month YYYY"
    final byMonth = <String, List<Alert>>{};
    for (final a in alerts) {
      final key = DateFormat('MMMM yyyy').format(a.createdAt);
      byMonth.putIfAbsent(key, () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Context banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: DesignTokens.ashGold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: DesignTokens.ashGold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 14, color: DesignTokens.ashGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Complete history — including dismissed insights.',
                  style: TextStyle(
                    color: DesignTokens.ashGold.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final entry in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
            child: Text(
              entry.key.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...entry.value.map((a) => _ReplayCard(alert: a)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Replay card — read-only, dimmed if dismissed ──────────────────

class _ReplayCard extends StatelessWidget {
  final Alert alert;
  const _ReplayCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isDismissed = alert.dismissedAt != null;

    return Opacity(
      opacity: isDismissed ? 0.45 : 1.0,
      child: InsightCard(
        alert: alert,
        isStarred: false,
        showAskViren: !isDismissed, // no Ask Viren on old dismissed cards
      ),
    );
  }
}
