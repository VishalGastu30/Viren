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

/// Reactive stream of alerts directly from DB — bypasses AlertRepository.
/// Used as fallback AND as the primary reactive source for import updates.
final rawAlertsProvider = StreamProvider<List<Alert>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.alerts)
        ..where((a) =>
            a.dismissedAt.isNull() &
            a.snoozedUntil.isSmallerThanValue(DateTime(9998)))
        ..orderBy([(a) => drift.OrderingTerm(
            expression: a.createdAt,
            mode: drift.OrderingMode.desc)]))
      .watch();
});

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() =>
      _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _isRefreshing = false;
  final Set<String> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    // Listen for trade changes — run insight engine when new trades arrive
    // so insights appear automatically after an import
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTradeChangeListener();
    });
  }

  void _setupTradeChangeListener() {
    // Watch allTradesProvider — when trades change, run a force check
    // This handles: manual import, email auto-import, and background sync
    ref.listenManual(allTradesProvider, (prev, next) {
      final prevCount = prev?.value?.length ?? 0;
      final nextCount = next.value?.length ?? 0;

      if (nextCount > prevCount && !_isRefreshing) {
        // New trades were added — run insights in background
        _runInsightsInBackground();
      }
    });
  }

  Future<void> _runInsightsInBackground() async {
    if (_isRefreshing) return;
    // Don't show the spinner for automatic background runs
    // Only show for manual user-initiated refreshes
    try {
      final db = ref.read(appDatabaseProvider);
      final engine = InsightEngine(db);
      await engine.runForceCheck();
      // rawAlertsProvider stream will auto-update the UI
    } catch (_) {}
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final engine = InsightEngine(db);
      await engine.runForceCheck();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: _buildFeedFromBestSource(),
      ),
    );
  }

  Widget _buildFeedFromBestSource() {
    // Watch both providers unconditionally — Riverpod requires
    // all ref.watch() calls to happen in the same order every build.
    final activeAsync = ref.watch(activeAlertsProvider);
    final rawAsync = ref.watch(rawAlertsProvider);

    // Strategy:
    // 1. Try activeAlertsProvider (AlertRepository stream)
    // 2. If it errors OR returns empty, use rawAlertsProvider (direct DB stream)
    // 3. rawAlertsProvider is a StreamProvider — it updates reactively when
    //    new alerts are written (after import, after WorkManager run, etc.)

    // Merge: prefer active alerts, fall back to raw if needed
    List<Alert>? activeAlerts;
    List<Alert>? rawAlerts;

    activeAsync.whenData((data) => activeAlerts = data);
    rawAsync.whenData((data) => rawAlerts = data);

    // Determine which source to use
    final useRaw = activeAlerts == null ||
        (activeAlerts!.isEmpty && rawAlerts != null && rawAlerts!.isNotEmpty);

    final alerts = useRaw ? (rawAlerts ?? []) : (activeAlerts ?? []);
    final isLoading = activeAsync.isLoading && rawAsync.isLoading;

    if (isLoading) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const Center(
              child: CircularProgressIndicator(
                color: DesignTokens.obsidianTeal,
                strokeWidth: 2,
              ),
            ),
          ),
        ],
      );
    }

    final visible = _filterVisible(alerts);
    if (visible.isEmpty) return _buildEmptyState();
    return _buildFeed(visible);
  }

  List<Alert> _filterVisible(List<Alert> alerts) {
    return alerts
        .where((a) =>
            a.alertType != 'MACRO_STATE' &&
            a.alertType != 'PRICE_SNAPSHOT' &&
            a.alertType != 'EMOTION_NOTE' &&
            a.alertType != 'OVERNIGHT_DATA')
        .toList();
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
    // ── Categories using EXACT alertType strings from AlertTriggerService ──
    // These must match the strings passed to createPatternAlert(),
    // createMacroAlert(), createNewsAlert(), checkDrawdown(), etc.

    final urgent = alerts.where((a) =>
        a.severity.name == 'critical' ||
        a.alertType == 'STOP_LOSS_HIT' ||
        a.alertType == 'PRICE_TARGET_HIT').toList();

    final marketIntel = alerts.where((a) =>
        a.alertType == 'NEWS_ALERT' ||      // ← createNewsAlert()
        a.alertType == 'MACRO_ALERT' ||     // ← createMacroAlert()
        a.alertType == 'MORNING_BRIEFING' ||
        a.alertType == 'MOMENTUM_ALERT').toList();   // ← checkMomentum()

    final portfolio = alerts.where((a) =>
        a.alertType == 'DRAWDOWN_ALERT' ||   // ← checkDrawdown()
        a.alertType == 'RECOVERY_ALERT' ||   // ← checkRecovery()
        a.alertType == 'PORTFOLIO_MILESTONE' ||
        a.alertType == 'DCA_OPPORTUNITY' ||
        a.alertType == 'ACCUMULATION_PATTERN' ||
        a.alertType == 'CONCENTRATION_DRIFT').toList();

    final behaviour = alerts.where((a) =>
        a.alertType == 'CONSISTENCY_STREAK' ||
        a.alertType == 'BEHAVIOUR_WARNING' ||  // ← _checkMirrorWarning()
        a.alertType == 'INACTIVITY_ALERT' ||
        a.alertType == 'WEEKLY_DIGEST').toList();

    // Catch-all: any alert not matched above still shows
    final categorised = {
      ...urgent, ...marketIntel, ...portfolio, ...behaviour
    }.map((a) => a.id).toSet();
    final other = alerts
        .where((a) => !categorised.contains(a.id))
        .toList();

    // Sort each group newest first
    for (final list in [urgent, marketIntel, portfolio, behaviour, other]) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (urgent.isNotEmpty) ...[
          _sectionHeader('Urgent', count: urgent.length, isUrgent: true),
          ...urgent.map(_buildCard),
        ],
        if (marketIntel.isNotEmpty) ...[
          _sectionHeader('Market Intelligence', count: marketIntel.length),
          ...marketIntel.map(_buildCard),
        ],
        if (portfolio.isNotEmpty) ...[
          _sectionHeader('Your Portfolio', count: portfolio.length),
          ...portfolio.map(_buildCard),
        ],
        if (behaviour.isNotEmpty) ...[
          _sectionHeader('Your Patterns', count: behaviour.length),
          ...behaviour.map(_buildCard),
        ],
        if (other.isNotEmpty) ...[
          _sectionHeader('Updates', count: other.length),
          ...other.map(_buildCard),
        ],
        if ([urgent, marketIntel, portfolio, behaviour, other]
            .every((l) => l.isEmpty))
          _buildEmptyState(),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${alerts.length} total insights',
            style: TextStyle(
              color: DesignTokens.textMediumContrast.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, {int count = 0, bool isUrgent = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isUrgent ? DesignTokens.crimsonWarning : DesignTokens.textMediumContrast,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isUrgent 
                    ? DesignTokens.crimsonWarning.withValues(alpha: 0.2)
                    : DesignTokens.obsidianTeal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isUrgent ? DesignTokens.crimsonWarning : DesignTokens.obsidianTeal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(Alert alert) {
    if (alert.alertType == 'MACRO_STATE' ||
        alert.alertType == 'PRICE_SNAPSHOT' ||
        alert.alertType == 'EMOTION_NOTE' ||
        alert.alertType == 'OVERNIGHT_DATA') {
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
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_expandedCards.contains(alert.id)) {
              _expandedCards.remove(alert.id);
            } else {
              _expandedCards.add(alert.id);
            }
          });
        },
        child: InsightCard(
          alert: alert,
          isExpanded: _expandedCards.contains(alert.id),
        ),
      ),
    );
  }
}
