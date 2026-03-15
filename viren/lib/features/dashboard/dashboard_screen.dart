import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/integrity/vault_health_service.dart';
import '../../widgets/confidence_meter_widget.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/animations/animation_presets.dart';
import '../../core/intelligence/confidence_calculator.dart';
import '../settings/settings_screen.dart';
import '../assistant/portfolio_analytics_engine.dart' as analytics;

// ─── Fixed allocation color palette ───────────────────────────────────────────

const List<Color> _allocationColors = [
  Color(0xFF00B4A6), // obsidianTeal
  Color(0xFFD4A843), // ashGold
  Color(0xFF6C7FE8), // soft blue
  Color(0xFFE87E6C), // soft coral
  Color(0xFF8BC34A), // soft green
  Color(0xFFAB47BC), // soft purple
  Color(0xFF26C6DA), // cyan
  Color(0xFFFF7043), // deep orange
];

// ═══════════════════════════════════════════════════════════════════════════════
// DashboardScreen — Full rewrite powered by PortfolioAnalyticsEngine
// ═══════════════════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isVisible = false;
  double _scrollOffset = 0.0;
  int _chartViewIndex = 0; // 0=Cumulative, 1=Monthly, 2=By Stock
  int _chartRangeIndex = 3; // 0=3M, 1=6M, 2=1Y, 3=All

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });

    // Trigger confidence score computation if trades exist
    // but no score has been recorded yet
    Future.microtask(() async {
      if (!mounted) return;
      final scoreAsync = ref.read(confidenceScoreProvider);
      scoreAsync.whenData((score) async {
        if (score == null) {
          // No score recorded yet — compute now
          try {
            final db = ref.read(appDatabaseProvider);
            final behaviorRepo = ref.read(behaviorRepositoryProvider);
            final calculator = ConfidenceCalculator(behaviorRepo);
            final allTrades = await db.select(db.trades).get();
            if (allTrades.isNotEmpty) {
              final reasons = <String, String?>{};
              final emotionalStates = <String, String?>{};
              for (final t in allTrades) {
                reasons[t.id] = t.rawTradeNo?.isNotEmpty == true
                    ? 'Imported from broker' : null;
                emotionalStates[t.id] = null;
              }
              await calculator.compute(
                trades: allTrades,
                reasons: reasons,
                emotionalStates: emotionalStates,
              );
            }
          } catch (_) {}
        }
      });
    });
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _shimmer(double width, double height) => AnimatedBuilder(
    animation: _shimmerController,
    builder: (_, __) => Opacity(
      opacity: _shimmerAnimation.value,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  void _showTamperDetails(BuildContext context, VaultHealthStatus status) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.graphiteSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vault Integrity Error', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DesignTokens.crimsonWarning)),
            const SizedBox(height: 16),
            const Text(
              'The cryptographic signature of your local data does not match the recorded audit tail. This could happen if the database file was modified by an external process or due to storage corruption.',
              style: TextStyle(color: DesignTokens.textMediumContrast),
            ),
            const SizedBox(height: 24),
            ...status.chainStatus.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(entry.value ? Icons.check_circle_outline : Icons.error_outline, 
                      color: entry.value ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning, size: 16),
                  const SizedBox(width: 8),
                  Text('Chain: ${entry.key}', style: TextStyle(color: entry.value ? DesignTokens.textMediumContrast : DesignTokens.crimsonWarning)),
                ],
              ),
            )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.crimsonWarning.withValues(alpha: 0.1),
                  foregroundColor: DesignTokens.crimsonWarning,
                ),
                onPressed: () => Navigator.pop(context), 
                child: const Text('I Understand'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerParallax = (_scrollOffset * 0.4).clamp(0.0, 100.0);
    final headerOpacity = (1 - (_scrollOffset / 150)).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        actions: [
          IconButton(
            icon: ref.watch(portfolioSnapshotAnalyticsProvider).when(
              data: (_) => const Icon(Icons.refresh_rounded,
                  color: DesignTokens.textMediumContrast),
              loading: () => const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.obsidianTeal,
                ),
              ),
              error: (_, __) => const Icon(Icons.refresh_rounded,
                  color: DesignTokens.crimsonWarning),
            ),
            onPressed: () => ref.invalidate(portfolioSnapshotAnalyticsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: DesignTokens.textMediumContrast),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: DesignTokens.obsidianTeal,
          backgroundColor: DesignTokens.graphiteSurface,
          onRefresh: () async {
            ref.invalidate(portfolioSnapshotAnalyticsProvider);
            await ref.read(portfolioSnapshotAnalyticsProvider.future);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
            // ── Parallax Header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Opacity(
                opacity: headerOpacity,
                child: Transform.translate(
                  offset: Offset(0, headerParallax),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Portfolio',
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            ref.watch(vaultHealthStatusProvider).maybeWhen(
                                  data: (status) => status.isHealthy
                                      ? const Icon(Icons.verified_user_outlined,
                                          color: DesignTokens.obsidianTeal, size: 20)
                                      : GestureDetector(
                                          onTap: () => _showTamperDetails(context, status),
                                          child: const Icon(Icons.warning_amber_rounded,
                                              color: DesignTokens.crimsonWarning, size: 24),
                                        ),
                                  orElse: () => const SizedBox.shrink(),
                                ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ref.watch(vaultHealthStatusProvider).maybeWhen(
                              data: (status) => status.isHealthy
                                  ? Text(
                                      'Market looks steady today.',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: DesignTokens.obsidianTeal,
                                          ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: DesignTokens.crimsonWarning.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: DesignTokens.crimsonWarning.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.security_rounded,
                                              size: 14, color: DesignTokens.crimsonWarning),
                                          const SizedBox(width: 8),
                                          Text(
                                            'VAULT TAMPER DETECTED',
                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                  color: DesignTokens.crimsonWarning,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                              orElse: () => Text(
                                'Checking vault integrity...',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: DesignTokens.textMediumContrast,
                                    ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Analytics-powered sections ───────────────────────────────
            SliverToBoxAdapter(
              child: ref.watch(portfolioSnapshotAnalyticsProvider).when(
                data: (snap) => _DashboardContent(
                  snap: snap,
                  isVisible: _isVisible,
                  chartViewIndex: _chartViewIndex,
                  chartRangeIndex: _chartRangeIndex,
                  onChartViewChanged: (i) => setState(() => _chartViewIndex = i),
                  onChartRangeChanged: (i) => setState(() => _chartRangeIndex = i),
                ),
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmer(double.infinity, 180),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _shimmer(double.infinity, 80)),
                        const SizedBox(width: 8),
                        Expanded(child: _shimmer(double.infinity, 80)),
                        const SizedBox(width: 8),
                        Expanded(child: _shimmer(double.infinity, 80)),
                      ]),
                      const SizedBox(height: 16),
                      _shimmer(double.infinity, 200),
                      const SizedBox(height: 16),
                      _shimmer(double.infinity, 160),
                    ],
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error loading portfolio: $e',
                      style: const TextStyle(color: DesignTokens.crimsonWarning)),
                ),
              ),
            ),

            // ── Section 7: Confidence Meter ──────────────────────────────
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _isVisible ? 1 : 0),
                duration: AnimationPresets.durationSlow,
                curve: AnimationPresets.entrance,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 50 * (1 - val) * AnimationPresets.parallaxFactor),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: ref.watch(confidenceScoreProvider).when(
                    data: (scoreData) {
                      if (scoreData == null) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: DesignTokens.graphiteSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Behaviour Score',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              Text(
                                'Scores will appear after more trades are recorded. '
                                'Keep investing consistently to build your profile.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: DesignTokens.textMediumContrast),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ConfidenceMeterWidget(
                        metric: ConfidenceMetric(
                          strategicConsistency: scoreData.strategyAdherence / 100,
                          timeDiscipline: scoreData.consistency / 100,
                          emotionalStability: scoreData.emotionalStability / 100,
                          strategicNote: 'Strategy consistency from Vault.',
                          timeNote: 'Time discipline measured against habits.',
                          emotionalNote: 'Emotional stability based on tags.',
                        ),
                      );
                    },
                    loading: () => SizedBox(height: 180, child: Center(child: _shimmer(double.infinity, 180))),
                    error: (_, __) => const Text('Error loading confidence'),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 48),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _DashboardContent — All analytics-powered sections
// ═══════════════════════════════════════════════════════════════════════════════

class _DashboardContent extends StatelessWidget {
  final analytics.PortfolioSnapshot snap;
  final bool isVisible;
  final int chartViewIndex;
  final int chartRangeIndex;
  final ValueChanged<int> onChartViewChanged;
  final ValueChanged<int> onChartRangeChanged;

  const _DashboardContent({
    required this.snap,
    required this.isVisible,
    required this.chartViewIndex,
    required this.chartRangeIndex,
    required this.onChartViewChanged,
    required this.onChartRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Section 1: Hero Portfolio Card ────────────────────────────
        _buildAnimatedSection(
          index: 0,
          child: _buildHeroCard(context),
        ),

        // ── Section 2: Quick Stats Row ───────────────────────────────
        _buildAnimatedSection(
          index: 1,
          child: _buildQuickStats(context),
        ),

        // ── Section 3: Allocation Chart ──────────────────────────────
        if (snap.holdings.isNotEmpty)
          _buildAnimatedSection(
            index: 2,
            child: _buildAllocationChart(context),
          ),

        // ── Section 4: Performance Bar Chart ─────────────────────────
        if (snap.hasPriceData)
          _buildAnimatedSection(
            index: 3,
            child: _buildPerformanceBars(context),
          ),

        // ── Section 5: Capital Deployed Chart ────────────────────────
        if (snap.trades.isNotEmpty)
          _buildAnimatedSection(
            index: 4,
            child: _buildCapitalDeployedChart(context),
          ),

        // ── Section 6: Investor Profile Card ─────────────────────────
        _buildAnimatedSection(
          index: 5,
          child: _buildInvestorProfileCard(context),
        ),

        // ── Section 8: Today's Moves ─────────────────────────────────
        if (snap.hasPriceData)
          _buildAnimatedSection(
            index: 6,
            child: _buildTodaysMoves(context),
          ),
      ],
    );
  }

  Widget _buildAnimatedSection({required int index, required Widget child}) {
    final offset = 20.0 + (index * 10.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isVisible ? 1 : 0),
      duration: AnimationPresets.durationNormal + Duration(milliseconds: index * 60),
      curve: AnimationPresets.entrance,
      builder: (context, val, childWidget) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - val) * AnimationPresets.parallaxFactor),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  // ── Section 1: Hero Portfolio Card ─────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context) {
    final isPositive = snap.totalPnL >= 0;
    final pnlColor = isPositive ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio Value', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _AnimatedCurrency(
              value: snap.totalCurrentValue,
              isVisible: isVisible,
              textStyle: Theme.of(context).textTheme.displayLarge!,
            ),
            const SizedBox(height: 16),

            // P&L chips row
            Row(
              children: [
                // Unrealised P&L chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pnlColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 16,
                        color: pnlColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${CurrencyFormatter.formatCompact(snap.totalPnL.abs())} (${snap.totalReturnPct >= 0 ? '+' : ''}${snap.totalReturnPct.toStringAsFixed(2)}%)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: pnlColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Day P&L chip — placeholder
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Day: —',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DesignTokens.textMediumContrast,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: DesignTokens.obsidianTeal.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 16),

            // Stat row: Invested | XIRR | Since
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(
                  label: 'Invested',
                  value: CurrencyFormatter.formatCompact(snap.totalInvested),
                ),
                _StatItem(
                  label: 'XIRR',
                  value: snap.xirr != null
                      ? '${snap.xirr! >= 0 ? '+' : ''}${snap.xirr!.toStringAsFixed(1)}%'
                      : '—',
                  valueColor: snap.xirr != null
                      ? (snap.xirr! >= 0 ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning)
                      : null,
                ),
                _StatItem(
                  label: 'Since',
                  value: snap.firstTradeDate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 2: Quick Stats Row ─────────────────────────────────────────────
  Widget _buildQuickStats(BuildContext context) {
    // Find NIFTYBEES holding for benchmark comparison
    final niftyHolding = snap.holdings.where(
      (h) => h.symbol.contains('NIFTYBEES'),
    ).firstOrNull;

    String benchmarkLabel = 'vs NIFTYBEES';
    String benchmarkValue = '—';
    Color benchmarkColor = DesignTokens.textMediumContrast;

    if (niftyHolding != null && niftyHolding.returnPct != null) {
      final diff = snap.totalReturnPct - niftyHolding.returnPct!;
      benchmarkValue = '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%';
      benchmarkLabel = diff >= 0 ? 'vs NIFTYBEES ▲' : 'vs NIFTYBEES ▼';
      benchmarkColor = diff >= 0 ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _QuickStatCard(
              label: 'Best Today',
              value: snap.bestByReturn?.symbol ?? '—',
              sub: snap.bestByReturn?.returnStr ?? 'No data',
              color: (snap.bestByReturn?.isProfitable ?? false)
                  ? DesignTokens.obsidianTeal
                  : DesignTokens.crimsonWarning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickStatCard(
              label: benchmarkLabel,
              value: benchmarkValue,
              sub: niftyHolding != null ? 'portfolio vs index' : 'No NIFTYBEES',
              color: benchmarkColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickStatCard(
              label: 'Charges Paid',
              value: CurrencyFormatter.formatCompact(snap.totalCharges),
              sub: 'drag on returns',
              color: DesignTokens.ashGold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 3: Allocation Chart ────────────────────────────────────────────
  Widget _buildAllocationChart(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allocation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 200,
                width: 200,
                child: _AllocationDonutFromSnap(
                  holdings: snap.holdings,
                  totalCurrentValue: snap.totalCurrentValue,
                ),
              ),
              const SizedBox(width: 32),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snap.holdings.asMap().entries.take(6).map((entry) {
                    final color = _allocationColors[entry.key % _allocationColors.length];
                    final holding = entry.value;
                    final pct = snap.totalCurrentValue > 0
                        ? (((holding.cmp ?? holding.avgCost) * holding.qty)
                            / snap.totalCurrentValue * 100)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(holding.symbol,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                                Text('${pct.toStringAsFixed(1)}%',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section 4: Performance Bar Chart ───────────────────────────────────────
  Widget _buildPerformanceBars(BuildContext context) {
    final withPrices = snap.holdings.where((h) => h.hasPriceData && h.returnPct != null).toList()
      ..sort((a, b) => (b.returnPct ?? 0).compareTo(a.returnPct ?? 0));

    if (withPrices.isEmpty) {
      return const SizedBox.shrink();
    }

    final data = withPrices.map((h) => (symbol: h.symbol, returnPct: h.returnPct!)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: data.length * 44.0,
              child: CustomPaint(
                size: Size(double.infinity, data.length * 44.0),
                painter: _PerformanceBarPainter(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 5: Capital Deployed Chart ──────────────────────────────────────
  Widget _buildCapitalDeployedChart(BuildContext context) {
    if (snap.trades.isEmpty) return const SizedBox.shrink();

    // Filter trades by range
    DateTime cutoff = DateTime.fromMillisecondsSinceEpoch(0);
    final now = DateTime.now();
    switch (chartRangeIndex) {
      case 0: cutoff = now.subtract(const Duration(days: 90)); break;
      case 1: cutoff = now.subtract(const Duration(days: 180)); break;
      case 2: cutoff = now.subtract(const Duration(days: 365)); break;
      case 3: break; // All
    }

    final filteredTrades = snap.trades
        .where((t) => t.tradeTimestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.tradeTimestamp.compareTo(b.tradeTimestamp));

    if (filteredTrades.isEmpty) return const SizedBox.shrink();

    Widget chartWidget;

    if (chartViewIndex == 0) {
      // ── VIEW 0: Cumulative Invested ──
      double running = 0;
      final spots = <FlSpot>[];
      final firstDate = filteredTrades.first.tradeTimestamp;
      
      for (final t in filteredTrades) {
        if (t.tradeType == db_enums.TradeType.buy) {
          running += t.totalValue;
        } else {
          running -= t.totalValue;
        }
        final days = t.tradeTimestamp.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(days, running));
      }

      chartWidget = SizedBox(
        height: 140,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: DesignTokens.obsidianTeal,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      DesignTokens.obsidianTeal.withValues(alpha: 0.3),
                      DesignTokens.obsidianTeal.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (chartViewIndex == 1) {
      // ── VIEW 1: Monthly % Bars ──
      final Map<String, double> monthlyNet = {};
      double totalNet = 0;
      for (final t in filteredTrades) {
        final key = DateFormat('yyyy-MM').format(t.tradeTimestamp);
        final amount = t.tradeType == db_enums.TradeType.buy ? t.totalValue : -t.totalValue;
        monthlyNet[key] = (monthlyNet[key] ?? 0) + amount;
        if (amount > 0) totalNet += amount;
      }
      
      final sortedKeys = monthlyNet.keys.toList()..sort();
      final barData = sortedKeys.map((k) {
        final parts = k.split('-');
        final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return (label: monthNames[int.parse(parts[1]) - 1], value: monthlyNet[k]!, pct: totalNet > 0 ? (monthlyNet[k]! / totalNet * 100) : 0.0);
      }).toList();

      chartWidget = SizedBox(
        height: 140,
        child: CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _MonthlyPctBarPainter(data: barData),
        ),
      );
    } else {
      // ── VIEW 2: By Stock Stacked Bars ──
      final Map<String, Map<String, double>> grouped = {};
      for (final t in filteredTrades) {
        final key = DateFormat('yyyy-MM').format(t.tradeTimestamp);
        final amount = t.tradeType == db_enums.TradeType.buy ? t.totalValue : -t.totalValue;
        if (amount <= 0) continue; // Only show buys for stack
        
        grouped.putIfAbsent(key, () => {});
        grouped[key]![t.instrumentSymbol] = (grouped[key]![t.instrumentSymbol] ?? 0) + amount;
      }
      
      final sortedKeys = grouped.keys.toList()..sort();
      final stackData = sortedKeys.map((k) {
        final parts = k.split('-');
        final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return (label: monthNames[int.parse(parts[1]) - 1], stocks: grouped[k]!);
      }).toList();

      chartWidget = SizedBox(
        height: 140,
        child: CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _StackedBarPainter(data: stackData, colors: _allocationColors),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Capital Deployed', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  chartViewIndex == 0 ? 'Cumulative' : chartViewIndex == 1 ? 'Monthly %' : 'By Stock',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.obsidianTeal),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // View Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildToggleBtn(context, 'Cumulative', 0, chartViewIndex, onChartViewChanged),
                  _buildToggleBtn(context, 'Monthly', 1, chartViewIndex, onChartViewChanged),
                  _buildToggleBtn(context, 'By Stock', 2, chartViewIndex, onChartViewChanged),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Range Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRangeBtn(context, '3M', 0, chartRangeIndex, onChartRangeChanged),
                const SizedBox(width: 8),
                _buildRangeBtn(context, '6M', 1, chartRangeIndex, onChartRangeChanged),
                const SizedBox(width: 8),
                _buildRangeBtn(context, '1Y', 2, chartRangeIndex, onChartRangeChanged),
                const SizedBox(width: 8),
                _buildRangeBtn(context, 'All', 3, chartRangeIndex, onChartRangeChanged),
              ],
            ),
            
            const SizedBox(height: 24),
            chartWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildToggleBtn(BuildContext context, String label, int index, int current, ValueChanged<int> onSelect) {
    final isSelected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: AnimationPresets.durationFast,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? DesignTokens.graphiteBase : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected ? DesignTokens.textHighContrast : DesignTokens.textMediumContrast,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRangeBtn(BuildContext context, String label, int index, int current, ValueChanged<int> onSelect) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: () => onSelect(index),
      child: AnimatedContainer(
        duration: AnimationPresets.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? DesignTokens.obsidianTeal.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Section 6: Investor Profile Card ───────────────────────────────────────
  Widget _buildInvestorProfileCard(BuildContext context) {
    // Compute investment style
    final Map<String, int> tradesByMonth = {};
    for (final t in snap.trades) {
      final key = DateFormat('yyyy-MM').format(t.tradeTimestamp);
      tradesByMonth[key] = (tradesByMonth[key] ?? 0) + 1;
    }
    final distinctMonths = tradesByMonth.keys.length;

    String investmentStyle;
    if (snap.totalTrades < 3) {
      investmentStyle = 'Building history...';
    } else if (distinctMonths > 3) {
      investmentStyle = 'Regular Investor — you invest consistently over time';
    } else if (distinctMonths <= 2 && snap.totalTrades > 0) {
      investmentStyle = 'Lump Sum style — you invest in concentrated bursts';
    } else {
      investmentStyle = 'Mixed approach';
    }

    final avgTradeSize = snap.totalTrades > 0
        ? snap.totalInvested / snap.totalTrades
        : 0.0;
    final chargesPercent = snap.totalInvested > 0
        ? (snap.totalCharges / snap.totalInvested * 100)
        : 0.0;

    // Days since first trade
    int daysSinceFirst = 0;
    if (snap.trades.isNotEmpty) {
      daysSinceFirst = DateTime.now().difference(snap.trades.first.tradeTimestamp).inDays;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
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
            const SizedBox(height: 16),
            _ProfileRow(label: 'First Investment', value: snap.firstTradeDate),
            _ProfileRow(label: 'Time in Market', value: '$daysSinceFirst days'),
            _ProfileRow(label: 'Total Trades', value: '${snap.totalTrades}'),
            _ProfileRow(label: 'Avg Trade Size', value: CurrencyFormatter.formatCompact(avgTradeSize)),
            _ProfileRow(label: 'Charges as % of Invested', value: '${chargesPercent.toStringAsFixed(2)}%'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DesignTokens.ashGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignTokens.ashGold.withValues(alpha: 0.2)),
              ),
              child: Text(
                investmentStyle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.ashGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 8: Today's Moves ───────────────────────────────────────────────
  Widget _buildTodaysMoves(BuildContext context) {
    final withDayChange = snap.holdings
        .where((h) => h.dayChangePercent != null)
        .toList()
      ..sort((a, b) => (b.dayChangePercent!.abs()).compareTo(a.dayChangePercent!.abs()));

    if (withDayChange.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Today's Moves", style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: DesignTokens.obsidianTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('live', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.obsidianTeal,
                  fontSize: 10,
                )),
              ],
            ),
            const SizedBox(height: 12),
            ...withDayChange.map((h) {
              final isPos = h.dayChangePercent! >= 0;
              final color = isPos ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;
              final dayPnl = h.currentValue != null && h.invested > 0
                  ? (h.cmp! * h.qty * h.dayChangePercent! / 100)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(h.symbol,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${isPos ? '+' : ''}${h.dayChangePercent!.toStringAsFixed(2)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${isPos ? '+' : ''}${CurrencyFormatter.formatCompact(dayPnl.abs())}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: DesignTokens.textMediumContrast,
          fontSize: 10,
        )),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: valueColor,
        )),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DesignTokens.textMediumContrast,
            fontSize: 10,
          )),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          )),
          const SizedBox(height: 2),
          Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: DesignTokens.textMediumContrast,
          )),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DesignTokens.textMediumContrast,
          )),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}

class _AnimatedCurrency extends StatelessWidget {
  final double value;
  final bool isVisible;
  final TextStyle textStyle;

  const _AnimatedCurrency({
    required this.value,
    required this.isVisible,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isVisible ? value : 0),
      duration: AnimationPresets.durationNormal,
      curve: AnimationPresets.entrance,
      builder: (context, currentValue, child) {
        return Text(
          CurrencyFormatter.format(currentValue),
          style: textStyle,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Custom Painters
// ═══════════════════════════════════════════════════════════════════════════════

class _PerformanceBarPainter extends CustomPainter {
  final List<({String symbol, double returnPct})> data;

  _PerformanceBarPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxAbs = data.map((d) => d.returnPct.abs()).reduce(math.max);
    if (maxAbs == 0) return;

    const rowHeight = 36.0;
    const rowSpacing = 8.0;
    const labelWidth = 80.0;
    const valueWidth = 60.0;
    final barAreaWidth = size.width - labelWidth - valueWidth - 16;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final y = i * (rowHeight + rowSpacing);
      final isPositive = d.returnPct >= 0;
      final color = isPositive ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;

      // Symbol label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: d.symbol,
          style: TextStyle(
            color: DesignTokens.textHighContrast,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: labelWidth);
      labelPainter.paint(canvas, Offset(0, y + (rowHeight - labelPainter.height) / 2));

      // Bar
      final barWidth = (d.returnPct.abs() / maxAbs) * barAreaWidth;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelWidth + 8,
          y + (rowHeight - 16) / 2,
          barWidth.clamp(4.0, barAreaWidth),
          16,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        barRect,
        Paint()..color = color.withValues(alpha: 0.7),
      );

      // Return % value
      final valuePainter = TextPainter(
        text: TextSpan(
          text: '${isPositive ? '+' : ''}${d.returnPct.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: valueWidth);
      valuePainter.paint(
        canvas,
        Offset(size.width - valuePainter.width, y + (rowHeight - valuePainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PerformanceBarPainter oldDelegate) =>
      oldDelegate.data != data;
}

class _MonthlyPctBarPainter extends CustomPainter {
  final List<({String label, double value, double pct})> data;

  _MonthlyPctBarPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxPct = data.map((d) => d.pct.abs()).reduce(math.max);
    if (maxPct == 0) return;

    const bottomPad = 24.0;
    final chartHeight = size.height - bottomPad;
    final barWidth = (size.width / data.length) * 0.6;
    final spacing = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final cx = spacing * i + spacing / 2;
      final barHeight = (d.pct.abs() / maxPct) * chartHeight * 0.85;
      final isPositive = d.value >= 0;

      // Bar
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cx - barWidth / 2,
          chartHeight - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        barRect,
        Paint()
          ..color = isPositive
              ? DesignTokens.obsidianTeal.withValues(alpha: 0.6)
              : DesignTokens.crimsonWarning.withValues(alpha: 0.6),
      );

      // Value % label if tall enough
      if (d.pct.abs() > 15) {
        final pctPainter = TextPainter(
          text: TextSpan(
            text: '${d.pct.abs().round()}%',
            style: TextStyle(
              color: isPositive ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        pctPainter.paint(
          canvas,
          Offset(cx - pctPainter.width / 2, chartHeight - barHeight - 12),
        );
      }

      // Month label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: d.label,
          style: TextStyle(
            color: DesignTokens.textMediumContrast.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(cx - labelPainter.width / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyPctBarPainter oldDelegate) =>
      oldDelegate.data != data;
}

class _StackedBarPainter extends CustomPainter {
  final List<({String label, Map<String, double> stocks})> data;
  final List<Color> colors;

  _StackedBarPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Find max total for any month to scale by
    double maxTotal = 0;
    for (final d in data) {
      final total = d.stocks.values.fold(0.0, (sum, val) => sum + val);
      if (total > maxTotal) maxTotal = total;
    }
    if (maxTotal == 0) return;

    const bottomPad = 24.0;
    final chartHeight = size.height - bottomPad;
    final barWidth = (size.width / data.length) * 0.6;
    final spacing = size.width / data.length;

    // Build symbol to color map
    final symbolColors = <String, Color>{};
    int colorIdx = 0;
    for (final d in data) {
      for (final s in d.stocks.keys) {
        if (!symbolColors.containsKey(s)) {
          symbolColors[s] = colors[colorIdx % colors.length];
          colorIdx++;
        }
      }
    }

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final cx = spacing * i + spacing / 2;
      
      double currentY = chartHeight;
      final sortedStocks = d.stocks.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedStocks) {
        final segmentHeight = (entry.value / maxTotal) * chartHeight * 0.85;
        
        // Draw segment
        final rect = Rect.fromLTWH(
          cx - barWidth / 2,
          currentY - segmentHeight,
          barWidth,
          segmentHeight,
        );
        
        // Add 1px gap between segments by making rect slightly smaller
        final paintRect = rect.deflate(0.5);
        if (paintRect.height > 0) {
            canvas.drawRect(
              paintRect,
              Paint()..color = symbolColors[entry.key]!,
            );
        }
        
        currentY -= segmentHeight;
      }

      // Month label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: d.label,
          style: TextStyle(
            color: DesignTokens.textMediumContrast.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(cx - labelPainter.width / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Allocation Donut from Snapshot Data
// ═══════════════════════════════════════════════════════════════════════════════

class _AllocationDonutFromSnap extends StatelessWidget {
  final List<analytics.HoldingAnalysis> holdings;
  final double totalCurrentValue;

  const _AllocationDonutFromSnap({
    required this.holdings,
    required this.totalCurrentValue,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AnimationPresets.durationChartDraw,
      curve: AnimationPresets.entrance,
      builder: (context, progress, _) {
        return CustomPaint(
          size: const Size.square(200),
          painter: _SnapDonutPainter(
            holdings: holdings,
            totalCurrentValue: totalCurrentValue,
            progress: progress,
          ),
        );
      },
    );
  }
}

class _SnapDonutPainter extends CustomPainter {
  final List<analytics.HoldingAnalysis> holdings;
  final double totalCurrentValue;
  final double progress;

  _SnapDonutPainter({
    required this.holdings,
    required this.totalCurrentValue,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    // Background track
    canvas.drawCircle(
      center,
      radius - strokeWidth / 2,
      Paint()
        ..color = DesignTokens.graphiteSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (totalCurrentValue <= 0) return;

    double currentAngle = -math.pi / 2;

    for (int i = 0; i < holdings.length; i++) {
      final h = holdings[i];
      final value = (h.cmp ?? h.avgCost) * h.qty;
      final sweepAngle = (value / totalCurrentValue) * 2 * math.pi * progress;

      final paint = Paint()
        ..color = _allocationColors[i % _allocationColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
      canvas.drawArc(rect, currentAngle, sweepAngle - 0.05, false, paint);

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _SnapDonutPainter old) =>
      old.progress != progress;
}
