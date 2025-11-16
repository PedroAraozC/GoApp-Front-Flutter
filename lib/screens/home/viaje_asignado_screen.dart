import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/socket_service.dart';
import '../../services/api_service.dart';

class ViajeAsignadoScreen extends StatefulWidget {
  final int idViaje;
  final String direccionOrigen;
  final String direccionDestino;
  final double? precioEstimado;

  const ViajeAsignadoScreen({
    super.key,
    required this.idViaje,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.precioEstimado,
  });

  @override
  State<ViajeAsignadoScreen> createState() => _ViajeAsignadoScreenState();
}

class _ViajeAsignadoScreenState extends State<ViajeAsignadoScreen> {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();

  bool _viajeEnCurso = false;
  bool _viajeFinalizado = false;
  bool _viajeCancelado = false;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _inicializarSocketListeners();
  }

  Future<void> _inicializarSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');

    // Aseguramos conexión al socket
    if (!_socket.isConnected) {
      await _socket.connect();
      debugPrint('🔌 Socket conectado desde ViajeAsignadoScreen');
    }

    // Registramos al usuario como pasajero (room pasajero_ID y "pasajeros")
    if (idUsuario != null) {
      await _socket.emitirConexionUsuario(idUsuario, 'pasajero');
      debugPrint(
        '✅ Pasajero $idUsuario registrado en socket desde ViajeAsignadoScreen',
      );
      _mostrarSnack('Conectado al servidor.');
    }

    // ▶️ Evento: viaje en curso (conductor marcó "comenzar")
    _socket.on('viaje_en_curso', (data) {
      try {
        debugPrint('▶️ Evento: viaje_en_curso -> $data');
        final idData = data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
        if (idData == null) return;

        final id = idData is num
            ? idData.toInt()
            : int.tryParse(idData.toString());

        if (id != widget.idViaje) return;

        if (mounted) {
          setState(() => _viajeEnCurso = true);
        }
        _mostrarSnack('Tu viaje ha comenzado ▶️');
      } catch (e) {
        debugPrint('Error procesando viaje_en_curso: $e');
      }
    });

    // 🏁 Evento: viaje finalizado
    _socket.on('viaje_finalizado', (data) {
      try {
        debugPrint('🏁 Evento: viaje_finalizado -> $data');
        final idData = data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
        if (idData == null) return;

        final id = idData is num
            ? idData.toInt()
            : int.tryParse(idData.toString());

        if (id != widget.idViaje) return;

        if (mounted) {
          setState(() {
            _viajeFinalizado = true;
            _viajeEnCurso = false;
          });
        }
        _mostrarSnack('El viaje ha finalizado. ¡Gracias por usar GoApp!');

        // Volver al home (o a la pantalla anterior) después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      } catch (e) {
        debugPrint('Error procesando viaje_finalizado: $e');
      }
    });

    // ❌ Evento: viaje cancelado (por conductor o sistema)
    _socket.on('viaje_cancelado', (data) {
      try {
        debugPrint('❌ Evento: viaje_cancelado -> $data');
        final idData = data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
        if (idData == null) return;

        final id = idData is num
            ? idData.toInt()
            : int.tryParse(idData.toString());

        if (id != widget.idViaje) return;

        if (mounted) {
          setState(() {
            _viajeCancelado = true;
            _cancelando = false;
            _viajeEnCurso = false;
          });
        }
        _mostrarSnack('Tu viaje fue cancelado.');

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } catch (e) {
        debugPrint('Error procesando viaje_cancelado: $e');
      }
    });
  }

  Future<void> _cancelarViaje() async {
    if (_cancelando) return; // evitar doble tap
    setState(() => _cancelando = true);

    try {
      await _api.cancelarViaje(widget.idViaje);
      _mostrarSnack('Cancelando viaje...');

      // El backend emitirá "viaje_cancelado" y el listener se encargará
    } catch (e) {
      debugPrint('❌ Error al cancelar viaje: $e');
      _mostrarSnack('Error al cancelar el viaje');
      if (mounted) setState(() => _cancelando = false);
    }
  }

  void _mostrarSnack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    // Limpiamos listeners asociados a esta pantalla
    _socket.off('viaje_en_curso');
    _socket.off('viaje_finalizado');
    _socket.off('viaje_cancelado');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String estado = 'Conductor en camino hacia tu ubicación 🚕';

    if (_viajeEnCurso) {
      estado = 'Estás viajando hacia tu destino ▶️';
    }

    if (_viajeFinalizado) {
      estado = 'Viaje finalizado 🏁';
    }

    if (_viajeCancelado) {
      estado = 'Viaje cancelado ❌';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tu viaje'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              estado,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Tarjeta con info del viaje
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalles del viaje',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.radio_button_checked, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.direccionOrigen,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.direccionDestino,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.precioEstimado != null)
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Precio estimado: \$${widget.precioEstimado!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Botón de cancelar viaje
            if (!_viajeCancelado && !_viajeFinalizado)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _cancelando ? null : _cancelarViaje,
                icon: _cancelando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cancel),
                label: Text(_cancelando ? 'Cancelando...' : 'Cancelar viaje'),
              ),

            if (_viajeFinalizado || _viajeCancelado) ...[
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Volver'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
