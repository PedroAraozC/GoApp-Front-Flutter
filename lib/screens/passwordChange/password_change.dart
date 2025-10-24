import 'package:flutter/material.dart';
import 'package:taxi_tuc/screens/auth/auth_screen.dart';
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

      await Future.delayed(const Duration(seconds: 2));
      setState(() => isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    } else {
      mostrarMensaje(
        response['message'] ?? "Error al cambiar la contraseña",
        error: true,
      );
      setState(() => isLoading = false);
    }
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),

                Text(
                  "Cambiar contraseña",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Ingresá tu contraseña actual y establecé una nueva.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 40),

                // Contraseña actual
                TextField(
                  controller: currentPasswordController,
                  obscureText: !showCurrentPassword,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                    hintText: "Contraseña actual",
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
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

                // Nueva contraseña
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                    hintText: "Nueva contraseña",
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_reset,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showNewPassword ? Icons.visibility_off : Icons.visibility,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
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

                // Confirmar contraseña
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                    hintText: "Confirmar nueva contraseña",
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_person,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
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

                // Botón cambiar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLoading
                          ? Colors.grey.shade400
                          : colorScheme.primary,
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
                        : Text(
                            "Cambiar contraseña",
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}