import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/auth/splash_screen.dart';

void main() => runApp(const BitesLogApp());

class BitesLogApp extends StatelessWidget {
  const BitesLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitesLog',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const SplashScreen(),
    );
  }
}
