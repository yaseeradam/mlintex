import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color accentColor = Color(0xFF06B6D4);
  static const Color accentLight = Color(0xFF22D3EE);

  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  static const Color backgroundStart = Color(0xFF0F172A);
  static const Color backgroundMid = Color(0xFF1E293B);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF334155);
  static const Color surfaceLighter = Color(0xFF475569);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static final Color cardBorder = Colors.white.withOpacity(0.06);

  static const _fontFamily = 'Inter';

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w800, letterSpacing: -1.5,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w800, letterSpacing: -1.0,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w700, letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w700, letterSpacing: -0.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w700, letterSpacing: -0.25,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w600, letterSpacing: -0.15,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w500, letterSpacing: 0.0,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w400, letterSpacing: 0.1,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w600, letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w500, letterSpacing: 0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: _fontFamily, fontWeight: FontWeight.w500, letterSpacing: 0.5,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: Colors.white,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF0F172A),
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFFF1F5F9),
      ),
      fontFamily: _fontFamily,
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          fontFamily: _fontFamily,
          letterSpacing: -0.5,
        ),
        toolbarHeight: 60,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 52),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        floatingLabelStyle: const TextStyle(color: primaryColor),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 15,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF1F5F9),
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor.withOpacity(0.25);
          return const Color(0xFFE2E8F0);
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
    );
  }

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}
