import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen2.dart';
import 'screens/home/home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const GoApp());
}

class GoApp extends StatelessWidget {
  const GoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tucu Taxi',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFFCC00),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/auth': (_) => const AuthScreen2(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
