// lib/screens/home/buscando_viaje_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../screens/home/services/api_service.dart';

/// Pantalla que muestra "Buscando viaje…" y hace polling al backend
/// para conocer el estado del viaje usando ApiService.
class BuscandoViajeScreen extends StatefulWidget {
  final int idViaje;
  const BuscandoViajeScreen({super.key, required this.idViaje});

  @override
  State<BuscandoViajeScreen> createState() => _BuscandoViajeScreenState();
}

class _BuscandoViajeScreenState extends State<BuscandoViajeScreen> {
  final _api = ApiService();
  Timer? _timer;
  String _estado = 'buscando';
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEstado());
  }

  Future<void> _checkEstado() async {
    try {
      final result = await _api.obtenerViaje(widget.idViaje);
      if (!mounted || result == null) return;

      final estado = (result['estado'] ?? 'buscando') as String;
      setState(() => _estado = estado);

      if (estado != 'buscando') {
        _timer?.cancel();
        if (!mounted) return;

        String msg = 'Estado del viaje: $estado';
        if (estado == 'asignado') msg = '¡Conductor asignado!';
        if (estado == 'en_curso') msg = '¡Tu viaje ya comenzó!';
        if (estado == 'cancelado') msg = 'Viaje cancelado';
        if (estado == 'finalizado') msg = 'Viaje finalizado';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context); // volver al mapa
      }
    } catch (_) {
      // silencioso: en el próximo tick del timer reintenta
    }
  }

  Future<void> _cancelar() async {
    if (_cancelando) return;
    setState(() => _cancelando = true);
    try {
      await _api.cancelarViaje(widget.idViaje);
    } catch (_) {
      // opcional: mostrar error si querés
    } finally {
      if (!mounted) return;
      setState(() => _cancelando = false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Buscando viaje…')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(strokeWidth: 6),
              ),
              const SizedBox(height: 20),
              Text(
                _estado == 'buscando'
                    ? 'Buscando un conductor cerca de vos…'
                    : 'Actualizando estado…',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'ID de viaje: ${widget.idViaje}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _cancelando ? null : _cancelar,
                icon: const Icon(Icons.close),
                label: Text(_cancelando ? 'Cancelando…' : 'Cancelar solicitud'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
