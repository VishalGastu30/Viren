import 'package:flutter/material.dart';
import '../../mock_data/holdings_mock.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../core/utils/currency_formatter.dart';
import 'holding_detail_screen.dart';

class HoldingsListScreen extends StatefulWidget {
  const HoldingsListScreen({super.key});

  @override
  State<HoldingsListScreen> createState() => _HoldingsListScreenState();
}

class _HoldingsListScreenState extends State<HoldingsListScreen> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 50), () {
      if(mounted) setState(() => _isLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text(
          'Holdings',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 100), // padding for bottom nav
        itemCount: HoldingsMock.holdings.length,
        separatorBuilder: (context, index) => const Divider(
          indent: 24,
          endIndent: 24,
        ),
        itemBuilder: (context, index) {
          final holding = HoldingsMock.holdings[index];
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _isLoaded ? 1 : 0),
            duration: AnimationPresets.durationNormal + AnimationPresets.staggerItem(index),
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
            child: _AnimatedHoldingRow(holding: holding),
          );
        },
      ),
    );
  }
}

class _AnimatedHoldingRow extends StatefulWidget {
  final Holding holding;
  const _AnimatedHoldingRow({required this.holding});

  @override
  State<_AnimatedHoldingRow> createState() => _AnimatedHoldingRowState();
}

class _AnimatedHoldingRowState extends State<_AnimatedHoldingRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => HoldingDetailScreen(holding: widget.holding),
          ),
        );
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AnimationPresets.durationFast,
        curve: AnimationPresets.micro,
        child: AnimatedContainer(
          duration: AnimationPresets.durationNormal,
          decoration: BoxDecoration(
            color: _isPressed ? DesignTokens.graphiteSurface.withValues(alpha: 0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            children: [
              Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.holding.symbol,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${widget.holding.quantity} qty',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: DesignTokens.textMediumContrast,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DesignTokens.graphiteSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.holding.percentOfPortfolio}%',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(widget.holding.totalValue),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.holding.totalPandL > 0 
                              ? Icons.arrow_upward_rounded 
                              : Icons.arrow_downward_rounded,
                            size: 14,
                            color: widget.holding.totalPandL > 0 
                              ? DesignTokens.obsidianTeal 
                              : DesignTokens.crimsonWarning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            CurrencyFormatter.formatCompact(widget.holding.totalPandL.abs()),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: widget.holding.totalPandL > 0 
                                ? DesignTokens.obsidianTeal 
                                : DesignTokens.crimsonWarning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
