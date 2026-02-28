import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/integrity/vault_health_service.dart';
import '../../widgets/confidence_meter_widget.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/charts/allocation_donut_chart.dart';
import '../../widgets/charts/monthly_sparkline.dart';
import '../../core/animations/animation_presets.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isVisible = false;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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
            icon: const Icon(Icons.settings_outlined, color: DesignTokens.textMediumContrast),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
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
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _isVisible ? 1 : 0),
                duration: AnimationPresets.durationNormal,
                curve: AnimationPresets.entrance,
                builder: (context, val, child) {
                   return Opacity(
                     opacity: val,
                     child: Transform.translate(
                       offset: Offset(0, 20 * (1 - val) * AnimationPresets.parallaxFactor),
                       child: child,
                     ),
                   );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: DesignTokens.graphiteSurface, // Surface color
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: ref.watch(holdingsStreamProvider).when(
                      data: (holdings) {
                        final totalValue = holdings.fold(0.0, (acc, h) => acc + h.investedValue);
                        final totalDayChange = 0.0; // Placeholder for now
                        final dayChangePercent = totalValue > 0 ? (totalDayChange / (totalValue - totalDayChange) * 100) : 0.0;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Value', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 8),
                             _AnimatedCurrency(
                              value: totalValue,
                              isVisible: _isVisible,
                              textStyle: Theme.of(context).textTheme.displayLarge!,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (totalDayChange >= 0 ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        totalDayChange >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
                                        size: 16, 
                                        color: totalDayChange >= 0 ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${CurrencyFormatter.formatCompact(totalDayChange.abs())} (${dayChangePercent.toStringAsFixed(2)}%)',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: totalDayChange >= 0 ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Text('Error loading portfolio data'),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _isVisible ? 1 : 0),
                duration: AnimationPresets.durationNormal,
                curve: AnimationPresets.entrance,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - val) * AnimationPresets.parallaxFactor),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ref.watch(holdingsStreamProvider).when(
                      data: (holdings) {
                        final totalInvested = holdings.fold(0.0, (acc, h) => acc + h.investedValue);
                        final totalCurrentValue = totalInvested; // Placeholder for now
                        final totalGain = 0.0; // Placeholder for now

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Invested', style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(height: 4),
                                   _AnimatedCurrency(
                                    value: totalInvested,
                                    isVisible: _isVisible,
                                    textStyle: Theme.of(context).textTheme.titleLarge!,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Total Returns', style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(height: 4),
                                   _AnimatedCurrency(
                                    value: totalGain,
                                    isVisible: _isVisible,
                                    textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                                       color: totalGain >= 0 
                                        ? DesignTokens.obsidianTeal 
                                        : DesignTokens.crimsonWarning,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Allocation',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 200,
                                width: 200,
                                child: AllocationDonutChart(holdings: holdings),
                              ),
                              const SizedBox(width: 40),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: holdings.take(4).map((holding) {
                                  final percent = totalCurrentValue > 0 
                                      ? (holding.investedValue / totalCurrentValue * 100).toStringAsFixed(1)
                                      : '0';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: DesignTokens.obsidianTeal.withValues(alpha: 0.8),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(holding.instrumentSymbol, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                            Text('$percent%', style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                    error: (_, __) => const Text('Error loading allocation'),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _isVisible ? 1 : 0),
                duration: AnimationPresets.durationSlow,
                curve: AnimationPresets.entrance,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 40 * (1 - val) * AnimationPresets.parallaxFactor),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                        Text(
                          'Monthly Growth',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ref.watch(portfolioSnapshotsProvider).when(
                          data: (snapshots) {
                            if (snapshots.isEmpty) {
                              return SizedBox(
                                height: 60,
                                child: Center(
                                  child: Text(
                                    'Add trades to see growth over time',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DesignTokens.textMediumContrast,
                                    ),
                                  ),
                                ),
                              );
                            }
                            // Use totalInvested values from snapshots (newest last for sparkline)
                            final dataPoints = snapshots
                                .reversed
                                .take(12)
                                .map((s) => s.totalInvested)
                                .toList();
                            return MonthlySparkline(dataPoints: dataPoints);
                          },
                          loading: () => const SizedBox(
                            height: 60,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.obsidianTeal)),
                          ),
                          error: (_, __) => const MonthlySparkline(dataPoints: [0.0]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                        return const ConfidenceMeterWidget(
                          metric: ConfidenceMetric(
                            strategicConsistency: 0.5,
                            timeDiscipline: 0.5,
                            emotionalStability: 0.5,
                            strategicNote: 'No data yet. Import trades.',
                            timeNote: 'No data yet. Import trades.',
                            emotionalNote: 'No data yet. Import trades.',
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
                    loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
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
