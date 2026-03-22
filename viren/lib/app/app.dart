import 'package:flutter/material.dart';

import '../core/theme/viren_theme.dart';
import '../features/splash/splash_screen.dart';

import '../core/market/market_watcher_service.dart';
import '../core/security/biometric_service.dart';
import '../core/security/biometric_lock_screen.dart';

class VirenApp extends StatefulWidget {
  const VirenApp({super.key});

  @override
  State<VirenApp> createState() => _VirenAppState();
}

class _VirenAppState extends State<VirenApp> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _biometricEnabled = false;
  final _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricOnLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkBiometricOnLaunch() async {
    final enabled = await _biometricService.isBiometricEnabled();
    setState(() {
      _biometricEnabled = enabled;
      _isUnlocked = !enabled; // if not enabled, start unlocked
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _biometricEnabled) {
      setState(() => _isUnlocked = false);
    }
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      MarketWatcherController.stop();
    } else if (state == AppLifecycleState.resumed) {
      MarketWatcherController.startIfMarketOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_biometricEnabled && !_isUnlocked) {
      return MaterialApp(
        title: 'Viren',
        theme: VirenTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: BiometricLockScreen(
          onUnlocked: () => setState(() => _isUnlocked = true),
        ),
      );
    }
    return MaterialApp(
      title: 'Viren',
      theme: VirenTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
