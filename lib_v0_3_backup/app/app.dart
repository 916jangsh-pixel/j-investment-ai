import 'package:flutter/material.dart';

import '../screens/main_shell.dart';

class JInvestmentApp extends StatelessWidget {
  const JInvestmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J.Investment AI',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F7CFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        cardTheme: const CardThemeData(
          color: Color(0xFF161B22),
          margin: EdgeInsets.zero,
        ),
      ),
      home: const MainShell(),
    );
  }
}
