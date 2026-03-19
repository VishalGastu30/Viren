import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/navigation/deep_link_service.dart';

import '../core/theme/design_tokens.dart';
import '../core/animations/animation_presets.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/holdings/holdings_list_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/import/import_center_screen.dart';
import '../features/import/manual_trade_entry_screen.dart';
import '../features/scan/scan_progress_screen.dart';

class VirenRouter extends ConsumerStatefulWidget {
  const VirenRouter({super.key});

  @override
  ConsumerState<VirenRouter> createState() => _VirenRouterState();
}

class _VirenRouterState extends ConsumerState<VirenRouter> {
  late final PageController _pageController;
  int _currentIndex = 0;

  // Stable key for AssistantScreen — never changes, never rebuilds the screen.
  final _assistantKey = GlobalKey<AssistantScreenState>();

  // Stable screens list — built once in initState, never recreated
  // so Flutter never destroys and recreates AssistantScreen on tab switches.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _screens = [
      const DashboardScreen(),
      const HoldingsListScreen(),
      const InsightsScreen(),
      AssistantScreen(key: _assistantKey), // no initialMessage, no ValueKey
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToAssistant({String? prompt}) {
    // Switch to the assistant tab
    _pageController.animateToPage(
      kTabAssistant,
      duration: AnimationPresets.durationNormal,
      curve: AnimationPresets.entrance,
    );

    // If there's a prompt, call the method on the existing screen state.
    // Small delay ensures the tab animation has started and the state is mounted.
    if (prompt != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _assistantKey.currentState?.receiveMessage(prompt);
        }
      });
    }
  }

  void _onBottomNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: AnimationPresets.durationNormal,
      curve: AnimationPresets.entrance,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Consume deep link targets from notification taps
    ref.listen<DeepLinkTarget?>(deepLinkProvider, (_, target) {
      if (target == null) return;

      if (target.tab == kTabAssistant && target.payload != null) {
        _navigateToAssistant(prompt: target.payload);
      } else {
        _pageController.animateToPage(
          target.tab,
          duration: AnimationPresets.durationNormal,
          curve: AnimationPresets.entrance,
        );
      }

      ref.read(deepLinkProvider.notifier).consume();
    });

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), 
        children: _screens.asMap().entries.map((entry) {
          return TickerMode(
            enabled: _currentIndex == entry.key,
            child: entry.value,
          );
        }).toList(),
      ),
      floatingActionButton: _currentIndex != 3
          ? FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
             context: context,
             backgroundColor: Colors.transparent,
             builder: (ctx) => Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                   color: DesignTokens.graphiteSurface,
                   borderRadius: BorderRadius.circular(24),
                   border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      ListTile(
                         leading: const Icon(Icons.edit_rounded, color: DesignTokens.obsidianTeal),
                         title: Text('Manual Trade', style: Theme.of(context).textTheme.titleMedium),
                         subtitle: Text('Record a single execution', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                         onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManualTradeEntryScreen()));
                         },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                         leading: const Icon(Icons.upload_file_rounded, color: DesignTokens.ashGold),
                         title: Text('Import File', style: Theme.of(context).textTheme.titleMedium),
                         subtitle: Text('Upload PDF/CSV from broker', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                         onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportCenterScreen()));
                         },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                         leading: const Icon(Icons.mail_outline_rounded, color: DesignTokens.textHighContrast),
                         title: Text('Scan Email', style: Theme.of(context).textTheme.titleMedium),
                         subtitle: Text('Auto-detect contract notes', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                         onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanProgressScreen()));
                         },
                      ),
                      const SizedBox(height: 16),
                   ],
                )
             )
          );
        },
        backgroundColor: DesignTokens.obsidianTeal,
        foregroundColor: DesignTokens.textHighContrast,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      )
          : null,
      bottomNavigationBar: _MorphingBottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
      ),
    );
  }
}

class _MorphingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MorphingBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Custom bottom nav indicating active state using a morphing top border per requirements
    // and using theme references.
    return Container(
      color: DesignTokens.graphiteSurface,
      child: SafeArea(
        top: false,
        child: SizedBox(
           height: 64,
           child: Stack(
             children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                      _NavItem(icon: Icons.dashboard_rounded, label: 'Overview', isActive: currentIndex == 0, onTap: () => onTap(0)),
                      _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Holdings', isActive: currentIndex == 1, onTap: () => onTap(1)),
                      _NavItem(icon: Icons.insights_rounded, label: 'Insights', isActive: currentIndex == 2, onTap: () => onTap(2)),
                      _NavItem(icon: Icons.bolt_rounded, label: 'Assistant', isActive: currentIndex == 3, onTap: () => onTap(3)),
                   ],
                ),
                // Animated Indicator
                AnimatedPositioned(
                  duration: AnimationPresets.durationFast,
                  curve: AnimationPresets.entrance,
                  top: 0,
                  left: (MediaQuery.of(context).size.width / 4) * currentIndex + (MediaQuery.of(context).size.width / 8) - 16,
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: DesignTokens.obsidianTeal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
             ],
           ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.0 : 0.9,
              duration: AnimationPresets.durationFast,
              curve: AnimationPresets.micro,
              child: Icon(
                icon,
                size: 22,
                color: isActive ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
              ),
            ),
            const SizedBox(height: 4),
            Text(
               label,
               style: Theme.of(context).textTheme.bodySmall?.copyWith(
                 fontSize: 10,
                 color: isActive ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
               ),
            ),
          ],
        ),
      ),
    );
  }
}
