import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart'; // Home pasajero
import 'screens/home/driver/driver_home_screen.dart'; // Panel chofer
import 'services/user_preferences.dart'; // 👈 para leer el usuario guardado
import 'screens/home/widgets/taximetro_overlay.dart'; // 👈 overlay global del taxímetro
import './screens/home/driver/driver_taximetro_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'TaxiTuc',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.dark,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            const TaximetroOverlay(), // 👈 flotante global
          ],
        );
      },
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/auth': (_) => const AuthScreen(),
        '/home': (_) => const _HomeWrapper(),
        '/home/driver': (_) => const DriverHomeScreen(),
        '/taximetro': (_) => const TaximetroScreen(),
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
