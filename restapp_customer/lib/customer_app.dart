import 'package:flutter/material.dart';
import 'package:restapp_customer/screens/bootstrap/customer_bootstrap_screen.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Restaurant Customer',

      theme: ThemeData(
        useMaterial3: true,

        colorSchemeSeed: Colors.deepOrange,

        scaffoldBackgroundColor: const Color(0xFFF8F8F8),

        appBarTheme: const AppBarTheme(centerTitle: false),
      ),

      home: const CustomerBootstrapScreen(),
    );
  }
}
