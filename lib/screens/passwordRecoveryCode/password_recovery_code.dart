import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../passwordChange/password_change.dart';

class RecuperarPasswordCodeScreen extends StatefulWidget {
  final String dni;
  final String email;
  const RecuperarPasswordCodeScreen({
    super.key,
    required this.dni,
    required this.email,
  });

  @override
  State<RecuperarPasswordCodeScreen> createState() =>
      _RecuperarPasswordCodeScreenState();
}

class _RecuperarPasswordCodeScreenState
    extends State<RecuperarPasswordCodeScreen> {
  final List<TextEditingController> codeControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  bool isLoading = false;

  int segundosRestantes = 50;
  bool puedeReenviar = false;
  Timer? temporizador;

  @override
  void initState() {
    super.initState();
    iniciarCuentaRegresiva();
  }

  @override
  void dispose() {
    temporizador?.cancel();
    for (var c in codeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void iniciarCuentaRegresiva() {
    temporizador?.cancel();
    setState(() {
      segundosRestantes = 50;
      puedeReenviar = false;
    });

    temporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (segundosRestantes > 0) {
        setState(() {
          segundosRestantes--;
        });
      } else {
        timer.cancel();
        setState(() {
          puedeReenviar = true;
        });
      }
    });
  }

  void reenviarCodigo() {
    mostrarMensaje(
      "El código de validación ha sido reenviado a tu dirección de correo electrónico.",
    );
    iniciarCuentaRegresiva();
  }

  Future<void> verificarCodigo() async {
    setState(() => isLoading = true);

    final codigoIngresado = codeControllers.map((c) => c.text).join();

    try {
      final response = await AuthService.verificarCodigo(
        widget.email,
        codigoIngresado,
      );

      if (response['success'] == true) {
        mostrarMensaje("Código verificado correctamente");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChangePasswordScreen(dni: widget.dni, email: widget.email),
          ),
        );
      } else {
        mostrarMensaje(response['message'] ?? "Código incorrecto", error: true);
      }
    } catch (e) {
      mostrarMensaje("Error de conexión con el servidor.", error: true);
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
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),

              Text(
                "Verificar código",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Ingresá el código de 5 dígitos que te enviamos al correo.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  return SizedBox(
                    width: 50,
                    child: TextField(
                      controller: codeControllers[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colorScheme.brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 4) {
                          FocusScope.of(context).nextFocus();
                        } else if (value.isEmpty && index > 0) {
                          FocusScope.of(context).previousFocus();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 40),

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
                  onPressed: isLoading ? null : verificarCodigo,
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
                          "Verificar código",
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
                  onTap: puedeReenviar ? reenviarCodigo : null,
                  child: Text(
                    puedeReenviar
                        ? "Volver a enviar código"
                        : "Volver a enviar el código (${segundosRestantes}s)",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: puedeReenviar
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.6),
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