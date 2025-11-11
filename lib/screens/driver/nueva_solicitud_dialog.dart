import 'package:flutter/material.dart';

/// Un diálogo modal que se muestra al conductor
/// cuando hay una nueva solicitud de viaje.
class NuevaSolicitudDialog extends StatelessWidget {
  // --- Información del Viaje ---
  final String origen;
  final String destino;
  final double precio;

  // --- Información del Pasajero ---
  final String nombreUsuario;
  final double ratingUsuario;
  final int viajesUsuario;

  // --- Acciones ---
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const NuevaSolicitudDialog({
    super.key,
    required this.origen,
    required this.destino,
    required this.precio,
    required this.nombreUsuario,
    required this.ratingUsuario,
    required this.viajesUsuario,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    // Usamos Dialog para que aparezca centrado
    // y con el fondo oscurecido.
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      elevation: 5,
      // Evita que el diálogo se cierre al tocar fuera
      child: PopScope(
        canPop: false,
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // Ajusta el tamaño al contenido
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Text(
                "Nueva Solicitud de Viaje",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Información del pasajero
              _BuildUserInfo(
                nombre: nombreUsuario,
                rating: ratingUsuario,
                viajes: viajesUsuario,
              ),

              const Divider(height: 32.0),

              // Información del viaje (Origen/Destino)
              _BuildTripInfo(
                origen: origen,
                destino: destino,
              ),

              const SizedBox(height: 20),

              // Precio (grande y centrado)
              Text(
                "ARS \$${precio.toStringAsFixed(2)}",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),

              const SizedBox(height: 24),

              // Botones de Acción
              _BuildActionButtons(
                onAceptar: onAceptar,
                onRechazar: onRechazar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Widget Interno: Info del Pasajero ---
class _BuildUserInfo extends StatelessWidget {
  final String nombre;
  final double rating;
  final int viajes;

  const _BuildUserInfo({
    required this.nombre,
    required this.rating,
    required this.viajes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.account_circle,
          size: 50,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 16),
                  Text(
                    " ${rating.toStringAsFixed(1)}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    "  •  $viajes viajes",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Widget Interno: Info del Viaje ---
class _BuildTripInfo extends StatelessWidget {
  final String origen;
  final String destino;

  const _BuildTripInfo({required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(
          icon: Icons.trip_origin,
          color: Colors.green,
          title: "Origen",
          subtitle: origen,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.place,
          color: Colors.red,
          title: "Destino",
          subtitle: destino,
        ),
      ],
    );
  }
}

// --- Widget Interno: Fila de Info (Origen/Destino) ---
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Widget Interno: Botones de Acción ---
class _BuildActionButtons extends StatelessWidget {
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _BuildActionButtons({
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Botón Rechazar (secundario)
        Expanded(
          child: OutlinedButton(
            onPressed: onRechazar,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Rechazar"),
          ),
        ),
        const SizedBox(width: 12),
        // Botón Aceptar (primario)
        Expanded(
          child: FilledButton(
            onPressed: onAceptar,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Aceptar"),
          ),
        ),
      ],
    );
  }
}