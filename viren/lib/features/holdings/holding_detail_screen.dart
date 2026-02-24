import 'package:flutter/material.dart';

import '../../mock_data/holdings_mock.dart';
import '../../mock_data/alerts_mock.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/charts/candlestick_chart.dart';

import '../../core/animations/animation_presets.dart';

class HoldingDetailScreen extends StatefulWidget {
  final Holding holding;

  const HoldingDetailScreen({super.key, required this.holding});

  @override
  State<HoldingDetailScreen> createState() => _HoldingDetailScreenState();
}

class _HoldingDetailScreenState extends State<HoldingDetailScreen> {
  String _selectedTimeframe = '1M';
  final List<String> _timeframes = ['1M', '3M', '6M', '1Y'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text(widget.holding.symbol),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.holding.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(widget.holding.currentPrice, showDecimals: true),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      CurrencyFormatter.formatPercentage((widget.holding.currentPrice - widget.holding.avgPrice)/widget.holding.avgPrice * 100),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: widget.holding.currentPrice >= widget.holding.avgPrice 
                          ? DesignTokens.obsidianTeal 
                          : DesignTokens.crimsonWarning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Chart Area
              SizedBox(
                height: 240,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: AnimationPresets.durationChartDraw == Duration.zero ? const Duration(milliseconds: 1) : AnimationPresets.durationChartDraw,
                  curve: AnimationPresets.entrance,
                   builder: (context, value, child) {
                     return CandlestickChart(
                        data: widget.holding.history.map((price) {
                           // Mocking High/Low/Open/Close from single price points for demo
                           return CandlestickData(
                             open: price * 0.99,
                             high: price * 1.02,
                             low: price * 0.98,
                             close: price,
                             date: DateTime.now(), // Date not rendered on axis yet
                           );
                        }).toList(),
                     );
                   }
                )
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _timeframes.map((tf) {
                  final isSelected = tf == _selectedTimeframe;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                         _selectedTimeframe = tf;
                      });
                    },
                    child: AnimatedContainer(
                      duration: AnimationPresets.durationFast,
                      curve: AnimationPresets.entrance,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? DesignTokens.graphiteSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? DesignTokens.obsidianTeal.withValues(alpha: 0.5) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        tf,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected ? DesignTokens.textHighContrast : DesignTokens.textMediumContrast,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 48),
              
              // Stats
              Row(
                children: [
                   Expanded(
                     child: _StatCard(
                       label: 'Invested', 
                       value: CurrencyFormatter.formatCompact(widget.holding.avgPrice * widget.holding.quantity),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: _StatCard(
                        label: 'Current', 
                        value: CurrencyFormatter.formatCompact(widget.holding.totalValue),
                        isHighlight: true,
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 16),
               Row(
                children: [
                   Expanded(
                     child: _StatCard(
                       label: 'Avg Price', 
                       value: CurrencyFormatter.format(widget.holding.avgPrice),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: _StatCard(
                        label: 'Quantity', 
                        value: widget.holding.quantity.toString(),
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 32),
               
               // Alerts Accordion
               _AlertsAccordion(symbol: widget.holding.symbol),
               const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _StatCard({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value, 
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isHighlight ? DesignTokens.obsidianTeal : DesignTokens.textHighContrast,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsAccordion extends StatefulWidget {
  final String symbol;

  const _AlertsAccordion({required this.symbol});

  @override
  State<_AlertsAccordion> createState() => _AlertsAccordionState();
}

class _AlertsAccordionState extends State<_AlertsAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Filter alerts to mock finding relevant ones for this holding
    final relevantAlerts = AlertsMock.insights.where((a) => a.title.contains(widget.symbol) || a.description.contains(widget.symbol)).toList();

    if (relevantAlerts.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? DesignTokens.obsidianTeal.withValues(alpha: 0.3) : Colors.transparent,
        )
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: DesignTokens.obsidianTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${relevantAlerts.length} Active Alert${relevantAlerts.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: AnimationPresets.durationFast,
                    curve: AnimationPresets.entrance,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: DesignTokens.textMediumContrast),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: relevantAlerts.map((alert) {
                   Color alertColor;
                   switch (alert.severity) {
                     case AlertSeverity.critical:
                       alertColor = DesignTokens.crimsonWarning;
                       break;
                     case AlertSeverity.warning:
                       alertColor = DesignTokens.ashGold;
                       break;
                     case AlertSeverity.success:
                       alertColor = DesignTokens.obsidianTeal;
                       break;
                     case AlertSeverity.info:
                       alertColor = DesignTokens.textMediumContrast;
                       break;
                   }
                   return Padding(
                     padding: const EdgeInsets.only(top: 12.0),
                     child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Container(
                             margin: const EdgeInsets.only(top: 4),
                             width: 8,
                             height: 8,
                             decoration: BoxDecoration(
                               color: alertColor,
                               shape: BoxShape.circle,
                             ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(alert.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: alertColor)),
                                const SizedBox(height: 4),
                                Text(alert.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
                                const SizedBox(height: 4),
                                Text(alert.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: DesignTokens.textMediumContrast)),
                              ],
                            ),
                          )
                       ],
                     ),
                   );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: AnimationPresets.durationNormal,
            firstCurve: AnimationPresets.entrance,
            secondCurve: AnimationPresets.entrance,
          ),
        ],
      ),
    );
  }
}


