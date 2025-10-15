import 'package:flutter/material.dart';
import 'package:go_app_flutter/screens/passwordRecovery/password_recovey.dart';
import 'package:go_app_flutter/screens/perfil_screen.dart';
import 'package:go_app_flutter/screens/passwordRecoveryCode/password_recovery_code.dart';
import 'package:go_app_flutter/screens/passwordChange/password_change.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
       return MaterialApp(
      title: 'Mi App',
      debugShowCheckedModeBanner: false,

      // 👇👇 Agregá esto 👇👇
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés (por si acaso)
      ],

      home: const ChangePasswordScreen(),
    );
  }
}
