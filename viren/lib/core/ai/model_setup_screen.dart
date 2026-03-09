import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/assistant/assistant_service.dart';
import '../theme/design_tokens.dart';
import 'model_download_service.dart';

enum SetupStage {
  idle,
  connecting,
  resuming,
  downloading,
  unwrapping, // ZIP extraction stage
  wiring,
  testing,
  ready,
  failed
}

class ModelSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const ModelSetupScreen({super.key, required this.onComplete});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen>
    with TickerProviderStateMixin {
  SetupStage _stage = SetupStage.idle;
  double _progress = 0.0;
  String _speed = '-- MB/s';
  String _received = '0 MB';
  String _total = '1.60 GB';
  String _errorMessage = '';

  // Single AssistantService instance — not recreated on every retry
  final AssistantService _assistantService = AssistantService();

  late AnimationController _orbController;
  late AnimationController _pulseController;

  static const _stageLabels = {
    SetupStage.connecting: 'Connecting to Dropbox',
    SetupStage.resuming: 'Resuming download',
    SetupStage.downloading: 'Downloading Viren AI',
    SetupStage.unwrapping: 'Unpacking model',
    SetupStage.wiring: 'Wiring neural pathways',
    SetupStage.testing: 'Running diagnostics',
    SetupStage.ready: 'Viren is ready',
  };

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
        vsync: this, duration: const Duration(seconds: 4));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() => _stage = SetupStage.connecting);
    _orbController.repeat();

    final success = await ModelDownloadService.downloadModel(
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
      onStage: (s) {
        if (mounted) {
          setState(() {
            if (s == 'downloading') _stage = SetupStage.downloading;
            if (s == 'resuming') _stage = SetupStage.resuming;
            if (s == 'unwrapping') _stage = SetupStage.unwrapping;
          });
        }
      },
      onSpeed: (s) {
        if (mounted) setState(() => _speed = s);
      },
      onSize: (r, t) {
        if (mounted) setState(() {
          _received = r;
          _total = t;
        });
      },
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _stage = SetupStage.failed;
        _errorMessage = 'Download failed. Check your connection and try again.';
      });
      _orbController.stop();
      return;
    }

    // Wiring stage
    setState(() {
      _stage = SetupStage.wiring;
      _progress = 0.97;
    });
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Testing stage
    setState(() {
      _stage = SetupStage.testing;
      _progress = 0.99;
      _errorMessage = '';
    });

    try {
      final result = await _assistantService.sendMessage(
        userMessage: 'Reply with exactly the single word: ready',
        portfolioContext: 'No data.',
        history: [],
      );
      debugPrint('DIAGNOSTIC RESULT: "$result"');

      if (!mounted) return;

      if (result.isNotEmpty) {
        setState(() {
          _stage = SetupStage.ready;
          _progress = 1.0;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          _orbController.stop();
          widget.onComplete();
        }
      } else {
        throw Exception('Empty response from model.');
      }
    } catch (e) {
      debugPrint('DIAGNOSTIC ERROR: $e');
      if (mounted) {
        final msg = e.toString();
        String displayError;
        if (msg.contains('MODEL_FILE_MISSING')) {
          displayError = 'Model file not found after download.\nPlease try again.';
        } else if (msg.contains('PLATFORM_ERROR')) {
          displayError = 'The AI engine could not start.\nYour device may not support this model.';
        } else if (msg.contains('Out of memory') || msg.contains('OOM')) {
          displayError = 'Not enough RAM to load the model.\nClose other apps and try again.';
        } else {
          displayError = 'Diagnostics failed. Please try again.\n\n$msg';
        }
        setState(() {
          _stage = SetupStage.failed;
          _errorMessage = displayError;
        });
        _orbController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold — rendered inside AssistantScreen's Material wrapper
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_stage == SetupStage.idle) _buildWifiWarning(),
            if (_stage == SetupStage.idle) const SizedBox(height: 32),
            _buildOrb(),
            const SizedBox(height: 32),
            Text(
              'Viren AI',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: DesignTokens.textHighContrast,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _stage == SetupStage.idle
                  ? 'Your private investment assistant'
                  : _stage == SetupStage.ready
                      ? 'Ready to talk'
                      : _stage == SetupStage.failed
                          ? 'Setup failed'
                          : 'Setting up...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  ),
            ),
            const SizedBox(height: 40),
            if (_stage != SetupStage.idle && _stage != SetupStage.ready)
              _buildProgressBar(),
            if (_stage == SetupStage.downloading ||
                _stage == SetupStage.resuming)
              _buildSpeedDisplay(),
            const SizedBox(height: 32),
            if (_stage != SetupStage.idle) _buildStageLog(),
            const SizedBox(height: 40),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.ashGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: DesignTokens.ashGold.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_rounded, color: DesignTokens.ashGold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'This download is 1.6 GB. Connect to WiFi to avoid mobile data charges.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.ashGold,
                  height: 1.5,
                ),
          ),
        ),
      ]),
    );
  }

  Widget _buildProgressBar() {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: DesignTokens.graphiteSurface,
          valueColor: const AlwaysStoppedAnimation<Color>(
              DesignTokens.obsidianTeal),
          minHeight: 6,
        ),
      ),
      const SizedBox(height: 10),
    ]);
  }

  Widget _buildSpeedDisplay() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(_progress * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.obsidianTeal,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            '  ·  $_speed  ·  $_received / $_total',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_stage == SetupStage.idle) {
      return Column(children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.obsidianTeal,
              foregroundColor: DesignTokens.graphiteBase,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Download Viren AI  ·  1.6 GB',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Downloaded once. Stored privately on your device.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignTokens.textMediumContrast.withValues(alpha: 0.6),
                fontSize: 11,
                height: 1.5,
              ),
          textAlign: TextAlign.center,
        ),
      ]);
    }

    if (_stage == SetupStage.failed) {
      return Column(children: [
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignTokens.crimsonWarning,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() {
              _stage = SetupStage.idle;
              _progress = 0.0;
              _speed = '-- MB/s';
              _errorMessage = '';
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.obsidianTeal,
              foregroundColor: DesignTokens.graphiteBase,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Try Again'),
          ),
        ),
      ]);
    }

    // Downloading / unwrapping / wiring / testing / ready — no button
    return const SizedBox.shrink();
  }

  Widget _buildOrb() {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: Listenable.merge([_orbController, _pulseController]),
        builder: (context, _) => CustomPaint(
          painter: _OrbPainter(
            stage: _stage,
            rotateValue: _orbController.value,
            pulseValue: _pulseController.value,
          ),
        ),
      ),
    );
  }

  Widget _buildStageLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SetupStage.connecting,
        SetupStage.downloading,
        SetupStage.unwrapping,
        SetupStage.wiring,
        SetupStage.testing,
        SetupStage.ready,
      ].map((s) {
        final label = _stageLabels[s]!;
        bool isPast = false;
        bool isCurrent = false;
        final sIndex = s.index;
        var currentStageIdx = _stage.index;

        // Map aliased stages to their display equivalents
        if (currentStageIdx == SetupStage.resuming.index) {
          currentStageIdx = SetupStage.downloading.index;
        }
        if (currentStageIdx == SetupStage.failed.index) {
          currentStageIdx = SetupStage.testing.index;
        }

        if (currentStageIdx > sIndex) {
          isPast = true;
        } else if (currentStageIdx == sIndex) {
          isCurrent = true;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Center(child: _buildStageDot(isPast, isCurrent)),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isCurrent
                          ? DesignTokens.obsidianTeal
                          : isPast
                              ? DesignTokens.textHighContrast
                              : DesignTokens.textMediumContrast,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
              if (isCurrent)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FadeTransition(
                    opacity: _pulseController,
                    child: const Text('◀',
                        style: TextStyle(
                            color: DesignTokens.obsidianTeal, fontSize: 12)),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStageDot(bool isPast, bool isCurrent) {
    if (isPast) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: DesignTokens.obsidianTeal,
          shape: BoxShape.circle,
        ),
      );
    }
    if (isCurrent) {
      return FadeTransition(
        opacity: _pulseController,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: DesignTokens.obsidianTeal,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        border: Border.all(
            color: DesignTokens.textMediumContrast, width: 1.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final SetupStage stage;
  final double rotateValue;
  final double pulseValue;

  _OrbPainter({
    required this.stage,
    required this.rotateValue,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (stage == SetupStage.ready || stage == SetupStage.failed) {
      final color = stage == SetupStage.ready
          ? DesignTokens.obsidianTeal
          : DesignTokens.crimsonWarning;
      canvas.drawCircle(center, radius, Paint()..color = color);
      final iconPaint = Paint()
        ..color = DesignTokens.graphiteBase
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (stage == SetupStage.ready) {
        final path = Path();
        path.moveTo(center.dx - 12, center.dy + 2);
        path.lineTo(center.dx - 4, center.dy + 10);
        path.lineTo(center.dx + 16, center.dy - 10);
        canvas.drawPath(path, iconPaint);
      } else {
        canvas.drawLine(Offset(center.dx - 12, center.dy - 12),
            Offset(center.dx + 12, center.dy + 12), iconPaint);
        canvas.drawLine(Offset(center.dx + 12, center.dy - 12),
            Offset(center.dx - 12, center.dy + 12), iconPaint);
      }
      return;
    }

    final innerScale = 0.9 + (pulseValue * 0.2);
    canvas.drawCircle(
      center,
      radius * 0.5 * innerScale,
      Paint()
        ..color = DesignTokens.obsidianTeal.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(center, 4, Paint()..color = DesignTokens.obsidianTeal);

    final outerAngle = rotateValue * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.9),
      outerAngle,
      math.pi * 1.5,
      false,
      Paint()
        ..color = DesignTokens.obsidianTeal.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final middleAngle = -rotateValue * math.pi * 4;
    final middlePaint = Paint()
      ..color = DesignTokens.obsidianTeal.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final arcSweep = math.pi * 2 / 24;
    for (int i = 0; i < 12; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.7),
        middleAngle + (i * arcSweep * 2),
        arcSweep,
        false,
        middlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.rotateValue != rotateValue ||
        oldDelegate.pulseValue != pulseValue;
  }
}