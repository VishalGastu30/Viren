import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../core/utils/currency_formatter.dart';
import 'holding_detail_screen.dart';

class HoldingsListScreen extends ConsumerStatefulWidget {
  const HoldingsListScreen({super.key});

  @override
  ConsumerState<HoldingsListScreen> createState() => _HoldingsListScreenState();
}

class _HoldingsListScreenState extends ConsumerState<HoldingsListScreen> {
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
      body: ref.watch(holdingsStreamProvider).when(
        data: (holdings) {
          if (holdings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.inventory_2_outlined, size: 64, color: DesignTokens.textMediumContrast),
                   const SizedBox(height: 16),
                   Text('No holdings yet.', style: Theme.of(context).textTheme.titleMedium),
                   const SizedBox(height: 8),
                   Text('Import trades or add them manually to see your portfolio.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 16, bottom: 100), // padding for bottom nav
            itemCount: holdings.length,
            separatorBuilder: (context, index) => const Divider(
              indent: 24,
              endIndent: 24,
            ),
            itemBuilder: (context, index) {
              final holding = holdings[index];
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _AnimatedHoldingRow extends StatefulWidget {
  final Holding holding; // Using Drift model
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
                          widget.holding.instrumentSymbol,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${widget.holding.totalQuantity.toStringAsFixed(0)} qty',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: DesignTokens.textMediumContrast,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '@ ${CurrencyFormatter.format(widget.holding.averagePrice, showDecimals: true)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: DesignTokens.textMediumContrast,
                                fontSize: 11,
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
                        CurrencyFormatter.format(widget.holding.investedValue, showDecimals: true),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded, 
                            size: 14,
                            color: DesignTokens.obsidianTeal,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '--',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DesignTokens.obsidianTeal,
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
