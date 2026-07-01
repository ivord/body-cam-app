import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark/teal palette, ported 1:1 from the "NVR Viewer" design mockup.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0B0F14);
  static const surface = Color(0xFF121821);
  static const surfaceAlt = Color(0xFF10161E);
  static const border = Color(0xFF1F2733);
  static const borderStrong = Color(0xFF243140);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8A98A8);
  static const textTertiary = Color(0xFF586676);
  static const teal = Color(0xFF2DD4BF);
  static const tealOn = Color(0xFF04201D);
  static const green = Color(0xFF43D17A);
  static const red = Color(0xFFE23B3B);
  static const recRed = Color(0xFFFF4D4D);
  static const deleteRed = Color(0xFFFF7A7A);
  static const amber = Color(0xFFF5B544);
}

ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.teal,
    onPrimary: AppColors.tealOn,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.red,
  );

  final textTheme = GoogleFonts.ibmPlexSansTextTheme(ThemeData(
    brightness: Brightness.dark,
    textTheme: const TextTheme(),
  ).textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    dividerColor: AppColors.border,
  );
}

/// IBM Plex Mono, used for hosts/IPs/channel codes/labels per the mockup.
TextStyle monoText({
  double fontSize = 12.5,
  FontWeight fontWeight = FontWeight.w500,
  Color color = AppColors.textSecondary,
  double? letterSpacing,
}) =>
    GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
