import 'package:flutter/material.dart';

class AppColors {
  static const primary    = Color(0xFFD65A7A);
  static const secondary  = Color(0xFF7B8FB2);
  static const background  = Color(0xFFFAFAFA);
  static const card        = Color(0xFFFFFFFF);
  static const text        = Color(0xFF2D2230);
  static const accent      = Color(0xFFF7C6D0);
}

final appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);