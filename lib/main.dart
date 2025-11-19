import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart'; // Home pasajero
import 'screens/home/driver/driver_home_screen.dart'; // Panel chofer
import 'services/user_preferences.dart'; // 👈 para leer el usuario guardado

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

        // 👇 Home general (pasajero, usa el usuario guardado en SharedPreferences)
        '/home': (_) => const _HomeWrapper(),

        // 👇 Home del chofer (id_rol == 3; la pantalla misma valida el rol)
        '/home/driver': (_) => const DriverHomeScreen(),
      },
    );
  }
}

/// Wrapper para cargar el usuario guardado y abrir HomeScreen correctamente
class _HomeWrapper extends StatelessWidget {
  const _HomeWrapper();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserPreferences.getUser(),
      builder: (context, snapshot) {
        // Mientras carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si no hay usuario guardado → mandamos a login
        if (!snapshot.hasData || snapshot.data == null) {
          return const AuthScreen();
        }

        // ✅ Usuario real desde SharedPreferences
        final user = snapshot.data!;
        return HomeScreen(user: user);
      },
    );
  }
}
