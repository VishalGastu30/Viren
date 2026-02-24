import 'package:flutter/material.dart';

import '../core/theme/viren_theme.dart';
import '../features/splash/splash_screen.dart';

class VirenApp extends StatelessWidget {
  const VirenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viren',
      theme: VirenTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
