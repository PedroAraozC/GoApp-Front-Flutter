import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart'; // Home pasajero
import 'screens/home/driver/driver_map_screen.dart'; // Panel chofer
import 'services/user_preferences.dart'; // 👈 para leer el usuario guardado y tema
import 'screens/home/widgets/taximetro_overlay.dart'; // 👈 overlay global del taxímetro
import 'screens/home/driver/driver_taximetro_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// Controlador global de tema (se guarda en SharedPreferences)
class AppThemeController {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  Future<void> load() async {
    final saved = await UserPreferences.getThemeMode(); // system|light|dark
    themeMode.value = _fromString(saved);
  }

  Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    await UserPreferences.setThemeMode(_toString(mode));
  }

  static ThemeMode _fromString(String v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // 👇 Carga el tema guardado ANTES de levantar la app
  await AppThemeController.instance.load();

  runApp(const GoApp());
}

class GoApp extends StatelessWidget {
  const GoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [routeObserver],
          debugShowCheckedModeBanner: false,
          title: 'TaxiTuc',

          // ✅ Tema global controlado por preferencias
          themeMode: mode,

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
            '/home/driver': (_) => const DriverMapScreen(),
            '/taximetro': (_) => const TaximetroScreen(),
          },
        );
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
