import 'package:flutter/material.dart';

import '../../mock_data/alerts_mock.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text(
          'Assistant & Journal',
           style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 20),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
               padding: const EdgeInsets.all(24.0),
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Viren',
                       style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: DesignTokens.graphiteSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'e.g. Why did you alert me on INFY?',
                          hintStyle: Theme.of(context).textTheme.bodyMedium,
                          border: InputBorder.none,
                          icon: const Icon(Icons.search_rounded, color: DesignTokens.textMediumContrast, size: 20),
                        ),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(label: 'Recent Trades'),
                        _FilterChip(label: 'Portfolio Perf'),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Mock Chat Messages
                    const _ChatBubble(
                       message: 'Hi Viren. Why did you alert me on INFY?',
                       isUser: true,
                       index: 0,
                    ),
                    const SizedBox(height: 16),
                    const _ChatBubble(
                       message: 'INFY broke its critical support level of 1430 yesterday. Given the broader weakness in the IT sector, I flagged this as a potential risk for your allocation.',
                       isUser: false,
                       index: 1,
                    ),
                  ]
               ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(
               indent: 24,
               endIndent: 24,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Journal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
               (context, index) {
                 final entry = AlertsMock.journal[index];
                 // Stagger logic
                 return TweenAnimationBuilder<double>(
                   tween: Tween<double>(begin: 0, end: 1),
                   duration: Duration(milliseconds: 600 + (index * 150)),
                   curve: AnimationPresets.entrance,
                   builder: (context, value, child) {
                     return Opacity(
                       opacity: value.clamp(0.0, 1.0),
                       child: Transform.translate(
                         offset: Offset(0, 20 * (1 - value)),
                         child: child,
                       ),
                     );
                   },
                   child: Padding(
                     padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
                     child: IntrinsicHeight(
                       child: Row(
                         crossAxisAlignment: CrossAxisAlignment.stretch,
                         children: [
                           Column(
                             children: [
                               Container(
                                 width: 12,
                                 height: 12,
                                 decoration: BoxDecoration(
                                   color: index == 0 ? DesignTokens.obsidianTeal : DesignTokens.graphiteSurface,
                                   shape: BoxShape.circle,
                                   border: Border.all(
                                     color: index == 0 ? DesignTokens.obsidianTeal : DesignTokens.ashGold, 
                                     width: 2
                                   ),
                                 ),
                               ),
                               if (index != AlertsMock.journal.length -1) // rudimentary timeline line
                                  Expanded(
                                    child: Container(
                                       width: 2,
                                       color: DesignTokens.graphiteSurface,
                                    ),
                                  ),
                             ],
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.date,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: index == 0 ? DesignTokens.obsidianTeal : DesignTokens.ashGold,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                         decoration: BoxDecoration(
                                           color: index == 0 ? DesignTokens.obsidianTeal.withValues(alpha: 0.1) : DesignTokens.graphiteSurface,
                                           borderRadius: BorderRadius.circular(12),
                                         ),
                                         child: Text(
                                           entry.tag,
                                           style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 10,
                                              color: index == 0 ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
                                           ),
                                         ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    entry.note,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      height: 1.5,
                                      color: index == 0 ? DesignTokens.textHighContrast : DesignTokens.textMediumContrast,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 );
               },
              childCount: AlertsMock.journal.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      )
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;

  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.graphiteSurface),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final int index;

  const _ChatBubble({
    required this.message,
    required this.isUser,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: AnimationPresets.entrance,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(isUser ? 20 * (1 - value) : -20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Container(
            padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUser ? DesignTokens.obsidianTeal.withValues(alpha: 0.1) : DesignTokens.graphiteSurface,
            borderRadius: BorderRadius.circular(20).copyWith(
               bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
               topLeft: !isUser ? const Radius.circular(4) : const Radius.circular(20),
            ),
            border: Border.all(
               color: isUser ? DesignTokens.obsidianTeal.withValues(alpha: 0.3) : Colors.transparent,
            )
          ),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
               height: 1.5,
               color: isUser ? DesignTokens.obsidianTeal : DesignTokens.textHighContrast,
               fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
            ),
            ),
          ),
        ),
      ),
    );
  }
}
