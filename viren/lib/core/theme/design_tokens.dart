import 'package:flutter/material.dart';

class DesignTokens {
  // Brand Colors
  static const Color graphiteBase = Color(0xFF121212); // Graphite / near-black
  static const Color graphiteSurface = Color(0xFF1E1E1E); // Elevated cards
  static const Color obsidianTeal = Color(0xFF0D9488); // Primary actions (~90%)
  static const Color ashGold = Color(0xFFB89E58); // Status/Milestones (5-8%)
  static const Color crimsonWarning = Color(0xFFE11D48); // Irreversible/Losses (≤2%)

  // Text Colors
  static const Color textHighContrast = Color(0xFFF3F4F6); // White-ish
  static const Color textMediumContrast = Color(0xFF9CA3AF); // Grey

  // Border & Dividers
  static const Color borderSubtle = Color(0xFF2D2D2D);
  
  // Spacing (8pt grid)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Radii
  static const double radius8 = 8.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
}
