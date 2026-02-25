import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../mock_data/alerts_mock.dart';
import '../../core/animations/animation_presets.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isTyping;

  ChatMessage({required this.text, required this.isUser, this.isTyping = false});
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello, Viren. I observed 3 trades in January and a slight drift in your conviction tagging. I can summarise the month, review your behavior, or answer questions about your holdings.',
      isUser: false,
    ),
  ];

  bool _isTyping = false;

  void _handleSuggestionTap(String question) async {
    if (_isTyping) return;

    final answer = AlertsMock.assistantQA[question];
    if (answer == null) return;

    setState(() {
      _messages.insert(0, ChatMessage(text: question, isUser: true));
      _isTyping = true;
    });

    // Simulated network/processing delay
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _messages.insert(0, ChatMessage(text: '...', isUser: false, isTyping: true));
    });

    // Simulated typing delay proportional to message length
    final typingDuration = Duration(milliseconds: 400 + (answer.length * 15));
    await Future.delayed(typingDuration);

    if (!mounted) return;
    setState(() {
      _messages.removeAt(0); // Remove typing indicator
      _messages.insert(0, ChatMessage(text: answer, isUser: false));
      _isTyping = false;
    });
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
                      children: AlertsMock.assistantQA.keys.map((q) => _ActionChip(
                        label: q,
                        onTap: () => _handleSuggestionTap(q),
                        isDisabled: _isTyping,
                      )).toList(),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Chat Messages 
                    ..._messages.reversed.toList().asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _ChatBubble(
                          message: entry.value.text,
                          isUser: entry.value.isUser,
                          isTyping: entry.value.isTyping,
                          index: _messages.length - 1 - entry.key, 
                        ),
                      );
                    }),
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
               (context, index) {
                 final entry = AlertsMock.journal[index];
                 // Stagger logic
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
