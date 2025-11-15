import 'package:flutter/material.dart';
import 'package:taxi_tuc/screens/home/driver_home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await dotenv.load(fileName: ".env");
  runApp(const GoApp());
}

class GoApp extends StatelessWidget {
  const GoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaxiTuc',

      // ✅ Respeta el tema del sistema (claro/oscuro)
      themeMode: ThemeMode.system,

      // ✅ Tema claro
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00), // amarillo TaxiTuc (seed)
          brightness: Brightness.light,
        ),
      ),

      // ✅ Tema oscuro
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.dark,
        ),
      ),

      // Localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],

      // Rutas
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/auth': (_) => const AuthScreen(),
        '/home': (_) => const DriverHomeScreen(),
      },
    );
  }
}
