import 'package:flutter/material.dart';
import 'package:restapp/screens/pos/pos_menu_test_screen.dart';
import 'package:restapp/screens/pos/pos_service_test_screen.dart';

import 'screens/login/login_screen.dart';

void main() {
  runApp(const RestaurantPosApp());
  // runApp(const PosServiceTestScreen());
}

class RestaurantPosApp extends StatelessWidget {
  const RestaurantPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Restaurant POS',

      theme: ThemeData(useMaterial3: true),

      home: //PosMenuTestScreen(),
          // PosServiceTestScreen(),
          const LoginScreen(),
    );
  }
}
