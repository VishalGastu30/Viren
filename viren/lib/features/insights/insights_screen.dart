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

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with TickerProviderStateMixin {
  bool _isRefreshing = false;
  final Set<String> _expandedCards = {};

  late TabController _tabController;
  static const _tabs = ['All', 'Critical', 'Portfolio', 'Patterns', 'Market'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Listen for trade changes — run insight engine when new trades arrive
    // so insights appear automatically after an import
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTradeChangeListener();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const JournalScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: DesignTokens.textMediumContrast),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AlertSettingsScreen())),
          ),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: DesignTokens.obsidianTeal),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: DesignTokens.textMediumContrast),
              onPressed: _refresh,
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: DesignTokens.obsidianTeal,
          unselectedLabelColor: DesignTokens.textMediumContrast,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          indicatorColor: DesignTokens.obsidianTeal,
          indicatorWeight: 2,
          dividerColor: Colors.white.withValues(alpha: 0.05),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
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
    final activeAsync = ref.watch(activeAlertsProvider);
    final rawAsync = ref.watch(rawAlertsProvider);

    List<Alert>? activeAlerts;
    List<Alert>? rawAlerts;
    activeAsync.whenData((d) => activeAlerts = d);
    rawAsync.whenData((d) => rawAlerts = d);

    final useRaw = activeAlerts == null ||
        (activeAlerts!.isEmpty && rawAlerts != null && rawAlerts!.isNotEmpty);
    final alerts = useRaw ? (rawAlerts ?? []) : (activeAlerts ?? []);
    final isLoading = activeAsync.isLoading && rawAsync.isLoading;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
            color: DesignTokens.obsidianTeal, strokeWidth: 2),
      );
    }

    final visible = _filterVisible(alerts);

    if (visible.isEmpty) return _buildEmptyState();

    return TabBarView(
      controller: _tabController,
      children: _tabs.map((tab) {
        final tabAlerts = _filterForTab(visible, tab);
        if (tabAlerts.isEmpty) {
          return _buildTabEmptyState(tab);
        }
        return _buildAlertList(tabAlerts);
      }).toList(),
    );
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

  List<Alert> _filterForTab(List<Alert> alerts, String tab) {
    // Sort newest first for all tabs
    final sorted = List<Alert>.from(alerts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    switch (tab) {
      case 'All':
        return sorted;

      case 'Critical':
        // Urgent: severe alerts and large price moves
        return sorted.where((a) =>
            a.severity.name == 'critical' ||
            a.severity.name == 'warning' ||
            a.alertType == 'CIRCUIT_BREAKER' ||
            a.alertType == 'DRAWDOWN_ALERT' ||
            a.alertType == 'MOMENTUM_ALERT').toList();

      case 'Portfolio':
        // Position-specific alerts
        return sorted.where((a) =>
            a.alertType == 'DRAWDOWN_ALERT' ||
            a.alertType == 'RECOVERY_ALERT' ||
            a.alertType == 'CIRCUIT_BREAKER' ||
            a.alertType == 'MOMENTUM_ALERT' ||
            a.alertType == 'PORTFOLIO_MILESTONE' ||
            a.alertType == 'DCA_OPPORTUNITY' ||
            a.alertType == 'ACCUMULATION_PATTERN' ||
            a.alertType == 'CONCENTRATION_DRIFT' ||
            a.alertType == 'USER_STOP_LOSS' ||
            a.alertType == 'USER_PRICE_TARGET').toList();

      case 'Patterns':
        // Behavioural and habit insights
        return sorted.where((a) =>
            a.alertType == 'CONSISTENCY_STREAK' ||
            a.alertType == 'BEHAVIOUR_WARNING' ||
            a.alertType == 'INACTIVITY_ALERT' ||
            a.alertType == 'WEEKLY_DIGEST').toList();

      case 'Market':
        // External intelligence: news, macro, morning briefing
        return sorted.where((a) =>
            a.alertType == 'NEWS_RELEVANT' ||   // ← exact string from createNewsAlert()
            a.alertType == 'MACRO_EVENT' ||     // ← exact string from createMacroAlert()
            a.alertType == 'MORNING_BRIEFING').toList();

      default:
        return sorted;
    }
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

  Widget _buildTabEmptyState(String tab) {
    final messages = {
      'Critical': 'No urgent alerts — your portfolio looks stable.',
      'Portfolio': 'No position alerts yet. Pull down to scan.',
      'Patterns': 'No behavioural patterns detected yet.\nKeep investing consistently.',
      'Market': 'No market intelligence yet.\nNews and macro events will appear here.',
    };
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 40,
                  color: DesignTokens.textMediumContrast.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                messages[tab] ?? 'Nothing here yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignTokens.textMediumContrast,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertList(List<Alert> alerts) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: alerts.length + 1, // +1 for the count footer
      itemBuilder: (context, index) {
        if (index == alerts.length) {
          // Footer
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            child: Center(
              child: Text(
                '${alerts.length} insight${alerts.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: DesignTokens.textMediumContrast.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              ),
            ),
          );
        }
        return _buildCard(alerts[index]);
      },
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
