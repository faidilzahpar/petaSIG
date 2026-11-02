import 'package:flutter/material.dart';

class TopoTheme {
  // Dark Industrial Slate Palette
  static const Color bgDark = Color(0xFF0D1117);
  static const Color surfaceDark = Color(0xFF161B22);
  static const Color cardDark = Color(0xFF21262D);
  static const Color borderDark = Color(0xFF30363D);

  // Precision Accents
  static const Color laserCyan = Color(0xFF00F0FF);
  static const Color safetyAmber = Color(0xFFFF9F1C);
  static const Color statusGreen = Color(0xFF00E676);
  static const Color alertRed = Color(0xFFFF4D4F);
  static const Color textLight = Color(0xFFF0F6FC);
  static const Color textMuted = Color(0xFF8B949E);

  // Hypsometric Tint (Pewarnaan Ketinggian Topografi)
  static Color getElevationColor(double z, double minZ, double maxZ) {
    if (maxZ <= minZ) return const Color(0xFF10B981);
    double t = ((z - minZ) / (maxZ - minZ)).clamp(0.0, 1.0);

    if (t < 0.25) {
      return Color.lerp(const Color(0xFF065F46), const Color(0xFF10B981), t / 0.25)!;
    } else if (t < 0.5) {
      return Color.lerp(const Color(0xFF10B981), const Color(0xFFFBBF24), (t - 0.25) / 0.25)!;
    } else if (t < 0.75) {
      return Color.lerp(const Color(0xFFFBBF24), const Color(0xFFEA580C), (t - 0.5) / 0.25)!;
    } else {
      return Color.lerp(const Color(0xFFEA580C), const Color(0xFFF8FAFC), (t - 0.75) / 0.25)!;
    }
  }

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgDark,
      cardColor: cardDark,
      colorScheme: const ColorScheme.dark(
        primary: safetyAmber,
        secondary: laserCyan,
        surface: surfaceDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: safetyAmber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

