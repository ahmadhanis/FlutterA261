import 'package:flutter/material.dart';

import 'views/splashscreen.dart';

void main() {
  runApp(const BudgetPlusApp());
}

class BudgetPlusApp extends StatelessWidget {
  const BudgetPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF147D64);
    return MaterialApp(
      title: 'Budget Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF7F8F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
