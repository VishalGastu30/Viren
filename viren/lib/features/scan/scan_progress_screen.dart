import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/auth/auth_service.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/ingestion/email/scan_orchestrator.dart';

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
  double _overallProgress = 0.0;
  bool _isAuthorizing = true; // Phase A: OAuth gate
  bool _isPanRequired = false;
  bool _isComplete = false;
  bool _hasError = false;
  String _completionMessage = '';
  String _errorMessage = '';

  // PAN input
  final _panController = TextEditingController();
  bool _panObscured = true;

  // Watchdog timer
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();

    // Initialize all stages to waiting
    for (final stage in ScanStage.values) {
      _stageStatuses[stage] = StageStatus.waiting;
      _stageProgress[stage] = 0.0;
    }

    // Start scan after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _orchestrator?.dispose();
    _watchdog?.cancel();
    _panController.dispose();
    super.dispose();
  }

  // ── PHASE A: OAuth Gate ──────────────────────────────────────────────────
  Future<void> _startScan() async {
    setState(() {
      _isAuthorizing = true;
      _currentActionText = 'Connecting to Gmail…';
    });

    try {
      final authService = await AuthService.create(scopes: [
        'https://www.googleapis.com/auth/gmail.readonly'
      ]);

      await authService.authenticate();

      if (!mounted) return;

      setState(() {
        _isAuthorizing = false;
        _currentActionText = 'Authorization complete. Starting scan…';
      });

      _startOrchestrator(authService);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthorizing = false;
        _hasError = true;
        _errorMessage = 'Gmail authorization failed: $e';
        _currentActionText = 'Authorization failed.';
      });
    }
  }

  // ── PHASE B: Scan Orchestration ─────────────────────────────────────────
  void _startOrchestrator(AuthService authService) {
    final tradeRepo = ref.read(tradeRepositoryProvider);
    final importDao = ref.read(importDaoProvider);
    final db = ref.read(appDatabaseProvider);
    final confidenceCalculator = ref.read(confidenceCalculatorProvider);

    _orchestrator = ScanOrchestrator(
      tradeRepository: tradeRepo,
      importDao: importDao,
      db: db,
      confidenceCalculator: confidenceCalculator,
    );

    // Also listen internally or handle StreamBuilder solely for UI.
    // The previous implementation used _handleEvent for state. We keep it
    // because it manages _isPanRequired, _isComplete, _hasError, etc.
    _subscription = _orchestrator!.events.listen(_handleEvent);
    _resetWatchdog();

    _orchestrator!.run(authService: authService);
  }

  void _resetWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 8), () {
      if (mounted && !_isComplete && !_hasError) {
        setState(() {
          _currentActionText = 'Still working… processing a large document.';
        });
        _resetWatchdog();
      }
    });
  }

  void _handleEvent(ScanEvent event) {
    if (!mounted) return;
    _resetWatchdog();

    setState(() {
      _lastEvent = event;
      _counters = event.counters;
      if (event.actionText != null) _currentActionText = event.actionText!;

      if (event is ScanPanRequiredEvent) {
        _isPanRequired = true;
        _stageStatuses[ScanStage.pdfDecryption] = StageStatus.waiting;
      } else if (event is ScanCompleteEvent) {
        _isComplete = true;
        _completeEvent = event;
        _completionMessage = event.summaryMessage;
        _overallProgress = 1.0;
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
      } else {
        _stageStatuses[event.stage] = event.status;
        _stageProgress[event.stage] = event.progress;

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

    const secureStorage = FlutterSecureStorage();
    secureStorage.write(key: 'user_pan', value: pan);

    setState(() => _isPanRequired = false);
    _orchestrator?.submitPan(pan);
  }

  // ── LAST EVENT — track the latest event for rendering ──────────────────
  ScanEvent? _lastEvent;
  ScanCompleteEvent? _completeEvent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isAuthorizing
                  ? _buildAuthGate()
                  : _isPanRequired
                      ? _buildPanInput()
                      : _hasError
                          ? _buildErrorScreen()
                          : _isComplete
                              ? _buildCompletionScreen()
                              : _buildProgressScreen(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  color: DesignTokens.textMediumContrast, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isComplete
                      ? 'Scan Complete'
                      : _hasError
                          ? 'Scan Failed'
                          : 'Scanning Email',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _isComplete
                      ? '${_counters.totalTradesInserted} trades imported'
                      : _currentActionText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                        fontSize: 11,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!_isComplete && !_hasError)
            const _PulsingDot(color: DesignTokens.obsidianTeal),
        ],
      ),
    );
  }

  // ── Auth Gate ────────────────────────────────────────────────────────────
  Widget _buildAuthGate() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: DesignTokens.obsidianTeal.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation(DesignTokens.obsidianTeal),
            ),
            const SizedBox(height: 24),
            Text(
              'Authorizing...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textHighContrast,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Requesting secure Gmail access.',
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

  // ── PAN Input ───────────────────────────────────────────────────────────
  Widget _buildPanInput() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: DesignTokens.obsidianTeal.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.lock_outline_rounded,
                  color: DesignTokens.obsidianTeal, size: 24),
              const SizedBox(width: 12),
              Text('PAN Required',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DesignTokens.textHighContrast,
                        fontWeight: FontWeight.w700,
                      )),
            ]),
            const SizedBox(height: 12),
            Text(
              'Your PAN is used locally to decrypt contract note PDFs. '
              'It is never transmitted anywhere.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _panController,
              obscureText: _panObscured,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              style: const TextStyle(
                color: DesignTokens.textHighContrast,
                fontFamily: 'monospace',
                fontSize: 18,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABCDE1234F',
                hintStyle: TextStyle(
                  color: DesignTokens.textMediumContrast
                      .withValues(alpha: 0.3),
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                ),
                filled: true,
                fillColor: DesignTokens.graphiteBase,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: DesignTokens.borderSubtle)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: DesignTokens.borderSubtle)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: DesignTokens.obsidianTeal)),
                suffixIcon: IconButton(
                  icon: Icon(
                      _panObscured
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: DesignTokens.textMediumContrast),
                  onPressed: () =>
                      setState(() => _panObscured = !_panObscured),
                ),
              ),
              onSubmitted: (_) => _submitPan(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitPan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.obsidianTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Decrypt & Continue',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error Screen ────────────────────────────────────────────────────────
  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                    DesignTokens.crimsonWarning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: DesignTokens.crimsonWarning, size: 40),
            ),
            const SizedBox(height: 24),
            Text('Scan Failed',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DesignTokens.textMediumContrast)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.graphiteSurface,
                  foregroundColor: DesignTokens.textHighContrast,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Dismiss',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Progress Screen ─────────────────────────────────────────────────────
  Widget _buildProgressScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          // ── Central progress ring ────────────────────────────────────
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring (decorative)
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DesignTokens.obsidianTeal
                            .withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  // Background track
                  SizedBox(
                    width: 136,
                    height: 136,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  // Animated progress arc
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0.0,
                        end: _overallProgress.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (_, value, __) => SizedBox(
                      width: 136,
                      height: 136,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        color: DesignTokens.obsidianTeal,
                      ),
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: 0,
                            end: (_overallProgress * 100)
                                .clamp(0.0, 100.0)),
                        duration: const Duration(milliseconds: 500),
                        builder: (_, v, __) => Text(
                          '${v.toInt()}%',
                          style: const TextStyle(
                            color: DesignTokens.textHighContrast,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastEvent?.stage.displayName ?? '',
                        style: const TextStyle(
                          color: DesignTokens.textMediumContrast,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Live stats ───────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LiveStat(
                  label: 'Emails Found',
                  value: _counters.emailsFound,
                  icon: Icons.mail_outline_rounded,
                  color: DesignTokens.textMediumContrast,
                ),
                _VerticalDivider(),
                _LiveStat(
                  label: 'PDFs Decrypted',
                  value: _counters.pdfsDecrypted,
                  total: _counters.pdfsFound,
                  icon: Icons.lock_open_rounded,
                  color: DesignTokens.ashGold,
                ),
                _VerticalDivider(),
                _LiveStat(
                  label: 'Trades Found',
                  value: _counters.regexTradesFound +
                      _counters.aiTradesRepaired,
                  icon: Icons.check_circle_outline_rounded,
                  color: DesignTokens.obsidianTeal,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Current file being processed ─────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _counters.currentPdfName != null
                ? Container(
                    key: ValueKey(_counters.currentPdfName),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: DesignTokens.obsidianTeal
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: DesignTokens.obsidianTeal
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            color: DesignTokens.obsidianTeal, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _counters.currentPdfName!,
                            style: const TextStyle(
                              color: DesignTokens.textHighContrast,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_counters.pdfsFound > 0)
                          Text(
                            '${_counters.currentPdfIndex}/${_counters.pdfsFound}',
                            style: const TextStyle(
                              color: DesignTokens.textMediumContrast,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 36),
          ),

          const SizedBox(height: 20),

          // ── Stage pipeline ───────────────────────────────────────────
          ...ScanStage.values.map(_buildStageRow),

          // ── Decryption failures warning ──────────────────────────────
          if (_counters.decryptionFailures > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DesignTokens.crimsonWarning
                    .withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DesignTokens.crimsonWarning
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: DesignTokens.crimsonWarning, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_counters.decryptionFailures} PDF(s) could not be '
                      'decrypted. Check your PAN is correct.',
                      style: const TextStyle(
                        color: DesignTokens.crimsonWarning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Stage Row Builder ───────────────────────────────────────────────────
  Widget _buildStageRow(ScanStage stage) {
    final status = _stageStatuses[stage] ?? StageStatus.waiting;
    final isCurrent = status == StageStatus.running;
    final isCompleted =
        status == StageStatus.completed || status == StageStatus.skipped;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedOpacity(
        opacity: (!isCurrent && !isCompleted) ? 0.25 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Row(
          children: [
            // Stage indicator
            SizedBox(
              width: 28,
              height: 28,
              child: isCompleted
                  ? Container(
                      decoration: BoxDecoration(
                        color: DesignTokens.obsidianTeal
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: DesignTokens.obsidianTeal, size: 14),
                    )
                  : isCurrent
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DesignTokens.obsidianTeal,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
            ),
            const SizedBox(width: 12),
            // Stage name
            Expanded(
              child: Text(
                stage.displayName,
                style: TextStyle(
                  color: isCompleted
                      ? DesignTokens.obsidianTeal
                      : isCurrent
                          ? DesignTokens.textHighContrast
                          : DesignTokens.textMediumContrast,
                  fontSize: 13,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            // Progress bar for current stage
            if (isCurrent &&
                (_stageProgress[stage] ?? 0) > 0)
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _stageProgress[stage],
                    minHeight: 2,
                    backgroundColor: DesignTokens.obsidianTeal
                        .withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(
                        DesignTokens.obsidianTeal),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Completion Screen ───────────────────────────────────────────────────
  Widget _buildCompletionScreen() {
    final trades = _counters.totalTradesInserted;
    final hasWarnings =
        _completeEvent?.importResult?.warnings.isNotEmpty == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        children: [
          // Animated success circle
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DesignTokens.obsidianTeal
                      .withValues(alpha: 0.12),
                  border: Border.all(
                    color: DesignTokens.obsidianTeal
                        .withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.check_rounded,
                    color: DesignTokens.obsidianTeal, size: 44),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            trades > 0 ? '$trades Trades Imported' : 'Scan Complete',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 8),

          Text(
            _completionMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.textMediumContrast,
                  height: 1.5,
                ),
          ),

          const SizedBox(height: 32),

          // Stats grid
          Row(
            children: [
              Expanded(
                  child: _CompletionStat(
                label: 'Emails',
                value: '${_counters.emailsFound}',
                icon: Icons.mail_outline_rounded,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _CompletionStat(
                label: 'PDFs',
                value: '${_counters.pdfsDecrypted}',
                icon: Icons.description_outlined,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _CompletionStat(
                label: 'Trades',
                value: '$trades',
                icon: Icons.trending_up_rounded,
                highlight: true,
              )),
            ],
          ),

          if (hasWarnings) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.ashGold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        DesignTokens.ashGold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: DesignTokens.ashGold, size: 15),
                    const SizedBox(width: 8),
                    Text('Needs Review',
                        style: TextStyle(
                          color: DesignTokens.ashGold,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                  ]),
                  const SizedBox(height: 10),
                  ..._completeEvent!.importResult!.warnings
                      .take(3)
                      .map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• $w',
                            style: TextStyle(
                              color: DesignTokens.textMediumContrast,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.obsidianTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Done',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

// ── Live Stat ───────────────────────────────────────────────────────────
class _LiveStat extends StatelessWidget {
  final String label;
  final int value;
  final int? total;
  final IconData icon;
  final Color color;

  const _LiveStat({
    required this.label,
    required this.value,
    this.total,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 500),
              builder: (_, v, __) => Text(
                '${v.toInt()}',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
            if (total != null && total! > 0)
              Text(
                '/$total',
                style: const TextStyle(
                  color: DesignTokens.textMediumContrast,
                  fontSize: 12,
                  height: 1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: DesignTokens.textMediumContrast,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ── Vertical Divider ────────────────────────────────────────────────────
class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

// ── Completion Stat ─────────────────────────────────────────────────────
class _CompletionStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _CompletionStat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? DesignTokens.obsidianTeal
        : DesignTokens.textMediumContrast;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: highlight
            ? DesignTokens.obsidianTeal.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? DesignTokens.obsidianTeal.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                color: DesignTokens.textMediumContrast,
                fontSize: 11,
              )),
        ],
      ),
    );
  }
}

// ── Pulsing Dot ─────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
