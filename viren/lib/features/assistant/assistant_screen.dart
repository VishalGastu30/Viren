import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/providers/database_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/ai/model_download_service.dart';
import '../../core/ai/model_setup_screen.dart';
import '../../core/database/app_database.dart';
import 'chat_message.dart';
import 'conversation_repository.dart';
import 'portfolio_context_builder.dart';
import 'assistant_service.dart';
import 'thinking_phrases.dart';
import 'memory_service.dart';
import 'message_renderer.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ConversationRepository(db);
});

final memoryServiceProvider = Provider<MemoryService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MemoryService(db);
});

// Holds the currently active conversation ID. Null = no conversation selected.
class ActiveConversationIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final activeConversationIdProvider =
    NotifierProvider<ActiveConversationIdNotifier, int?>(
        ActiveConversationIdNotifier.new);

// Watches messages for the active conversation reactively.
final activeMessagesProvider = StreamProvider<List<ConversationMessage>>((ref) {
  final convId = ref.watch(activeConversationIdProvider);
  if (convId == null) return Stream.value([]);
  final repo = ref.watch(conversationRepositoryProvider);
  return repo.watchMessages(convId);
});

// Watches all conversations reactively.
final allConversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final repo = ref.watch(conversationRepositoryProvider);
  return repo.watchAllConversations();
});

// ─── AssistantScreen ──────────────────────────────────────────────────────────

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with TickerProviderStateMixin {

  // Model readiness
  bool _isModelReady = false;
  bool _showSlideToUnlock = false;

  // Input / loading
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Portfolio + memory context
  String _portfolioContext = '';
  String _memoryContext = '';

  // Thinking animation
  bool _showThinking = false;
  String _thinkingPhrase = '';
  Timer? _thinkingTimer;
  late AnimationController _shimmerController;

  // Drawer
  late AnimationController _drawerController;
  late Animation<double> _contentScale;

  // Message entrance — tracks newly added message indices
  final Set<int> _animatingIndices = {};

  // Local message list — kept in sync with DB stream + streaming state
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _contentScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _drawerController, curve: Curves.easeOutCubic),
    );

    _checkModelReady();
    _initFirstConversation();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _shimmerController.dispose();
    _drawerController.dispose();
    _thinkingTimer?.cancel();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initFirstConversation() async {
    final repo = ref.read(conversationRepositoryProvider);
    final convs = await repo.getAllConversations();
    if (convs.isNotEmpty) {
      ref.read(activeConversationIdProvider.notifier).set(convs.first.id);
      _syncMessagesFromDb(convs.first.id);
    }
    _loadPortfolioContext();
  }

  Future<void> _syncMessagesFromDb(int convId) async {
    final repo = ref.read(conversationRepositoryProvider);
    final dbMessages = await repo.getMessages(convId);
    if (mounted) {
      setState(() {
        _messages = dbMessages.map((m) => ChatMessage(
          text: m.messageText,
          isUser: m.isUser,
          timestamp: m.timestamp,
        )).toList();
        _animatingIndices.clear();
      });
      _scrollToBottom();
    }
  }

  // ── Model readiness ───────────────────────────────────────────────────────

  Future<void> _checkModelReady() async {
    final ready = await ModelDownloadService.isModelReady();
    if (!mounted) return;
    if (ready) {
      final fileExists = await ModelDownloadService.modelFileExists();
      if (!fileExists) {
        await ModelDownloadService.resetModelReady();
        setState(() { _isModelReady = false; _showSlideToUnlock = false; });
        return;
      }
      setState(() => _isModelReady = true);
    }
  }

  // ── Portfolio + memory context ────────────────────────────────────────────

  Future<void> _loadPortfolioContext() async {
    final db = ref.read(appDatabaseProvider);
    final builder = PortfolioContextBuilder(db);
    final ctx = await builder.build();
    final memoryService = ref.read(memoryServiceProvider);
    final memoryCtx = await memoryService.getMemoryContext();
    if (mounted) {
      setState(() {
        _portfolioContext = ctx;
        _memoryContext = memoryCtx;
      });
    }
  }

  // ── Conversation management ───────────────────────────────────────────────

  Future<void> _selectConversation(Conversation conv) async {
    // Summarise current conversation before switching (fire and forget)
    final currentId = ref.read(activeConversationIdProvider);
    if (currentId != null && currentId != conv.id && _messages.length >= 4) {
      final memoryService = ref.read(memoryServiceProvider);
      memoryService.summariseAndStore(
        conversationId: currentId,
        messages: _messages
            .where((m) => !m.isStreaming)
            .map((m) => {'role': m.isUser ? 'user' : 'viren', 'text': m.text})
            .toList(),
      );
    }

    ref.read(activeConversationIdProvider.notifier).set(conv.id);
    await _syncMessagesFromDb(conv.id);
    _closeDrawer();
  }

  Future<void> _newConversation() async {
    // Summarise outgoing conversation
    final currentId = ref.read(activeConversationIdProvider);
    if (currentId != null && _messages.length >= 4) {
      final memoryService = ref.read(memoryServiceProvider);
      memoryService.summariseAndStore(
        conversationId: currentId,
        messages: _messages
            .where((m) => !m.isStreaming)
            .map((m) => {'role': m.isUser ? 'user' : 'viren', 'text': m.text})
            .toList(),
      );
    }

    final repo = ref.read(conversationRepositoryProvider);
    final conv = await repo.createConversation();
    ref.read(activeConversationIdProvider.notifier).set(conv.id);
    if (mounted) {
      setState(() {
        _messages = [];
        _animatingIndices.clear();
      });
    }
    _closeDrawer();
  }

  Future<void> _deleteConversation(Conversation conv) async {
    final repo = ref.read(conversationRepositoryProvider);
    await repo.deleteConversation(conv.id);

    final currentId = ref.read(activeConversationIdProvider);
    if (currentId == conv.id) {
      final remaining = await repo.getAllConversations();
      if (remaining.isNotEmpty) {
        ref.read(activeConversationIdProvider.notifier).set(remaining.first.id);
        await _syncMessagesFromDb(remaining.first.id);
      } else {
        ref.read(activeConversationIdProvider.notifier).set(null);
        if (mounted) setState(() => _messages = []);
      }
    }
  }

  Future<void> _renameConversation(Conversation conv) async {
    final controller = TextEditingController(text: conv.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignTokens.graphiteSurface,
        title: Text('Rename', style: TextStyle(color: DesignTokens.textHighContrast)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: DesignTokens.textHighContrast),
          decoration: InputDecoration(
            hintText: 'Conversation name',
            hintStyle: TextStyle(color: DesignTokens.textMediumContrast),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: DesignTokens.obsidianTeal),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: DesignTokens.obsidianTeal, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: DesignTokens.textMediumContrast)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save', style: TextStyle(color: DesignTokens.obsidianTeal)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.setTitle(conv.id, result);
    }
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading || !_isModelReady) return;

    final repo = ref.read(conversationRepositoryProvider);

    // Create conversation if none active
    int convId;
    final currentId = ref.read(activeConversationIdProvider);
    if (currentId == null) {
      final conv = await repo.createConversation();
      ref.read(activeConversationIdProvider.notifier).set(conv.id);
      convId = conv.id;
    } else {
      convId = currentId;
    }

    // Auto-title on first message
    if (_messages.isEmpty) {
      await repo.autoTitle(convId, text.trim());
    }

    await repo.addMessage(conversationId: convId, text: text.trim(), isUser: true);

    final userMsg = ChatMessage(text: text.trim(), isUser: true, timestamp: DateTime.now());
    final placeholderMsg = ChatMessage(text: '', isUser: false, timestamp: DateTime.now(), isStreaming: true);

    final userIndex = _messages.length;
    final placeholderIndex = userIndex + 1;

    setState(() {
      _messages.add(userMsg);
      _messages.add(placeholderMsg);
      _animatingIndices.add(userIndex);
      _animatingIndices.add(placeholderIndex);
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    // Thinking animation — only shows after 400ms
    _thinkingPhrase = ThinkingPhrases.forMessage(text.trim());
    _thinkingTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _isLoading) {
        setState(() => _showThinking = true);
        _shimmerController.repeat();
      }
    });

    try {
      final service = AssistantService();
      final response = await service.sendMessage(
        userMessage: text.trim(),
        portfolioContext: _portfolioContext,
        history: _messages.where((m) => !m.isStreaming).toList(),
        memoryContext: _memoryContext,
      );

      _thinkingTimer?.cancel();
      if (mounted) {
        setState(() => _showThinking = false);
        _shimmerController.stop();
        _shimmerController.reset();
      }

      await repo.addMessage(conversationId: convId, text: response, isUser: false);

      // Word-by-word streaming simulation
      final words = response.split(' ');
      String accumulated = '';
      for (final word in words) {
        await Future.delayed(const Duration(milliseconds: 35));
        accumulated += (accumulated.isEmpty ? '' : ' ') + word;
        if (mounted) {
          setState(() {
            _messages[placeholderIndex] =
                placeholderMsg.copyWith(text: accumulated, isStreaming: true);
          });
          _scrollToBottom();
        }
      }

      if (mounted) {
        setState(() {
          _messages[placeholderIndex] =
              placeholderMsg.copyWith(text: response, isStreaming: false);
          _isLoading = false;
        });
      }
    } catch (e) {
      _thinkingTimer?.cancel();
      if (mounted) {
        const errText = 'Something went wrong. Please try again.';
        setState(() {
          _showThinking = false;
          _shimmerController.stop();
          _shimmerController.reset();
          _messages[placeholderIndex] =
              placeholderMsg.copyWith(text: errText, isStreaming: false);
          _isLoading = false;
        });
        await repo.addMessage(conversationId: convId, text: errText, isUser: false, isError: true);
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

  // ── Drawer ────────────────────────────────────────────────────────────────

  void _openDrawer() {
    _drawerController.forward();
  }

  void _closeDrawer() {
    _drawerController.reverse();
  }

  bool get _drawerOpen => _drawerController.value > 0.01;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainUI(),
        if (!_isModelReady && !_showSlideToUnlock) _buildSetupOverlay(),
        if (_showSlideToUnlock) _buildSlideToUnlock(),
      ],
    );
  }

  Widget _buildMainUI() {
    return AnimatedBuilder(
      animation: _drawerController,
      builder: (context, child) {
        return Stack(
          children: [
            // Main content — scales and shifts right as drawer opens
            Transform(
              transform: Matrix4.identity()
                ..setTranslationRaw(_drawerController.value * 260.0, 0.0, 0.0)
                ..scale(_contentScale.value),
              alignment: Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_drawerController.value * 20),
                child: GestureDetector(
                  onTap: _drawerOpen ? _closeDrawer : null,
                  child: AbsorbPointer(
                    absorbing: _drawerOpen,
                    child: _buildChatScreen(),
                  ),
                ),
              ),
            ),

            // Dim overlay
            if (_drawerController.value > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDrawer,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45 * _drawerController.value),
                  ),
                ),
              ),

            // Drawer panel
            Transform.translate(
              offset: Offset(-280 * (1 - _drawerController.value), 0),
              child: _buildDrawer(),
            ),
          ],
        );
      },
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    final activeId = ref.watch(activeConversationIdProvider);
    final convsAsync = ref.watch(allConversationsProvider);

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 280,
        height: double.infinity,
        child: Material(
          color: const Color(0xFF0D0D0D),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 16, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VIREN',
                              style: TextStyle(
                                color: DesignTokens.obsidianTeal,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              )),
                          const SizedBox(height: 2),
                          Text('Assistant',
                              style: TextStyle(
                                color: DesignTokens.textMediumContrast,
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                              )),
                        ],
                      ),
                      const Spacer(),
                      // New chat button
                      GestureDetector(
                        onTap: _newConversation,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: DesignTokens.obsidianTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(Icons.edit_outlined,
                              color: DesignTokens.obsidianTeal, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Section label ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('RECENTS',
                      style: TextStyle(
                        color: DesignTokens.textMediumContrast.withValues(alpha: 0.4),
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      )),
                ),

                // ── Conversation list ──
                Expanded(
                  child: convsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 1),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (convs) {
                      if (convs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  color: DesignTokens.textMediumContrast
                                      .withValues(alpha: 0.2),
                                  size: 32),
                              const SizedBox(height: 12),
                              Text('No conversations yet',
                                  style: TextStyle(
                                    color: DesignTokens.textMediumContrast
                                        .withValues(alpha: 0.4),
                                    fontSize: 12,
                                  )),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: convs.length,
                        itemBuilder: (context, i) {
                          final conv = convs[i];
                          final isActive = conv.id == activeId;
                          return _ConversationTile(
                            conversation: conv,
                            isActive: isActive,
                            onTap: () => _selectConversation(conv),
                            onDelete: () => _deleteConversation(conv),
                            onRename: () => _renameConversation(conv),
                          );
                        },
                      );
                    },
                  ),
                ),

                // ── Footer ──
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: DesignTokens.obsidianTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Private. Local. Yours.',
                          style: TextStyle(
                            color: DesignTokens.textMediumContrast
                                .withValues(alpha: 0.35),
                            fontSize: 10,
                            letterSpacing: 1.2,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Chat screen ───────────────────────────────────────────────────────────

  Widget _buildChatScreen() {
    final activeId = ref.watch(activeConversationIdProvider);
    final convsAsync = ref.watch(allConversationsProvider);
    final activeTitle = convsAsync.whenOrNull(
      data: (convs) => convs
          .where((c) => c.id == activeId)
          .map((c) => c.title)
          .firstOrNull,
    );

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        leading: IconButton(
          icon: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _drawerController,
            color: DesignTokens.textMediumContrast,
            size: 22,
          ),
          onPressed: _drawerOpen ? _closeDrawer : _openDrawer,
        ),
        title: GestureDetector(
          onTap: () async {
            final convsData = ref.read(allConversationsProvider).value;
            final active = convsData?.where((c) => c.id == activeId).firstOrNull;
            if (active != null) await _renameConversation(active);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeTitle ?? 'Viren',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: DesignTokens.textHighContrast,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('tap to rename',
                  style: TextStyle(
                    color: DesignTokens.textMediumContrast.withValues(alpha: 0.4),
                    fontSize: 9,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: DesignTokens.textMediumContrast, size: 20),
              onPressed: () async {
                final convsData = ref.read(allConversationsProvider).value;
                final active = convsData?.where((c) => c.id == activeId).firstOrNull;
                if (active != null) await _deleteConversation(active);
              },
            ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined,
                color: DesignTokens.textMediumContrast, size: 20),
            onPressed: _newConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          if (_showThinking) _buildThinkingIndicator(),
          if (_messages.isEmpty) _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _ShimmerThinkingWidget(
          phrase: _thinkingPhrase,
          controller: _shimmerController,
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isNew = _animatingIndices.contains(index);
        return _AnimatedChatBubble(
          key: ValueKey('msg_${index}_${msg.text.length}'),
          message: msg,
          animate: isNew,
          shimmerController: _shimmerController,
          onAnimationComplete: () => _animatingIndices.remove(index),
        );
      },
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
                border: Border.all(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: DesignTokens.obsidianTeal, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Ask me anything about\nyour portfolio.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w300,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Everything stays on your device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignTokens.textMediumContrast,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      "Which holding is performing best?",
      "What's my total return so far?",
      "How much have I paid in charges?",
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: suggestions.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _sendMessage(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: DesignTokens.graphiteSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DesignTokens.textHighContrast,
                        )),
                  ),
                  Icon(Icons.north_east_rounded,
                      size: 14, color: DesignTokens.obsidianTeal),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: DesignTokens.graphiteBase,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _inputController,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 5,
                minLines: 1,
                enabled: _isModelReady,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _isModelReady
                      ? 'Ask Viren anything...'
                      : 'Setting up Viren...',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DesignTokens.textMediumContrast.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (v) => _sendMessage(v),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isModelReady && !_isLoading
                ? () => _sendMessage(_inputController.text)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (!_isModelReady || _isLoading)
                    ? DesignTokens.obsidianTeal.withValues(alpha: 0.3)
                    : DesignTokens.obsidianTeal,
                shape: BoxShape.circle,
                boxShadow: _isModelReady && !_isLoading
                    ? [
                        BoxShadow(
                          color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
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

  // ── Setup overlay + slide to unlock ───────────────────────────────────────

  Widget _buildSetupOverlay() {
    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: Material(
          color: DesignTokens.graphiteBase,
          child: ModelSetupScreen(
            onComplete: () {
              if (mounted) setState(() => _showSlideToUnlock = true);
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
                child: const Icon(Icons.bolt_rounded,
                    color: DesignTokens.obsidianTeal, size: 36),
              ),
              const SizedBox(height: 28),
              Text('Viren is ready',
                  style: TextStyle(
                    color: DesignTokens.textHighContrast,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 8),
              Text('Your portfolio context is loaded',
                  style: TextStyle(
                      color: DesignTokens.textMediumContrast, fontSize: 14)),
              const SizedBox(height: 64),
              _SlideToUnlockBar(
                onUnlocked: () async {
                  if (mounted) {
                    await ModelDownloadService.markModelReady();
                    if (mounted) {
                      setState(() {
                        _showSlideToUnlock = false;
                        _isModelReady = true;
                      });
                      _loadPortfolioContext();
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('slide to begin',
                  style: TextStyle(
                    color: DesignTokens.textMediumContrast.withValues(alpha: 0.4),
                    fontSize: 11,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Thinking Widget ──────────────────────────────────────────────────

class _ShimmerThinkingWidget extends StatelessWidget {
  final String phrase;
  final AnimationController controller;

  const _ShimmerThinkingWidget({
    required this.phrase,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                DesignTokens.obsidianTeal,
                Color(0xFFB2F5EF),
                DesignTokens.obsidianTeal,
              ],
              stops: [
                (controller.value - 0.3).clamp(0.0, 1.0),
                controller.value.clamp(0.0, 1.0),
                (controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                phrase,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              _PulsingDots(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _PulsingDots extends StatelessWidget {
  final AnimationController controller;
  const _PulsingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final phase = ((controller.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─── Animated Chat Bubble ─────────────────────────────────────────────────────

class _AnimatedChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool animate;
  final AnimationController shimmerController;
  final VoidCallback onAnimationComplete;

  const _AnimatedChatBubble({
    super.key,
    required this.message,
    required this.animate,
    required this.shimmerController,
    required this.onAnimationComplete,
  });

  @override
  State<_AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<_AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _showTimestamp = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.animate) {
      _controller.forward().then((_) => widget.onAnimationComplete());
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onLongPress: () {
              HapticFeedback.lightImpact();
              setState(() => _showTimestamp = !_showTimestamp);
            },
            child: Column(
              crossAxisAlignment: widget.message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: widget.message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.80,
                    ),
                    child: widget.message.isUser
                        ? _UserBubble(text: widget.message.text)
                        : _VirenBubble(
                            message: widget.message,
                            shimmerController: widget.shimmerController,
                          ),
                  ),
                ),
                if (_showTimestamp)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: AnimatedOpacity(
                      opacity: _showTimestamp ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _formatTimestamp(widget.message.timestamp),
                        style: TextStyle(
                          color: DesignTokens.textMediumContrast
                              .withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── User Bubble ──────────────────────────────────────────────────────────────

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

// ─── Viren Bubble ─────────────────────────────────────────────────────────────

class _VirenBubble extends StatelessWidget {
  final ChatMessage message;
  final AnimationController shimmerController;
  const _VirenBubble({required this.message, required this.shimmerController});

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
        AnimatedBuilder(
          animation: shimmerController,
          builder: (context, child) {
            // Pulse the left border while streaming
            final borderOpacity = message.isStreaming
                ? (0.4 + shimmerController.value * 0.6)
                : 1.0;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: DesignTokens.graphiteSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  left: BorderSide(
                    color: DesignTokens.obsidianTeal
                        .withValues(alpha: borderOpacity * 0.6),
                    width: 2,
                  ),
                ),
              ),
              child: message.isStreaming && message.text.isEmpty
                  ? const _TypingIndicator()
                  : MessageRenderer(
                      text: message.text,
                      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DesignTokens.textHighContrast,
                            height: 1.6,
                          ),
                    ),
            );
          },
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
    for (final c in _controllers) { c.dispose(); }
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

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('conv_${conversation.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: DesignTokens.crimsonWarning.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded,
            color: DesignTokens.crimsonWarning, size: 20),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: DesignTokens.graphiteSurface,
            title: Text('Delete conversation?',
                style: TextStyle(color: DesignTokens.textHighContrast, fontSize: 16)),
            content: Text('This cannot be undone.',
                style: TextStyle(color: DesignTokens.textMediumContrast)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TextStyle(color: DesignTokens.textMediumContrast)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: TextStyle(color: DesignTokens.crimsonWarning)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onLongPress: onRename,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? DesignTokens.obsidianTeal.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border(
                    left: BorderSide(
                        color: DesignTokens.obsidianTeal, width: 2))
                : null,
          ),
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            onTap: onTap,
            title: Text(
              conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive
                    ? DesignTokens.textHighContrast
                    : DesignTokens.textMediumContrast,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              _relativeTime(conversation.updatedAt),
              style: TextStyle(
                color: DesignTokens.textMediumContrast.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
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
          Center(
            child: Opacity(
              opacity: (1 - progress * 2).clamp(0.0, 1.0),
              child: const Text('›  ›  ›',
                  style: TextStyle(
                      color: DesignTokens.obsidianTeal,
                      fontSize: 18,
                      letterSpacing: 6)),
            ),
          ),
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
                      const Duration(milliseconds: 300), widget.onUnlocked);
                }
              },
              onHorizontalDragEnd: (_) {
                if (!_unlocked) setState(() => _dragPosition = 0);
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
                child: const Icon(Icons.chevron_right_rounded,
                    color: Colors.black, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}