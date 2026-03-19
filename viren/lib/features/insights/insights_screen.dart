import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/providers/database_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/insights/insight_engine.dart';
import 'widgets/insight_card.dart';
import 'journal_screen.dart';
import '../settings/alert_settings_screen.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() =>
      _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final engine = InsightEngine(db);
      await engine.run();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(activeAlertsProvider);

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        title: Text(
          'Insights',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded,
                color: DesignTokens.textMediumContrast),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const JournalScreen()),
            ),
            tooltip: 'Investment journal',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: DesignTokens.textMediumContrast),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AlertSettingsScreen(),
              ),
            ),
            tooltip: 'Intelligence settings',
          ),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.obsidianTeal,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: DesignTokens.textMediumContrast),
              onPressed: _refresh,
              tooltip: 'Scan for new insights',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: DesignTokens.obsidianTeal,
        backgroundColor: DesignTokens.graphiteSurface,
        onRefresh: _refresh,
        child: alertsAsync.when(
          data: (alerts) {
            // Filter out internal sentinel rows
            final visible = alerts
                .where((a) =>
                    a.alertType != 'MACRO_STATE' &&
                    a.alertType != 'PRICE_SNAPSHOT' &&
                    a.alertType != 'EMOTION_NOTE')
                .toList();
            if (visible.isEmpty) {
              return _buildEmptyState();
            }
            return _buildFeed(visible);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: DesignTokens.obsidianTeal,
            ),
          ),
          error: (_, __) => _buildEmptyState(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 48,
                color: DesignTokens.textMediumContrast
                    .withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No insights yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Pull down to scan for price alerts\nand news relevant to your holdings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignTokens.textMediumContrast,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                InsightEngine.isMarketHours()
                    ? '🟢 Market is open — live monitoring active'
                    : '⚪ Market is closed — background monitoring paused',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignTokens.textMediumContrast
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeed(List<Alert> alerts) {
    final now = DateTime.now();
    final todayAlerts = alerts
        .where((a) => now.difference(a.createdAt).inHours < 24)
        .toList();
    final weekAlerts = alerts
        .where((a) =>
            now.difference(a.createdAt).inHours >= 24 &&
            now.difference(a.createdAt).inDays < 7)
        .toList();
    final olderAlerts = alerts
        .where((a) => now.difference(a.createdAt).inDays >= 7)
        .toList();

    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (todayAlerts.isNotEmpty) ...[
          _sectionHeader('Today'),
          ...todayAlerts.map(_buildCard),
        ],
        if (weekAlerts.isNotEmpty) ...[
          _sectionHeader('This Week'),
          ...weekAlerts.map(_buildCard),
        ],
        if (olderAlerts.isNotEmpty) ...[
          _sectionHeader('Older'),
          ...olderAlerts.map(_buildCard),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DesignTokens.textMediumContrast,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildCard(Alert alert) {
    if (alert.alertType == 'MACRO_STATE' ||
        alert.alertType == 'PRICE_SNAPSHOT' ||
        alert.alertType == 'EMOTION_NOTE') {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.horizontal,
      // Swipe LEFT = dismiss (red X) — shown on the right side
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: DesignTokens.crimsonWarning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.close_rounded,
            color: DesignTokens.crimsonWarning),
      ),
      // Swipe RIGHT = star/journal (gold bookmark) — shown on the left side
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: DesignTokens.ashGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.bookmark_rounded,
            color: DesignTokens.ashGold),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right — star it, but do NOT remove from feed
          final db = ref.read(appDatabaseProvider);
          await (db.update(db.alerts)
                ..where((a) => a.id.equals(alert.id)))
              .write(AlertsCompanion(
            snoozedUntil: drift.Value(DateTime(9999, 1, 1)),
          ));
          return false; // card stays in the feed
        }
        // Swipe left — confirm dismiss
        return true;
      },
      onDismissed: (direction) async {
        final db = ref.read(appDatabaseProvider);
        await (db.update(db.alerts)
              ..where((a) => a.id.equals(alert.id)))
            .write(AlertsCompanion(
          dismissedAt: drift.Value(DateTime.now()),
        ));
      },
      child: InsightCard(alert: alert),
    );
  }
}
