import 'package:flutter/material.dart';
import 'package:go_app_flutter/screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaxiTuc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // <-- solo llama al HomeScreen
    );
  }
}
