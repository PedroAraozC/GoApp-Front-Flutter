import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../passwordRecoveryCode/password_recovery_code.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  State<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dniController = TextEditingController();
  bool isLoading = false;

  Future<void> enviarRecuperacion() async {
    setState(() => isLoading = true);

    final email = emailController.text.trim();
    final dni = dniController.text.trim();

    if (email.isEmpty || !email.contains("@")) {
      mostrarMensaje("Por favor ingresá un correo válido", error: true);
      setState(() => isLoading = false);
      return;
    }

    if (dni.isEmpty) {
      mostrarMensaje("Por favor ingresá tu DNI", error: true);
      setState(() => isLoading = false);
      return;
    }

    try {
      final result = await AuthService.recuperarPassword(dni, email);

      if (!mounted) return;

      if (result['success'] == true) {
        mostrarMensaje("Código enviado al correo");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RecuperarPasswordCodeScreen(dni: dni, email: email),
          ),
        );
      } else {
        mostrarMensaje(
          result['message'] ?? "Error al enviar código",
          error: true,
        );
      }
    } catch (e) {
      mostrarMensaje("Error al conectar con el servidor", error: true);
    }

    setState(() => isLoading = false);
  }

  void mostrarMensaje(String mensaje, {bool error = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? colorScheme.error : colorScheme.primary,
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: colorScheme.onSurface.withValues(alpha: 0.7)),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),

              Text(
                "Recuperar contraseña",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                "Ingresá tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 40),

              // DNI TextField
              TextField(
                controller: dniController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
                  hintText: "Número de documento",
                  hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.badge, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Email TextField
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
                  hintText: "Correo electrónico",
                  hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.email_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                ),
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  onPressed: isLoading ? null : enviarRecuperacion,
                  child: isLoading
                      ? const SizedBox(
                          height: 25,
                          width: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          "Enviar enlace de recuperación",
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    "Volver al inicio de sesión",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}