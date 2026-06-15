import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();
  static const navy = Color(0xFF0D1B2A);
  static const navyMid = Color(0xFF1B2E45);
  static const Color navyLight = Color(0xFF2D4A6B);
  static const amber = Color(0xFF00A6D6);
  static const Color amberLight = Color(0xFFBAF2FF);
  static const Color amberDark = Color(0xFF007A9E);
  static const offWhite = Color(0xFFF8FAFC);
  static const lightGray = Color(0xFFE2E8F0);
  static const gray = Color(0xFF94A3B8);
  static const darkGray = Color(0XFF334155);
  static const green = Color(0xFF16A34A);
  static const Color greenLight = Color(0xFFDCFCE7);
  static const Color white = Color(0xFFFFFFFF);

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: navy,
      onPrimary: white,
      primaryContainer: navyMid,
      secondary: amber,
      onSecondary: navy,
      secondaryContainer: amberLight,
      surface: offWhite,
      onSurface: navy,
      surfaceContainerHighest: offWhite,
      error: Colors.red,
      onError: white,
      outline: lightGray,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: offWhite,
      primaryColor: navy,
      appBarTheme: AppBarTheme(
        backgroundColor: white,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: navy.withValues(alpha: 0.08),
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: navy),
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: amber,
      onPrimary: navy,
      primaryContainer: amberDark,
      secondary: amber,
      onSecondary: navy,
      secondaryContainer: navyLight,
      onSurface: offWhite,
      surface: navy,
      surfaceContainerHighest: navyLight,
      error: Colors.red,
      onError: white,
      outline: navyLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: navy,
      primaryColor: amber,
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: offWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: offWhite,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: offWhite),
      ),
    );
  }
}
