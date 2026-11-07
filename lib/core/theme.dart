import 'package:flutter/material.dart';

class Brand {
  static const orange = Color(0xFFE2964E);
  static const orangeLight = Color(0xFFF2B27A);
  static const orangeDeep = Color(0xFFC8742A);
  static const dark = Color(0xFF1B1B17);
  static const card = Color(0xFF26261F);
  static const card2 = Color(0xFF33332A);
  static const text = Color(0xFFF4EFE8);
  static const muted = Color(0xFFA9A395);
  static const bg = dark;
  static const green = Color(0xFF6FDC94);
  static const red = Color(0xFFFF8C82);
}

ThemeData buildTheme(bool arabic) => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: arabic ? 'Cairo' : 'Ubuntu',
      colorScheme: ColorScheme.fromSeed(
        seedColor: Brand.orange,
        brightness: Brightness.dark,
        primary: Brand.orange,
        surface: Brand.dark,
      ),
      scaffoldBackgroundColor: Brand.dark,
      cardTheme: CardTheme(
        color: Brand.card,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Brand.dark,
        foregroundColor: Brand.text,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Brand.orange,
          foregroundColor: Brand.dark,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Brand.card,
        hintStyle: const TextStyle(color: Brand.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
