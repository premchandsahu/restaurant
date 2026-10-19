import 'package:flutter/material.dart';

import 'screens/captain_login_screen.dart';

void main() {
  runApp(const CaptainApp());
}

class CaptainApp extends StatelessWidget {
  const CaptainApp({super.key});

  // Change this single value when moving
  // between testing and production.
  static const String baseUrl = 'http://api.jaihindplaster.com:5000';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jai Hind Captain',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const CaptainLoginScreen(baseUrl: baseUrl),
    );
  }
}
