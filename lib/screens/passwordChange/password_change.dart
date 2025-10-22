import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String dni;
  final String email;
  const ChangePasswordScreen({
    super.key,
    required this.dni,
    required this.email,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool showCurrentPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;

  Future<void> cambiarContrasena() async {
    setState(() => isLoading = true);

    final current = currentPasswordController.text.trim();
    final nueva = newPasswordController.text.trim();
    final confirmar = confirmPasswordController.text.trim();

    if (current.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
      mostrarMensaje("Todos los campos son obligatorios", error: true);
      setState(() => isLoading = false);
      return;
    }

    if (nueva.length < 6) {
      mostrarMensaje(
        "La nueva contraseña debe tener al menos 6 caracteres",
        error: true,
      );
      setState(() => isLoading = false);
      return;
    }

    if (nueva != confirmar) {
      mostrarMensaje("Las contraseñas no coinciden", error: true);
      setState(() => isLoading = false);
      return;
    }

    final response = await AuthService.cambiarPassword(
      dni: widget.dni,
      email: widget.email,
      actual: current,
      nueva: nueva,
    );

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (response['success'] == true) {
      mostrarMensaje("Contraseña cambiada exitosamente");
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();

      // Podés redirigir al login, por ejemplo:
      //Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

      await Future.delayed(const Duration(seconds: 2));

      setState(() => isLoading = false);
      print("Te vas al login");
    } else {
      mostrarMensaje(
        response['message'] ?? "Error al cambiar la contraseña",
        error: true,
      );
      setState(() => isLoading = false);
    }
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
                "Cambiar contraseña",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Ingresá tu contraseña actual y establecé una nueva.",
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
              const SizedBox(height: 40),

              // Contraseña actual
              TextField(
                controller: currentPasswordController,
                obscureText: !showCurrentPassword,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Contraseña actual",
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.black45,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showCurrentPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.black45,
                    ),
                    onPressed: () {
                      setState(
                        () => showCurrentPassword = !showCurrentPassword,
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF6C63FF),
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

              // Nueva contraseña
              TextField(
                controller: newPasswordController,
                obscureText: !showNewPassword,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Nueva contraseña",
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(
                    Icons.lock_reset,
                    color: Colors.black45,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showNewPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black45,
                    ),
                    onPressed: () {
                      setState(() => showNewPassword = !showNewPassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF6C63FF),
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

              // Confirmar contraseña
              TextField(
                controller: confirmPasswordController,
                obscureText: !showConfirmPassword,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Confirmar nueva contraseña",
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(
                    Icons.lock_person,
                    color: Colors.black45,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.black45,
                    ),
                    onPressed: () {
                      setState(
                        () => showConfirmPassword = !showConfirmPassword,
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF6C63FF),
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

              // Botón cambiar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLoading
                        ? Colors.grey.shade400
                        : const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  onPressed: isLoading ? null : cambiarContrasena,
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
                          "Cambiar contraseña",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
