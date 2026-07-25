import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const VohnegasnykyApp());
}

class VohnegasnykyApp extends StatelessWidget {
  const VohnegasnykyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'РозкладкаВ',
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
