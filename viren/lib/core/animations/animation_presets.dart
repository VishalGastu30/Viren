import 'package:flutter/widgets.dart';

class AnimationPresets {
  // Flag modified via Settings to instantly zero out durations (Calm Mode)
  static bool calmModeEnabled = false;

  /// Speeds
  static Duration get durationMicro => calmModeEnabled ? Duration.zero : const Duration(milliseconds: 150);
  static Duration get durationFast => calmModeEnabled ? Duration.zero : const Duration(milliseconds: 300);
  static Duration get durationNormal => calmModeEnabled ? Duration.zero : const Duration(milliseconds: 500);
  static Duration get durationSlow => calmModeEnabled ? Duration.zero : const Duration(milliseconds: 800);
  static Duration get durationChartDraw => calmModeEnabled ? Duration.zero : const Duration(milliseconds: 1200);

  /// Standard globally accessible easing curves
  // Used for primary entrances, page reveals
  static const Curve entrance = Cubic(0.16, 1.0, 0.3, 1.0); 

  // Used for hover states, button scaling, micro-interactions
  static const Curve micro = Cubic(0.22, 1.0, 0.36, 1.0);

  // For steady timeline draw logic or unweighted panning
  static const Curve linear = Curves.linear;
}
