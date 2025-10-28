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
    // 🔍 PRINT DEL ID VIAJE AL INICIAR
    print('🚕 BuscandoViajeScreen iniciado con idViaje: ${widget.idViaje}');
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEstado());
  }

  Future<void> _checkEstado() async {
    try {
      // 🔍 PRINT ANTES DE HACER LA PETICIÓN
      print('🔄 Haciendo polling para idViaje: ${widget.idViaje}');

      final result = await _api.obtenerViaje(widget.idViaje);
      if (!mounted || result == null) return;

      final estado = (result['estado'] ?? 'buscando') as String;

      // 🔍 PRINT DEL ESTADO OBTENIDO
      print('📊 Estado obtenido para idViaje ${widget.idViaje}: $estado');

      setState(() => _estado = estado);

      if (estado != 'buscando') {
        _timer?.cancel();
        if (!mounted) return;

        String msg = 'Estado del viaje: $estado';
        if (estado == 'Asignado') msg = '¡Conductor asignado!';
        if (estado == 'En Curso') msg = '¡Tu viaje ya comenzó!';
        if (estado == 'Cancelado') msg = 'Viaje cancelado';
        if (estado == 'Finalizado') msg = 'Viaje finalizado';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context); // volver al mapa
      }
    } catch (e) {
      // 🔍 PRINT DEL ERROR
      print('❌ Error en polling para idViaje ${widget.idViaje}: $e');
    }
  }

  Future<void> _cancelar() async {
    if (_cancelando) return;

    // 🔍 PRINT AL CANCELAR
    print('🚫 Cancelando viaje idViaje: ${widget.idViaje}');

    setState(() => _cancelando = true);
    try {
      await _api.cancelarViaje(widget.idViaje);
      print('✅ Viaje ${widget.idViaje} cancelado exitosamente');
    } catch (e) {
      print('❌ Error al cancelar viaje ${widget.idViaje}: $e');
    } finally {
      if (!mounted) return;
      setState(() => _cancelando = false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // 🔍 PRINT AL DESTRUIR LA PANTALLA
    print('🔚 BuscandoViajeScreen dispose - idViaje: ${widget.idViaje}');
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
