import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class RecuperarPasswordCodeScreen extends StatefulWidget {
  const RecuperarPasswordCodeScreen({super.key});

  @override
  State<RecuperarPasswordCodeScreen> createState() =>
      _RecuperarPasswordCodeScreenState();
}

class _RecuperarPasswordCodeScreenState
    extends State<RecuperarPasswordCodeScreen> {
  final List<TextEditingController> codeControllers =
      List.generate(5, (_) => TextEditingController());

  bool isLoading = false;
  final String codigoCorrecto = "12345";

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
    /*ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("El codigo de validación ha sido reenviad a tu dirección de correo electrónico."),
        duration: Duration(seconds: 2),
      ),
    );*/
    mostrarMensaje("El código de validación ha sido reenviado a tu dirección de correo electrónico.");
    iniciarCuentaRegresiva();
  }

  Future<void> verificarCodigo() async {
    setState(() => isLoading = true);

    final codigoIngresado = codeControllers.map((c) => c.text).join();

    await Future.delayed(const Duration(seconds: 1));

    if (codigoIngresado == codigoCorrecto) {
      mostrarMensaje("El código de validación ha sido verificado correctamente.");
      for (var c in codeControllers) {
        c.clear();
      }
    } else {
      mostrarMensaje("El código de validación ingresado no es correcto.", error: true);
      for (var c in codeControllers) {
        c.clear();
      }
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
                "Verificar código",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Ingresá el código de 5 dígitos que te enviamos al correo.",
                style: TextStyle(color: Colors.black54, fontSize: 15),
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
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C63FF),
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
                    backgroundColor: const Color(0xFF6C63FF),
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
                      : const Text(
                          "Verificar código",
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
                  onTap: puedeReenviar ? reenviarCodigo : null,
                  child: Text(
                    puedeReenviar
                        ? "Volver a enviar código"
                        : "Volver a enviar el código (${segundosRestantes}s)",
                    style: TextStyle(
                      color: puedeReenviar
                          ? const Color(0xFF6C63FF)
                          : Colors.grey,
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
