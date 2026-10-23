import 'package:flutter/material.dart';

class Brand {
  static const orange = Color(0xFFFF9900);
  static const dark = Color(0xFF232323);
  static const bg = Color(0xFFF6F6F6);
  static const green = Color(0xFF2E9E5B);
  static const red = Color(0xFFD64545);
}

ThemeData buildTheme(bool arabic) => ThemeData(
      useMaterial3: true,
      fontFamily: arabic ? 'Cairo' : 'Ubuntu',
      colorScheme: ColorScheme.fromSeed(
        seedColor: Brand.orange,
        primary: Brand.orange,
        secondary: Brand.dark,
      ),
      scaffoldBackgroundColor: Brand.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Brand.dark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Brand.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
