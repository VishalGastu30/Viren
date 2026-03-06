import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const BiometricLockScreen({super.key, required this.onUnlocked});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> with SingleTickerProviderStateMixin {
  final _biometricService = BiometricService();
  int _failedAttempts = 0;
  bool _showError = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptBiometric();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _promptBiometric({bool allowPin = false}) async {
    setState(() => _showError = false);
    
    final success = await _biometricService.authenticate(
      reason: 'Unlock Viren',
      biometricOnly: !allowPin,
    );

    if (!mounted) return;

    if (success) {
      await _fadeController.forward();
      if (mounted) {
        widget.onUnlocked();
      }
    } else {
      setState(() {
        _failedAttempts++;
        _showError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: DesignTokens.graphiteBase,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Text(
                  'VIREN',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: DesignTokens.textHighContrast,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 1,
                  color: DesignTokens.obsidianTeal,
                ),
                const SizedBox(height: 64),
                
                // Fingerprint Icon
                const Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: DesignTokens.obsidianTeal,
                ),
                const SizedBox(height: 24),
                
                // Text
                const Text(
                  'Touch sensor to unlock',
                  style: TextStyle(
                    color: DesignTokens.textMediumContrast,
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Error & Retry
                if (_showError) ...[
                  const Text(
                    'Authentication failed',
                    style: TextStyle(
                      color: DesignTokens.crimsonWarning,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _promptBiometric(),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: DesignTokens.obsidianTeal),
                    ),
                  ),
                ],

                // PIN Fallback
                if (_failedAttempts >= 3) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _promptBiometric(allowPin: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.graphiteSurface,
                      foregroundColor: DesignTokens.textHighContrast,
                    ),
                    child: const Text('Use device PIN'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
