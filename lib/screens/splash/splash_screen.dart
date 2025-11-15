import 'package:flutter/material.dart';
import 'package:taxi_tuc/screens/home/driver/driver_home_screen.dart';
import 'package:taxi_tuc/screens/home/home_screen.dart'; // 👈 import home pasajero
import '../../services/user_preferences.dart';
import '../../screens/auth/auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // ⏳ Después de la animación, verificamos sesión y rol
    Future.delayed(const Duration(seconds: 3), _checkAuthStatus);
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await UserPreferences.isLoggedIn();

      if (!isLoggedIn) {
        // No hay sesión → ir al login
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
        return;
      }

      // Sí hay sesión → cargamos datos del usuario
      final user = await UserPreferences.getUser(); // Map<String, dynamic>?
      final dynamic rawRole = user?['id_rol'];
      final int roleId = rawRole is String
          ? int.tryParse(rawRole) ?? 0
          : (rawRole is int ? rawRole : 0);

      if (!mounted) return;

      if (roleId == 3) {
        // 👨‍✈️ Conductor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        );
      } else if (roleId == 2) {
        // 🧑‍✈️ Pasajero
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: user ?? {})),
        );
      } else {
        // Rol desconocido → por seguridad al login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error en _checkAuthStatus: $e');
      if (!mounted) return;
      // Si algo falla, mandamos al login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFCC00),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset('assets/images/taxituc_splash.png', width: 180),
          ),
        ),
      ),
    );
  }
}
