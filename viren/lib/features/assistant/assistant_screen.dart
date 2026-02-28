import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/theme/design_tokens.dart';
import '../../core/intelligence/ai/data_sanitizer.dart';
import '../../core/animations/animation_presets.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isTyping;

  ChatMessage({required this.text, required this.isUser, this.isTyping = false});
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'Viren is initializing...',
        isUser: false,
      ),
    );
  }

  bool _isTyping = false;

  void _handleSuggestionTap(String label, String actionType) async {
    if (_isTyping) return;

    setState(() {
      _messages.insert(0, ChatMessage(text: label, isUser: true));
      _isTyping = true;
    });

    if (!mounted) return;
    setState(() {
      _messages.insert(0, ChatMessage(text: '...', isUser: false, isTyping: true));
    });

    try {
      final aiProvider = ref.read(aiProviderProvider);
      final String answer;

      if (actionType == 'summarize') {
        final holdings = await ref.read(holdingsStreamProvider.future);
        final score = await ref.read(confidenceScoreProvider.future);

        final sanitizedData = DataSanitizer.sanitizePortfolio(
          holdings: holdings,
          confidenceScore: score?.strategyAdherence ?? 0.0,
          timeRange: 'All Time',
        );
        final response = await aiProvider.summarize(sanitizedData);
        answer = response.content;
      } else if (actionType == 'reflect') {
        final tradesList = await ref.read(allTradesProvider.future);
        final trades = tradesList.map((t) => t.trade).toList();
        final metrics = await ref.read(behaviorDaoProvider).watchAllMetrics().first;
        final score = await ref.read(confidenceScoreProvider.future);
        
        final sanitizedData = DataSanitizer.sanitizeBehavior(metrics, score, trades);
        final response = await aiProvider.reflect(sanitizedData);
        answer = response.content;
      } else {
        answer = "I'm sorry, I don't know how to do that.";
      }

      if (!mounted) return;
      setState(() {
        _messages.removeAt(0); // Remove typing indicator
        _messages.insert(0, ChatMessage(text: answer, isUser: false));
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeAt(0);
        _messages.insert(0, ChatMessage(text: 'I am currently unable to process that. Please ensure you have data available and Ollama is running. Error: $e', isUser: false));
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text(
          'Assistant',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: DesignTokens.graphiteSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: DesignTokens.obsidianTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Viren is observant, not predictive.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DesignTokens.textMediumContrast,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Suggestions
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ActionChip(
                          label: 'Summarize portfolio',
                          onTap: () => _handleSuggestionTap('Summarize portfolio', 'summarize'),
                          isDisabled: _isTyping,
                        ),
                        _ActionChip(
                          label: 'Reflect on behavior',
                          onTap: () => _handleSuggestionTap('Reflect on behavior', 'reflect'),
                          isDisabled: _isTyping,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Chat Messages 
                    ref.watch(allTradesProvider).when(
                      data: (trades) {
                        final count = trades.length;
                        final greeting = count == 0 
                            ? 'Hello. I am Viren. I observe your trade behavior and conviction. You haven\'t recorded any trades yet. Shall we start?'
                            : 'Hello. I have analyzed your $count recorded trade${count > 1 ? 's' : ''}. I can summarize your activity or discuss your recent conviction levels.';
                        
                        // Update initial message if it's the first time
                        if (_messages.isNotEmpty && _messages.last.text == 'Viren is initializing...') {
                          _messages.last = ChatMessage(text: greeting, isUser: false);
                        }

                        return Column(
                          children: _messages.reversed.toList().asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _ChatBubble(
                                message: entry.value.text,
                                isUser: entry.value.isUser,
                                isTyping: entry.value.isTyping,
                                index: _messages.length - 1 - entry.key, 
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Text('Error linking assistant to Vault.'),
                    ),
                  ]
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(
               indent: 24,
               endIndent: 24,
               color: DesignTokens.graphiteSurface,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Journal Timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          ref.watch(allTradesProvider).when(
            data: (trades) {
              if (trades.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Text('No journal entries yet. Your trade history will appear here.'),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                   (context, index) {
                     final trade = trades[index];
                     final dateStr = '${trade.trade.tradeTimestamp.day}/${trade.trade.tradeTimestamp.month}/${trade.trade.tradeTimestamp.year}';
                     
                     return TweenAnimationBuilder<double>(
                       tween: Tween<double>(begin: 0, end: 1),
                       duration: AnimationPresets.durationNormal + AnimationPresets.staggerItem(index),
                       curve: AnimationPresets.entrance,
                       builder: (context, value, child) {
                         return Opacity(
                           opacity: value.clamp(0.0, 1.0),
                           child: Transform.translate(
                             offset: Offset(0, 20 * (1 - value) * AnimationPresets.parallaxFactor),
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
                                   if (index != trades.length -1) // rudimentary timeline line
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
                                            dateStr,
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
                                               trade.trade.tradeType == db_enums.TradeType.buy ? 'INVESTMENT' : 'EXIT',
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
                                        'You ${trade.trade.tradeType == db_enums.TradeType.buy ? 'bought' : 'sold'} ${trade.trade.quantity} shares of ${trade.trade.instrumentSymbol} at ₹${trade.trade.pricePerUnit.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          height: 1.5,
                                          color: index == 0 ? DesignTokens.textHighContrast : DesignTokens.textMediumContrast,
                                        ),
                                      ),
                                      if (trade.reasonText != null && trade.reasonText!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Reason: ${trade.reasonText}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                        ),
                                      ],
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
                  childCount: trades.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SliverToBoxAdapter(child: Text('Error loading journal')),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      )
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDisabled;

  const _ActionChip({required this.label, required this.onTap, required this.isDisabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: AnimationPresets.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDisabled ? DesignTokens.graphiteBase : DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDisabled ? DesignTokens.graphiteSurface : DesignTokens.borderSubtle),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDisabled ? DesignTokens.textMediumContrast.withValues(alpha: 0.5) : DesignTokens.textMediumContrast,
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isTyping;
  final int index;

  const _ChatBubble({
    required this.message,
    required this.isUser,
    this.isTyping = false,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AnimationPresets.durationFast,
      curve: AnimationPresets.entrance,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(isUser ? 10 * (1 - value) : -10 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUser ? DesignTokens.obsidianTeal.withValues(alpha: 0.1) : DesignTokens.graphiteBase,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 0),
                bottomRight: Radius.circular(isUser ? 0 : 20),
              ),
              border: Border.all(
                color: isUser ? DesignTokens.obsidianTeal.withValues(alpha: 0.3) : DesignTokens.graphiteSurface,
              ),
            ),
            child: isTyping
                ? const SizedBox(
                    width: 40,
                    height: 20,
                    child: Center(
                      child: Text('...', style: TextStyle(color: DesignTokens.obsidianTeal, fontSize: 20, height: 0.5)),
                    ),
                  )
                : Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isUser ? DesignTokens.obsidianTeal : DesignTokens.textHighContrast,
                      height: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
