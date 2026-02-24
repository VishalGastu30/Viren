import 'package:flutter/material.dart';

import '../../mock_data/portfolio_mock.dart';
import '../../mock_data/holdings_mock.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/charts/allocation_donut_chart.dart';
import '../../widgets/charts/monthly_sparkline.dart';
import '../../core/animations/animation_presets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  @override
  Widget build(BuildContext context) {
    final headerParallax = (_scrollOffset * 0.4).clamp(0.0, 100.0);
    final headerOpacity = (1 - (_scrollOffset / 150)).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
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
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portfolio',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Market looks steady today.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: DesignTokens.obsidianTeal, // Primary accent
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
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) {
                   return Opacity(
                     opacity: val,
                     child: Transform.translate(
                       offset: Offset(0, 20 * (1 - val)),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Value', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                         _AnimatedCurrency(
                          value: PortfolioMock.currentValue,
                          isVisible: _isVisible,
                          textStyle: Theme.of(context).textTheme.displayLarge!,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: DesignTokens.obsidianTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_upward_rounded, size: 16, color: DesignTokens.obsidianTeal),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${CurrencyFormatter.formatCompact(PortfolioMock.dayChange)} (${PortfolioMock.dayChangePercent}%)',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DesignTokens.obsidianTeal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - val)),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
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
                                value: PortfolioMock.totalInvested,
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
                                value: PortfolioMock.overallPandL,
                                isVisible: _isVisible,
                                textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                                   color: PortfolioMock.overallPandL > 0 
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
                          const SizedBox(
                            height: 200,
                            width: 200,
                            child: AllocationDonutChart(),
                          ),
                          const SizedBox(width: 40),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: HoldingsMock.holdings.take(4).map((holding) {
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
                                        Text(holding.symbol, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                        Text('${holding.percentOfPortfolio}%', style: Theme.of(context).textTheme.bodySmall),
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
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _isVisible ? 1 : 0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 40 * (1 - val)),
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
                        MonthlySparkline(dataPoints: PortfolioMock.monthlySparks),
                      ],
                    ),
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
