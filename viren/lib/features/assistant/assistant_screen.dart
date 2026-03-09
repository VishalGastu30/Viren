import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/providers/database_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/ai/model_download_service.dart';
import '../../core/ai/model_setup_screen.dart';
import 'chat_message.dart';
import 'portfolio_context_builder.dart';
import 'assistant_service.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showSuggestions = true;
  String _portfolioContext = '';
  bool _isModelReady = false;
  bool _showSlideToUnlock = false;

  @override
  void initState() {
    super.initState();
    _checkModelReady();
  }

  Future<void> _checkModelReady() async {
    final ready = await ModelDownloadService.isModelReady();
    if (mounted) {
      if (ready) {
        // FIX #5: on re-launch the model is already marked ready.
        // Skip the download overlay but still verify the file exists on disk
        // before trusting SharedPreferences. If the file was deleted, reset.
        final fileExists = await ModelDownloadService.modelFileExists();
        if (!fileExists) {
          // Model file was deleted after the flag was set — reset the flag
          // so the user is sent back through the download flow.
          await ModelDownloadService.resetModelReady();
          setState(() {
            _isModelReady = false;
            _showSlideToUnlock = false;
          });
          return;
        }
        // File confirmed present — go straight to chat, no slide-to-unlock
        // on re-launch (intentional: slide-to-unlock is a first-launch ceremony).
        setState(() => _isModelReady = true);
        _loadPortfolioContext();
      }
      // If not ready, _isModelReady stays false → setup overlay is shown.
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // FIX #6: _loadPortfolioContext is only called from two controlled places:
  //   1. _checkModelReady (re-launch path)
  //   2. onUnlocked callback (first-launch path after slide)
  // No risk of double-call as these two paths are mutually exclusive.
  Future<void> _loadPortfolioContext() async {
    final db = ref.read(appDatabaseProvider);
    final builder = PortfolioContextBuilder(db);
    final context = await builder.build();
    if (mounted) {
      setState(() => _portfolioContext = context);
    }
  }

  Future<void> _sendMessage(String text) async {
    // FIX #7: guard against sending when model isn't ready or already loading
    if (text.trim().isEmpty || _isLoading || !_isModelReady) return;

    final userMsg = ChatMessage(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    final virenPlaceholder = ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(virenPlaceholder);
      _isLoading = true;
      _showSuggestions = false;
      _inputController.clear();
    });

    _scrollToBottom();

    try {
      final service = AssistantService();
      final response = await service.sendMessage(
        userMessage: text.trim(),
        portfolioContext: _portfolioContext,
        history: _messages.where((m) => !m.isStreaming).toList(),
      );

      // Simulate word-by-word streaming
      final words = response.split(' ');
      String accumulated = '';

      for (final word in words) {
        await Future.delayed(const Duration(milliseconds: 40));
        accumulated += (accumulated.isEmpty ? '' : ' ') + word;
        if (mounted) {
          setState(() {
            _messages[_messages.length - 1] =
                virenPlaceholder.copyWith(text: accumulated, isStreaming: true);
          });
          _scrollToBottom();
        }
      }

      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] =
              virenPlaceholder.copyWith(text: response, isStreaming: false);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ASSISTANT ERROR: $e');
      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] = virenPlaceholder.copyWith(
            text: 'Something interrupted the response. Please try again.',
            isStreaming: false,
          );
          _isLoading = false;
        });
      }
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1 — always present: the real chat UI
        _buildChatScreen(),

        // Layer 2 — setup overlay: only shown when model not ready
        if (!_isModelReady && !_showSlideToUnlock)
          _buildSetupOverlay(),

        // Layer 3 — slide to unlock: shown after setup completes
        if (_showSlideToUnlock)
          _buildSlideToUnlock(),
      ],
    );
  }

  Widget _buildSetupOverlay() {
    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: Material(
          color: DesignTokens.graphiteBase,
          child: ModelSetupScreen(
            onComplete: () {
              if (mounted) {
                setState(() {
                  _showSlideToUnlock = true;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSlideToUnlock() {
    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: Material(
          color: DesignTokens.graphiteBase,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: DesignTokens.obsidianTeal,
                  size: 36,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Viren is ready',
                style: TextStyle(
                  color: DesignTokens.textHighContrast,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your portfolio context is loaded',
                style: TextStyle(
                  color: DesignTokens.textMediumContrast,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 64),
              _SlideToUnlockBar(
                onUnlocked: () async {
                  if (mounted) {
                    // FIX #3 (coordinated with model_setup_screen fix):
                    // markModelReady() is called HERE — after the user confirms
                    // via slide — not inside ModelSetupScreen before onComplete.
                    // This is the single authoritative place it is written.
                    await ModelDownloadService.markModelReady();
                    if (mounted) {
                      setState(() {
                        _showSlideToUnlock = false;
                        _isModelReady = true;
                      });
                      // FIX #6: only one call site for _loadPortfolioContext
                      // on first launch (re-launch calls it from _checkModelReady)
                      _loadPortfolioContext();
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'slide to begin',
                style: TextStyle(
                  color: DesignTokens.textMediumContrast.withValues(alpha: 0.4),
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatScreen() {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          if (_showSuggestions && _messages.isEmpty) _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: DesignTokens.graphiteBase,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viren', style: Theme.of(context).textTheme.titleLarge),
          Text('Private. Local. Yours.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    fontSize: 11,
                  )),
        ],
      ),
      actions: [
        if (_messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: DesignTokens.textMediumContrast, size: 20),
            onPressed: () => setState(() {
              _messages.clear();
              _showSuggestions = true;
            }),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: DesignTokens.obsidianTeal, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Ask me anything about your portfolio.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'I know your holdings, trades, costs, and patterns.\nEverything stays on your device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _buildDynamicSuggestions();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: suggestions
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _sendMessage(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: DesignTokens.graphiteSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: DesignTokens.obsidianTeal
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(s,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: DesignTokens.textHighContrast,
                                    )),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 12, color: DesignTokens.obsidianTeal),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  List<String> _buildDynamicSuggestions() {
    final suggestions = <String>[];
    if (_portfolioContext.contains('Holdings:') &&
        _portfolioContext.contains('units')) {
      suggestions.add("What's my total return so far?");
      suggestions.add('Which holding is performing best?');
      suggestions.add('How much have I paid in charges?');
    } else {
      suggestions.add('How do I get started?');
      suggestions.add('What can you tell me?');
      suggestions.add('Summarize my portfolio.');
    }
    return suggestions.take(3).toList();
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _ChatBubble(message: msg);
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: DesignTokens.graphiteBase,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _inputController,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                // FIX #7: input bar is disabled until model is ready
                enabled: _isModelReady,
                decoration: InputDecoration(
                  hintText: _isModelReady
                      ? 'Ask Viren anything...'
                      : 'Setting up Viren...',
                  hintStyle:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DesignTokens.textMediumContrast
                                .withValues(alpha: 0.5),
                          ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (v) => _sendMessage(v),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            // FIX #7: send button also gated on _isModelReady
            onTap: _isModelReady
                ? () => _sendMessage(_inputController.text)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (!_isModelReady || _isLoading)
                    ? DesignTokens.obsidianTeal.withValues(alpha: 0.4)
                    : DesignTokens.obsidianTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.arrow_upward_rounded,
                color: DesignTokens.graphiteBase,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.80,
          ),
          child: message.isUser
              ? _UserBubble(text: message.text)
              : _VirenBubble(message: message),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: DesignTokens.obsidianTeal.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DesignTokens.textHighContrast,
              )),
    );
  }
}

class _VirenBubble extends StatelessWidget {
  final ChatMessage message;
  const _VirenBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('VIREN',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.obsidianTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  )),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: DesignTokens.graphiteSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: const Border(
              left: BorderSide(color: Color(0x664ECDC4), width: 2),
            ),
          ),
          child: message.isStreaming && message.text.isEmpty
              ? const _TypingIndicator()
              : Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DesignTokens.textHighContrast,
                        height: 1.6,
                      ),
                ),
        ),
      ],
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
        3,
        (i) => AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 600),
            ));
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0.3, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          3,
          (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FadeTransition(
                  opacity: _anims[i],
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: DesignTokens.obsidianTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )),
    );
  }
}

// ─── Slide To Unlock ──────────────────────────────────────────────────────────

class _SlideToUnlockBar extends StatefulWidget {
  final VoidCallback onUnlocked;
  const _SlideToUnlockBar({required this.onUnlocked});

  @override
  State<_SlideToUnlockBar> createState() => _SlideToUnlockBarState();
}

class _SlideToUnlockBarState extends State<_SlideToUnlockBar> {
  double _dragPosition = 0;
  final double _trackWidth = 280;
  final double _thumbSize = 56;
  bool _unlocked = false;

  double get _maxDrag => _trackWidth - _thumbSize;

  @override
  Widget build(BuildContext context) {
    final progress = (_dragPosition / _maxDrag).clamp(0.0, 1.0);

    return Container(
      width: _trackWidth,
      height: _thumbSize,
      decoration: BoxDecoration(
        color: DesignTokens.obsidianTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        children: [
          // Fill track as user slides
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: _thumbSize + _dragPosition,
                  decoration: BoxDecoration(
                    color: DesignTokens.obsidianTeal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ),
          // Label fades as thumb moves right
          Center(
            child: Opacity(
              opacity: (1 - progress * 2).clamp(0.0, 1.0),
              child: const Text(
                '›  ›  ›',
                style: TextStyle(
                  color: DesignTokens.obsidianTeal,
                  fontSize: 18,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
          // Draggable thumb
          Positioned(
            left: _dragPosition,
            top: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (_unlocked) return;
                setState(() {
                  _dragPosition = (_dragPosition + details.delta.dx)
                      .clamp(0.0, _maxDrag);
                });
                if (_dragPosition >= _maxDrag) {
                  setState(() => _unlocked = true);
                  Future.delayed(
                    const Duration(milliseconds: 300),
                    widget.onUnlocked,
                  );
                }
              },
              onHorizontalDragEnd: (_) {
                if (!_unlocked) {
                  setState(() => _dragPosition = 0);
                }
              },
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: DesignTokens.obsidianTeal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DesignTokens.obsidianTeal.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}