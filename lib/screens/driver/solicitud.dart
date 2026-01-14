import 'package:flutter/material.dart';
import 'nueva_solicitud_dialog.dart'; // Asegúrate de importar el dialog

/// Esta es una pantalla de EJEMPLO que simula
/// la vista del conductor (podría ser tu mapa).
class DriverHomeExampleScreen extends StatelessWidget {
  const DriverHomeExampleScreen({super.key});

  // Esta función simula la llegada de una nueva solicitud
  // y muestra el diálogo.
  void _mostrarDialogoSolicitud(BuildContext context) {
    // En un caso real, estos datos vendrían de un
    // WebSocket, Notificación Push, o una API.
    showDialog(
      context: context,
      // Impide que se cierre al tocar fuera
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NuevaSolicitudDialog(
          // --- Datos de ejemplo ---
          origen: "Av. Corrientes 1234, CABA",
          destino: "Malabia 800, Villa Crespo, CABA",
          precio: 1850.50,
          nombreUsuario: "Lucía Fernández",
          ratingUsuario: 4.8,
          viajesUsuario: 120,
          // --- Acciones ---
          onAceptar: () {
            // Lógica al aceptar el viaje
            print("VIAJE ACEPTADO");
            // Cierra el diálogo
            Navigator.of(context).pop();
            // TODO: Navegar a la pantalla de "En Curso"
          },
          onRechazar: () {
            // Lógica al rechazar
            print("VIAJE RECHAZADO");
            // Cierra el diálogo
            Navigator.of(context).pop();
            // TODO: Notificar al sistema que se rechazó
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vista del Conductor"),
      ),
      body: Center(
        child: FilledButton(
          // Este botón es solo para probar el diálogo
          onPressed: () => _mostrarDialogoSolicitud(context),
          child: const Text("Simular Nueva Solicitud"),
        ),
      ),
      // En tu app real, la pantalla del conductor
      // probablemente tendría un mapa aquí.
    );
  }
}