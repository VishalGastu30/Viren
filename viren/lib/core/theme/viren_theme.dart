import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

class VirenTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DesignTokens.graphiteBase,
      primaryColor: DesignTokens.obsidianTeal,
      canvasColor: DesignTokens.graphiteBase,
      colorScheme: const ColorScheme.dark(
        primary: DesignTokens.obsidianTeal,
        secondary: DesignTokens.ashGold,
        surface: DesignTokens.graphiteSurface,
        error: DesignTokens.crimsonWarning,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: DesignTokens.textHighContrast,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          color: DesignTokens.textHighContrast,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          color: DesignTokens.textHighContrast,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        displaySmall: GoogleFonts.inter(
          color: DesignTokens.textHighContrast,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: GoogleFonts.inter(
          color: DesignTokens.textHighContrast,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: GoogleFonts.inter(
          color: DesignTokens.textHighContrast,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.inter(
          color: DesignTokens.textHighContrast,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          color: DesignTokens.textMediumContrast,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: GoogleFonts.inter(
          color: DesignTokens.obsidianTeal,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: GoogleFonts.inter(
          color: DesignTokens.textMediumContrast,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: DesignTokens.textHighContrast),
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.graphiteSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: DesignTokens.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: DesignTokens.textHighContrast,
        size: 24,
      ),
    );
  }
}
