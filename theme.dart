import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const primary = Color(0xFF2F5BFF);
  static const primary2 = Color(0xFF2B49D6);
  static const bg = Color(0xFFF5F7FF);

  static const card = Colors.white;
  static const text = Color(0xFF111827);
  static const subText = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

/// ✅ App theme
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AppColors.text),
  ),

   
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  ),
);



/// ✅ Call this ONCE (in main.dart)
void setupSystemUI() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color.fromARGB(0, 163, 129, 129), // 👈 no color behind status bar
      statusBarIconBrightness: Brightness.dark, // 👈 black icons (battery/wifi)
      statusBarBrightness: Brightness.light, // iOS
    ),
  );
}


