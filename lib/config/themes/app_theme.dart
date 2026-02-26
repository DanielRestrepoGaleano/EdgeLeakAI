import 'package:flutter/material.dart';

class AppTheme {
  static const Color normalColor = Color(0xFF4CAF50); // Verde
  static const Color warningColor = Color(0xFFFFC107); // Amarillo
  static const Color criticalColor = Color(0xFFF44336); // Rojo
  static const Color primaryColor = Color(0xFF2196F3); // Azul

  static ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
    );
  }
}
