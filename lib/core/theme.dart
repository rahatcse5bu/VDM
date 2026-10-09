import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF2F7BF5);
  static const primaryDeep = Color(0xFF1F62DA);
  static const success = Color(0xFF22B573);
  static const purple = Color(0xFF9B6BF2);
}

/// Surface colours that differ between light and dark mode.
class VdmPalette {
  const VdmPalette({
    required this.bg,
    required this.card,
    required this.soft,
    required this.text,
    required this.muted,
    required this.border,
  });

  final Color bg;
  final Color card;
  final Color soft;
  final Color text;
  final Color muted;
  final Color border;

  static const light = VdmPalette(
    bg: Color(0xFFF4F8FE),
    card: Colors.white,
    soft: Color(0xFFEAF2FE),
    text: Color(0xFF1B2333),
    muted: Color(0xFF6B7487),
    border: Color(0xFFE3EAF5),
  );

  static const dark = VdmPalette(
    bg: Color(0xFF0D131F),
    card: Color(0xFF161F30),
    soft: Color(0xFF1C2840),
    text: Color(0xFFEFF3FA),
    muted: Color(0xFF94A0B8),
    border: Color(0xFF26324A),
  );
}

extension VdmContext on BuildContext {
  VdmPalette get palette =>
      Theme.of(this).brightness == Brightness.dark ? VdmPalette.dark : VdmPalette.light;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? VdmPalette.dark : VdmPalette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      surface: p.card,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme)
        .apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: TextStyle(color: p.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
