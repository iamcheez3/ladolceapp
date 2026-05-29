import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Comprehensive Material 3 theme configuration for LaDolce
/// Supports both light and dark modes with premium food delivery aesthetics
class AppTheme {
  AppTheme._();

  // Brand Colors - Premium food delivery palette
  static const Color primaryNavy = Color(0xFF0D1565);
  static const Color primaryNavyLight = Color(0xFF1E2A7A);
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentGold = Color(0xFFC6A15B);
  static const Color accentCoral = Color(0xFFF97316);
  
  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF475569);
  static const Color darkDivider = Color(0xFF334155);

  // Spacing System - 4px base grid
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceBase = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double space3xl = 40;

  // Border Radius System
  static const double radiusSm = 8;
  static const double radiusBase = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusFull = 9999;

  // Typography Scale
  static const double textXs = 10;
  static const double textSm = 12;
  static const double textBase = 14;
  static const double textMd = 16;
  static const double textLg = 18;
  static const double textXl = 20;
  static const double text2xl = 24;
  static const double text3xl = 30;

  // Elevation/Shadow System
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowBase => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // Light Theme
  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light(useMaterial3: true);
    
    return baseTheme.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primaryNavy,
      colorScheme: const ColorScheme.light(
        primary: primaryNavy,
        onPrimary: Colors.white,
        primaryContainer: primaryNavyLight,
        onPrimaryContainer: Colors.white,
        secondary: accentTeal,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFCCFBF1),
        onSecondaryContainer: accentTeal,
        tertiary: accentGold,
        onTertiary: Colors.white,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceContainerHighest: lightCard,
        onSurfaceVariant: lightTextSecondary,
        outline: lightBorder,
        error: error,
        onError: Colors.white,
        shadow: const Color(0x1A000000),
      ),
      textTheme: _buildTextTheme(baseTheme.textTheme, lightTextPrimary, lightTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: textLg,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: spaceBase, vertical: spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusBase),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: textBase,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: spaceBase, vertical: spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusBase),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: textBase,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentTeal,
          padding: const EdgeInsets.symmetric(horizontal: spaceSm, vertical: spaceSm),
          textStyle: GoogleFonts.inter(
            fontSize: textSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightDivider,
        selectedColor: primaryNavy,
        labelStyle: GoogleFonts.inter(fontSize: textSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryNavy,
        unselectedItemColor: lightTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: textXs, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: textXs),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceBase, vertical: spaceMd),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusBase),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusBase),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusBase),
          borderSide: const BorderSide(color: primaryNavy, width: 2),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: textBase,
          color: lightTextTertiary,
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    
    return baseTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryNavy,
      colorScheme: const ColorScheme.dark(
        primary: primaryNavy,
        onPrimary: Colors.white,
        primaryContainer: primaryNavyLight,
        onPrimaryContainer: Colors.white,
        secondary: accentTeal,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF134E4A),
        onSecondaryContainer: accentTeal,
        tertiary: accentGold,
        onTertiary: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkCard,
        onSurfaceVariant: darkTextSecondary,
        outline: darkBorder,
        error: error,
        onError: Colors.white,
        shadow: const Color(0x4D000000),
      ),
      textTheme: _buildTextTheme(baseTheme.textTheme, darkTextPrimary, darkTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: textLg,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: spaceBase, vertical: spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusBase),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: textBase,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: spaceBase, vertical: spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusBase),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: textBase,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentTeal,
          padding: const EdgeInsets.symmetric(horizontal: spaceSm, vertical: spaceSm),
          textStyle: GoogleFonts.inter(
            fontSize: textSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkDivider,
        selectedColor: primaryNavy,
        labelStyle: GoogleFonts.inter(fontSize: textSm, color: darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: accentTeal,
        unselectedItemColor: darkTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: textXs, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: textXs),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceBase, vertical: spaceMd),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusBase),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusBase),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusBase),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: textBase,
          color: darkTextTertiary,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: text3xl,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: text2xl,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: textXl,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: textLg,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: textMd,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: textBase,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: textMd,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: textBase,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: textSm,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: textBase,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: textSm,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: textXs,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: textBase,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: textSm,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: textXs,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Extension methods for easy theme access
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  bool get isDarkMode => theme.brightness == Brightness.dark;
}
