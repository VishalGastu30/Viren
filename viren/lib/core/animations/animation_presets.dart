import 'package:flutter/widgets.dart';

enum AnimationIntensity { subtle, balanced, expressive }

class AnimationPresets {
  // Flag modified via Settings to instantly zero out durations (Calm Mode)
  static bool calmModeEnabled = false;

  // Animation intensity — affects scale, parallax, stagger depth
  static AnimationIntensity intensity = AnimationIntensity.balanced;

  /// Intensity multiplier for non-essential animations
  static double get _intensityScale {
    switch (intensity) {
      case AnimationIntensity.subtle: return 0.5;
      case AnimationIntensity.balanced: return 1.0;
      case AnimationIntensity.expressive: return 1.4;
    }
  }

  /// Speeds — all respect calmModeEnabled
  static Duration get durationMicro => calmModeEnabled ? Duration.zero : Duration(milliseconds: (150 * _intensityScale).round());
  static Duration get durationFast => calmModeEnabled ? Duration.zero : Duration(milliseconds: (300 * _intensityScale).round());
  static Duration get durationNormal => calmModeEnabled ? Duration.zero : Duration(milliseconds: (500 * _intensityScale).round());
  static Duration get durationSlow => calmModeEnabled ? Duration.zero : Duration(milliseconds: (800 * _intensityScale).round());
  static Duration get durationChartDraw => calmModeEnabled ? Duration.zero : Duration(milliseconds: (1200 * _intensityScale).round());

  /// Parallax factor — 0 in calm mode, scaled by intensity
  static double get parallaxFactor => calmModeEnabled ? 0.0 : 0.4 * _intensityScale;

  /// Stagger offset — used to compute per-item stagger delays
  static Duration staggerItem(int index) {
    if (calmModeEnabled) return Duration.zero;
    return Duration(milliseconds: (80 * index * _intensityScale).round());
  }

  /// Standard globally accessible easing curves
  // Used for primary entrances, page reveals
  static const Curve entrance = Cubic(0.16, 1.0, 0.3, 1.0);

  // Used for hover states, button scaling, micro-interactions
  static const Curve micro = Cubic(0.22, 1.0, 0.36, 1.0);

  // For steady timeline draw logic or unweighted panning
  static const Curve linear = Curves.linear;
}
