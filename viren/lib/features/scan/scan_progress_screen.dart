import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../core/auth/auth_service.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/ingestion/email/scan_orchestrator.dart';
import '../holdings/holdings_list_screen.dart';

class ScanProgressScreen extends ConsumerStatefulWidget {
  const ScanProgressScreen({super.key});

  @override
  ConsumerState<ScanProgressScreen> createState() => _ScanProgressScreenState();
}

class _ScanProgressScreenState extends ConsumerState<ScanProgressScreen>
    with TickerProviderStateMixin {
  ScanOrchestrator? _orchestrator;
  StreamSubscription<ScanEvent>? _subscription;

  // State
  final Map<ScanStage, StageStatus> _stageStatuses = {};
  final Map<ScanStage, double> _stageProgress = {};
  ScanCounters _counters = const ScanCounters();
  String _currentActionText = 'Initializing scan…';
  int _elapsedMs = 0;
  int _estimatedRemainingMs = 0;
  double _overallProgress = 0.0;
  bool _isAuthorizing = true; // Phase A: OAuth gate
  bool _isPanRequired = false;
  bool _isComplete = false;
  bool _hasError = false;
  String _completionMessage = '';
  String _errorMessage = '';
  List<DebugPdfInfo> _debugPayloads = [];
  bool _showDebugPanel = false;
  int? _expandedDebugIndex;

  // PAN input
  final _panController = TextEditingController();
  bool _panObscured = true;

  // Watchdog timer
  Timer? _watchdog;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize all stages to waiting
    for (final stage in ScanStage.values) {
      _stageStatuses[stage] = StageStatus.waiting;
      _stageProgress[stage] = 0.0;
    }

    // Pulse animation for active stage
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: AnimationPresets.durationNormal,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: AnimationPresets.entrance));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: AnimationPresets.entrance),
    );

    _entranceController.forward();

    // Start scan after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _orchestrator?.dispose();
    _watchdog?.cancel();
    _pulseController.dispose();
    _entranceController.dispose();
    _panController.dispose();
    super.dispose();
  }

  // ── PHASE A: OAuth Gate ──────────────────────────────────────────────────
  // Authenticate BEFORE creating the orchestrator. OAuth is a prerequisite,
  // not a scan stage. If OAuth requires interactive consent (browser/sheet),
  // it happens here while the UI shows "Authorizing…".

  Future<void> _startScan() async {
    setState(() {
      _isAuthorizing = true;
      _currentActionText = 'Connecting to Gmail…';
    });
    _pulseController.repeat(reverse: true);

    try {
      // Phase A: Acquire authorization BEFORE any scan work
      final authService = await AuthService.create(scopes: [
        'https://www.googleapis.com/auth/gmail.readonly'
      ]);

      // This call may trigger interactive OAuth (Google sign-in sheet)
      // The app may go to background and resume. This is expected.
      await authService.authenticate();

      if (!mounted) return;

      // Phase A complete — OAuth gate passed
      setState(() {
        _isAuthorizing = false;
        _currentActionText = 'Authorization complete. Starting scan…';
      });

      // Phase B: Start scan orchestration with pre-authenticated service
      _startOrchestrator(authService);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthorizing = false;
        _hasError = true;
        _errorMessage = 'Gmail authorization failed: $e';
        _currentActionText = 'Authorization failed.';
        _pulseController.stop();
      });
    }
  }

  // ── PHASE B: Scan Orchestration ─────────────────────────────────────────

  void _startOrchestrator(AuthService authService) {
    final tradeRepo = ref.read(tradeRepositoryProvider);
    final importDao = ref.read(importDaoProvider);

    _orchestrator = ScanOrchestrator(
      tradeRepository: tradeRepo,
      importDao: importDao,
    );

    _subscription = _orchestrator!.events.listen(_handleEvent);
    _resetWatchdog();

    // Fire and forget — orchestrator emits events on its stream
    _orchestrator!.run(authService: authService);
  }

  // ── Watchdog Timer ──────────────────────────────────────────────────────
  // If no progress events arrive within 8 seconds, show a heartbeat message
  // so the UI never appears frozen.

  void _resetWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 8), () {
      if (mounted && !_isComplete && !_hasError) {
        setState(() {
          _currentActionText = 'Still working… processing a large document.';
        });
        _resetWatchdog(); // Restart for the next interval
      }
    });
  }

  void _handleEvent(ScanEvent event) {
    if (!mounted) return;
    _resetWatchdog(); // Reset watchdog on every event

    setState(() {
      _counters = event.counters;
      _elapsedMs = event.elapsedMs;
      _estimatedRemainingMs = event.estimatedRemainingMs;
      if (event.actionText != null) _currentActionText = event.actionText!;

      if (event is ScanPanRequiredEvent) {
        _isPanRequired = true;
        _stageStatuses[ScanStage.pdfDecryption] = StageStatus.waiting;
        _currentActionText = 'PAN required to decrypt ${event.pdfsFound} PDF attachments.';
      } else if (event is ScanCompleteEvent) {
        _isComplete = true;
        _completionMessage = event.summaryMessage;
        _debugPayloads = event.debugPayloads;
        _overallProgress = 1.0;
        _pulseController.stop();
        for (final stage in ScanStage.values) {
          if (_stageStatuses[stage] == StageStatus.waiting) {
            _stageStatuses[stage] = StageStatus.skipped;
          }
        }
        _stageStatuses[ScanStage.finalization] = StageStatus.completed;
      } else if (event is ScanErrorEvent) {
        _hasError = true;
        _errorMessage = event.errorMessage;
        _stageStatuses[event.stage] = StageStatus.failed;
        _pulseController.stop();
      } else {
        _stageStatuses[event.stage] = event.status;
        _stageProgress[event.stage] = event.progress;

        // Calculate overall progress
        int completedStages = _stageStatuses.values
            .where((s) => s == StageStatus.completed || s == StageStatus.skipped)
            .length;
        _overallProgress = completedStages / ScanStage.values.length;
      }
    });
  }

  void _submitPan() {
    final pan = _panController.text.trim().toUpperCase();
    if (pan.length != 10) return;

    // Save PAN to secure storage for future background scans
    const secureStorage = FlutterSecureStorage();
    secureStorage.write(key: 'user_pan', value: pan);

    setState(() => _isPanRequired = false);
    _orchestrator?.submitPan(pan);
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '—';
    final seconds = (ms / 1000).round();
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── HEADER ──
                SliverToBoxAdapter(child: _buildHeader()),

                // ── AUTH GATE (Phase A) ──
                if (_isAuthorizing)
                  SliverToBoxAdapter(child: _buildAuthGate()),

                // ── PAN INPUT (conditional) ──
                if (_isPanRequired)
                  SliverToBoxAdapter(child: _buildPanInput()),

                // ── STAGE TIMELINE ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Pipeline Stages',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: DesignTokens.textMediumContrast,
                              letterSpacing: 1.2,
                            )),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildStageCard(ScanStage.values[index]),
                    childCount: ScanStage.values.length,
                  ),
                ),

                // ── LIVE COUNTERS ──
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildLiveCounters()),

                // ── CURRENT ACTION TEXT ──
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildActionText()),

                // ── COMPLETION / ERROR ──
                if (_isComplete) SliverToBoxAdapter(child: _buildCompletionCard()),
                if (_hasError) SliverToBoxAdapter(child: _buildErrorCard()),

                // ── DEBUG PANEL (after completion) ──
                if (_isComplete && _debugPayloads.isNotEmpty)
                  SliverToBoxAdapter(child: _buildDebugToggle()),
                if (_isComplete && _showDebugPanel)
                  SliverToBoxAdapter(child: _buildDebugPanel()),

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_isComplete || _hasError) {
                    Navigator.of(context).pop();
                  }
                },
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: (_isComplete || _hasError)
                      ? DesignTokens.textHighContrast
                      : DesignTokens.textMediumContrast.withValues(alpha: 0.3),
                  size: 20,
                ),
              ),
              const Spacer(),
              // Overall ETA
              if (!_isComplete && !_hasError)
                Text(
                  _estimatedRemainingMs > 0
                      ? '~${_formatDuration(_estimatedRemainingMs)} remaining'
                      : 'Estimating…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _isComplete
                ? 'Scan Complete'
                : _hasError
                    ? 'Scan Interrupted'
                    : _isAuthorizing
                        ? 'Connecting to Gmail'
                        : 'Scanning Your Portfolio',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: DesignTokens.textHighContrast,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _isComplete
                ? 'Truth reconstructed from chaos.'
                : _hasError
                    ? 'Something went wrong.'
                    : _isAuthorizing
                        ? 'Requesting Gmail authorization…'
                        : 'Reconstructing truth from chaos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
          const SizedBox(height: 20),
          // Overall progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: AnimationPresets.durationNormal,
                    curve: Curves.easeInOut,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: _overallProgress,
                      backgroundColor: DesignTokens.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _hasError ? DesignTokens.crimsonWarning : DesignTokens.obsidianTeal,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(_overallProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: DesignTokens.obsidianTeal,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Elapsed: ${_formatDuration(_elapsedMs)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthGate() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.obsidianTeal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.obsidianTeal),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Authorizing Gmail Access',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DesignTokens.textHighContrast,
                          fontWeight: FontWeight.w600,
                        )),
                const SizedBox(height: 4),
                Text(
                  'If prompted, please grant read-only Gmail access. This is required to discover broker emails.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanInput() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.obsidianTeal.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: DesignTokens.obsidianTeal, size: 20),
              const SizedBox(width: 8),
              Text('PAN Required',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DesignTokens.textHighContrast,
                        fontWeight: FontWeight.w600,
                      )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your PAN is used locally to decrypt broker PDFs. It is stored securely on-device and never transmitted.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _panController,
                  obscureText: _panObscured,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: DesignTokens.textHighContrast,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'ABCDE1234F',
                    hintStyle: TextStyle(
                      color: DesignTokens.textMediumContrast.withValues(alpha: 0.4),
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                    filled: true,
                    fillColor: DesignTokens.graphiteBase,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: DesignTokens.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: DesignTokens.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignTokens.obsidianTeal),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _panObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: DesignTokens.textMediumContrast,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _panObscured = !_panObscured),
                    ),
                  ),
                  onSubmitted: (_) => _submitPan(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitPan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.obsidianTeal,
                    foregroundColor: DesignTokens.graphiteBase,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Decrypt', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard(ScanStage stage) {
    final status = _stageStatuses[stage] ?? StageStatus.waiting;
    final progress = _stageProgress[stage] ?? 0.0;
    final isActive = status == StageStatus.running;
    final isCompleted = status == StageStatus.completed;
    final isSkipped = status == StageStatus.skipped;
    final isFailed = status == StageStatus.failed;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DesignTokens.graphiteSurface,
            borderRadius: BorderRadius.circular(DesignTokens.radius8),
            border: Border.all(
              color: isActive
                  ? DesignTokens.obsidianTeal.withValues(alpha: _pulseAnimation.value)
                  : isFailed
                      ? DesignTokens.crimsonWarning.withValues(alpha: 0.4)
                      : Colors.transparent,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: DesignTokens.obsidianTeal.withValues(alpha: _pulseAnimation.value * 0.2),
                      blurRadius: 12,
                      spreadRadius: 0,
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon
              _buildStageIcon(status, isActive),
              const SizedBox(width: 12),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isActive
                                ? DesignTokens.textHighContrast
                                : isCompleted
                                    ? DesignTokens.textHighContrast.withValues(alpha: 0.7)
                                    : isSkipped
                                        ? DesignTokens.textMediumContrast.withValues(alpha: 0.4)
                                        : DesignTokens.textMediumContrast.withValues(alpha: 0.6),
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          ),
                    ),
                    if (isActive && progress > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: DesignTokens.borderSubtle,
                          valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.obsidianTeal),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Status badge
              _buildStatusBadge(status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStageIcon(StageStatus status, bool isActive) {
    IconData icon;
    Color color;

    switch (status) {
      case StageStatus.completed:
        icon = Icons.check_circle_rounded;
        color = DesignTokens.obsidianTeal;
      case StageStatus.running:
        icon = Icons.sync_rounded;
        color = DesignTokens.obsidianTeal;
      case StageStatus.failed:
        icon = Icons.error_rounded;
        color = DesignTokens.crimsonWarning;
      case StageStatus.skipped:
        icon = Icons.skip_next_rounded;
        color = DesignTokens.textMediumContrast.withValues(alpha: 0.3);
      case StageStatus.waiting:
        icon = Icons.circle_outlined;
        color = DesignTokens.textMediumContrast.withValues(alpha: 0.3);
    }

    final iconWidget = Icon(icon, color: color, size: 20);

    if (isActive) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.9 + (_pulseAnimation.value * 0.15),
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  Widget _buildStatusBadge(StageStatus status) {
    String label;
    Color bgColor;
    Color textColor;

    switch (status) {
      case StageStatus.completed:
        label = 'Done';
        bgColor = DesignTokens.obsidianTeal.withValues(alpha: 0.15);
        textColor = DesignTokens.obsidianTeal;
      case StageStatus.running:
        label = 'Active';
        bgColor = DesignTokens.obsidianTeal.withValues(alpha: 0.15);
        textColor = DesignTokens.obsidianTeal;
      case StageStatus.failed:
        label = 'Failed';
        bgColor = DesignTokens.crimsonWarning.withValues(alpha: 0.15);
        textColor = DesignTokens.crimsonWarning;
      case StageStatus.skipped:
        label = 'Skipped';
        bgColor = Colors.transparent;
        textColor = DesignTokens.textMediumContrast.withValues(alpha: 0.4);
      case StageStatus.waiting:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLiveCounters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Metrics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    letterSpacing: 1.2,
                  )),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _CounterTile(label: 'Emails', value: _counters.emailsFound, icon: Icons.mail_rounded),
              _CounterTile(label: 'PDFs Found', value: _counters.pdfsFound, icon: Icons.picture_as_pdf_rounded),
              _CounterTile(label: 'Decrypted', value: _counters.pdfsDecrypted, icon: Icons.lock_open_rounded),
              _CounterTile(label: 'Candidates', value: _counters.rawCandidatesDetected, icon: Icons.search_rounded),
              _CounterTile(
                label: 'Trades',
                value: _counters.regexTradesFound + _counters.aiTradesRepaired,
                icon: Icons.trending_up_rounded,
                highlight: true,
              ),
              _CounterTile(label: 'Snapshots', value: _counters.snapshotsParsed, icon: Icons.camera_alt_rounded),
            ],
          ),
          if (_counters.currentPdfName != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.description_rounded, color: DesignTokens.textMediumContrast, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Processing: ${_counters.currentPdfName} (${_counters.currentPdfIndex}/${_counters.pdfsFound})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DesignTokens.textMediumContrast,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedSwitcher(
        duration: AnimationPresets.durationFast,
        child: Text(
          _currentActionText,
          key: ValueKey(_currentActionText),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignTokens.textMediumContrast.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.obsidianTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: DesignTokens.obsidianTeal, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Scan Complete',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: DesignTokens.textHighContrast,
                          fontWeight: FontWeight.w600,
                        )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _completionMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.textMediumContrast,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed in ${_formatDuration(_elapsedMs)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignTokens.textHighContrast,
                    side: const BorderSide(color: DesignTokens.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HoldingsListScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.obsidianTeal,
                    foregroundColor: DesignTokens.graphiteBase,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('View Portfolio', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.crimsonWarning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: DesignTokens.crimsonWarning, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Scan Interrupted',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: DesignTokens.textHighContrast,
                          fontWeight: FontWeight.w600,
                        )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.textMediumContrast,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.textHighContrast,
                side: const BorderSide(color: DesignTokens.borderSubtle),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => setState(() => _showDebugPanel = !_showDebugPanel),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DesignTokens.graphiteSurface,
            borderRadius: BorderRadius.circular(DesignTokens.radius8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Debug: ${_debugPayloads.length} PDFs Processed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                _showDebugPanel ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: Colors.amber,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Text(
                  'RAW EXTRACTION DEBUG',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.amber, height: 1, thickness: 0.3),
          // Per-PDF cards
          ..._debugPayloads.asMap().entries.map((entry) {
            final idx = entry.key;
            final info = entry.value;
            final isExpanded = _expandedDebugIndex == idx;
            return _buildDebugPdfCard(info, idx, isExpanded);
          }),
        ],
      ),
    );
  }

  Widget _buildDebugPdfCard(DebugPdfInfo info, int index, bool isExpanded) {
    final isNseDirect = info.sender.toLowerCase().contains('nse-direct@nse.co.in');
    return Column(
      children: [
        // Summary row (always visible)
        GestureDetector(
          onTap: () => setState(() {
            _expandedDebugIndex = isExpanded ? null : index;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 14,
                      color: isNseDirect ? Colors.orangeAccent : DesignTokens.textMediumContrast,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.filename,
                        style: TextStyle(
                          color: isNseDirect ? Colors.orangeAccent : DesignTokens.textHighContrast,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: DesignTokens.textMediumContrast,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _debugChip(info.extractionMethod, Colors.cyan),
                    _debugChip(info.docType, Colors.purple),
                    _debugChip('${info.textLength} chars', info.textLength < 50 ? Colors.red : Colors.green),
                    _debugChip('regex: ${info.regexTrades}', info.regexTrades > 0 ? Colors.green : Colors.orange),
                    _debugChip('AI: ${info.aiTrades}', info.aiTrades > 0 ? Colors.green : Colors.orange),
                    _debugChip('windows: ${info.candidateWindows}', Colors.blue),
                    if (info.unresolvedTrades.isNotEmpty)
                      _debugChip('⚠️ ${info.unresolvedTrades.length} unresolved', Colors.red),
                  ],
                ),
                if (info.unresolvedTrades.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⚠️ ${info.unresolvedTrades.length} trade(s) need manual review',
                    style: const TextStyle(color: Colors.red, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                  ),
                ],
                if (info.warnings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⚠ ${info.warnings.length} warning(s)',
                    style: const TextStyle(color: Colors.amber, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Expanded: raw text
        if (isExpanded) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'RAW EXTRACTED TEXT',
                      style: TextStyle(color: Colors.amber, fontSize: 9, fontFamily: 'monospace', letterSpacing: 1.2),
                    ),
                    const Spacer(),
                    Text(
                      'from: ${info.sender}',
                      style: TextStyle(color: DesignTokens.textMediumContrast.withValues(alpha: 0.5), fontSize: 9, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  info.extractedText.isEmpty ? '(EMPTY — 0 characters extracted)' : info.extractedText,
                  style: TextStyle(
                    color: info.extractedText.isEmpty ? Colors.red : const Color(0xFF88FF88),
                    fontFamily: 'monospace',
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
                if (info.warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'WARNINGS',
                    style: TextStyle(color: Colors.amber, fontSize: 9, fontFamily: 'monospace', letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  ...info.warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '⚠ $w',
                      style: const TextStyle(color: Colors.amber, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
        if (index < _debugPayloads.length - 1)
          Divider(color: DesignTokens.borderSubtle.withValues(alpha: 0.3), height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _debugChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Counter Tile Widget
// ─────────────────────────────────────────────────────────────────────────────

class _CounterTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool highlight;

  const _CounterTile({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: highlight
                      ? DesignTokens.obsidianTeal
                      : DesignTokens.textMediumContrast.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignTokens.textMediumContrast,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: AnimationPresets.durationFast,
            builder: (context, val, _) {
              return Text(
                '$val',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: highlight
                          ? DesignTokens.obsidianTeal
                          : DesignTokens.textHighContrast,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}
