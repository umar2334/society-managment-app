// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color brand      = Color(0xFF0052CC);
  static const Color brandDark  = Color(0xFF003A99);
  static const Color brandLight = Color(0xFF1B6EE8);
  static const Color accent     = Color(0xFF00C2FF);
  static const Color gold       = Color(0xFFFFB703);
  static const Color success    = Color(0xFF06D6A0);
  static const Color danger     = Color(0xFFEF233C);
  static const Color surface    = Color(0xFFF4F7FF);
  static const Color cardBg     = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF0A1628);
  static const Color textSecondary = Color(0xFF5B6B8A);
  static const Color textMuted     = Color(0xFF99A8BF);
  static const Color divider       = Color(0xFFE4EAF5);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.light(
        primary: brand,
        secondary: accent,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.soraTextTheme().copyWith(
        displayLarge: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary),
        titleLarge:   GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
        titleMedium:  GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
        bodyLarge:    GoogleFonts.sora(fontSize: 14, color: textPrimary),
        bodyMedium:   GoogleFonts.sora(fontSize: 12, color: textSecondary),
        labelSmall:   GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: brandDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: brand, width: 2)),
        hintStyle: GoogleFonts.sora(color: textMuted, fontSize: 13),
        labelStyle: GoogleFonts.sora(color: textSecondary, fontSize: 13),
      ),
    );
  }
}
