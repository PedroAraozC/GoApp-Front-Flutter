import 'package:flutter/material.dart';
import 'dart:async';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  State<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  Future<void> enviarRecuperacion() async {
    setState(() => isLoading = true);

    final email = emailController.text.trim();

    // Validar email
    if (email.isEmpty || !email.contains("@")) {
      mostrarMensaje("Por favor ingresá un correo válido", error: true);
      setState(() => isLoading = false);
      return;
    }

    await Future.delayed(const Duration(seconds: 2));

    final exito = email == "usuario@ejemplo.com";

    if (exito) {
      mostrarMensaje("Se envió el enlace de recuperación a tu correo");
      emailController.clear();
    } else {
      mostrarMensaje("El correo ingresado no está registrado", error: true);
    }

    setState(() => isLoading = false);
  }

  void mostrarMensaje(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.redAccent : Colors.green,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Botón volver
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),

              const Text(
                "Recuperar contraseña",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Ingresá tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Correo electrónico",
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Colors.black45),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF6C63FF), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 18, horizontal: 16),
                ),
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
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
                      : const Text(
                          "Enviar enlace de recuperación",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "Volver al inicio de sesión",
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
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
