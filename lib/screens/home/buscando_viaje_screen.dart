// lib/screens/.../buscando_viaje_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import 'viaje_asignado_screen.dart'; // 👈 ajustá la ruta si es necesario

class BuscandoViajeScreen extends StatefulWidget {
  final int idViaje; // ID del viaje actual

  const BuscandoViajeScreen({super.key, required this.idViaje});

  @override
  State<BuscandoViajeScreen> createState() => _BuscandoViajeScreenState();
}

class _BuscandoViajeScreenState extends State<BuscandoViajeScreen> {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();

  bool _viajeAsignado = false;
  bool _viajeCancelado = false;
  bool _viajeEnCurso = false;
  bool _cancelando = false;

  bool _navegandoADetalle = false; // para evitar navegar dos veces

  @override
  void initState() {
    super.initState();
    _inicializarSocketListeners();
  }

  Future<void> _inicializarSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');

    // Conectamos si no está conectado todavía
    if (!_socket.isConnected) {
      await _socket.connect();
      debugPrint('🔌 Socket conectado desde BuscandoViajeScreen');
    }

    // Registramos al usuario en el socket como pasajero
    if (idUsuario != null) {
      await _socket.emitirConexionUsuario(idUsuario, 'pasajero');
      debugPrint(
        '✅ Pasajero $idUsuario registrado en socket desde BuscandoViajeScreen',
      );
      _mostrarSnack('Conectado al servidor.');
    }

    // 🚕 Evento: viaje asignado
    _socket.on('viaje_asignado', (data) {
      debugPrint('🚕 Evento: viaje_asignado -> $data');
      final latDesde = double.tryParse(
        (data['lat_desde'] ?? data['latDesde']).toString(),
      );

      final lonDesde = double.tryParse(
        (data['lon_desde'] ?? data['lonDesde']).toString(),
      );

      try {
        // 1) Validar que el viaje que llega por socket sea el mismo que este screen
        final rawId =
            data?['id_viajes'] ??
            data?['id_viaje'] ??
            data?['id']; // por las dudas
        if (rawId == null) return;

        final idSocket = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId.toString());

        if (idSocket == null || idSocket != widget.idViaje) {
          debugPrint(
            'ℹ️ viaje_asignado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
          );
          return;
        }

        if (!mounted || _navegandoADetalle || _viajeCancelado) return;

        setState(() {
          _viajeAsignado = true;
          _navegandoADetalle = true;
        });

        _mostrarSnack('Un conductor fue asignado a tu viaje 🚕');

        // 2) Extraer datos del viaje para mostrar en la pantalla siguiente
        final direccionOrigen =
            (data['direccion_desde'] ?? data['direccionDesde'] ?? '')
                .toString();
        final direccionDestino =
            (data['direccion_hasta'] ?? data['direccionHasta'] ?? '')
                .toString();

        final dynamic rawValor = data['valor'];
        final double? precioEstimado = rawValor is num
            ? rawValor.toDouble()
            : double.tryParse(rawValor?.toString() ?? '');

        // 3) Navegar a la pantalla de viaje asignado
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ViajeAsignadoScreen(
              idViaje: widget.idViaje,
              direccionOrigen: direccionOrigen,
              direccionDestino: direccionDestino,
              precioEstimado: precioEstimado,
              latOrigen: double.parse(data['lat_desde'].toString()),
              lngOrigen: double.parse(data['lon_desde'].toString()),
            ),
          ),
        );
      } catch (e) {
        debugPrint('❌ Error procesando viaje_asignado: $e');
      }
    });

    // ▶️ Evento: viaje en curso
    _socket.on('viaje_en_curso', (data) {
      debugPrint('▶️ Evento: viaje_en_curso -> $data');
      if (mounted) setState(() => _viajeEnCurso = true);
      _mostrarSnack('Tu viaje ha comenzado ▶️');
    });

    // 🏁 Evento: viaje finalizado
    _socket.on('viaje_finalizado', (data) {
      debugPrint('🏁 Evento: viaje_finalizado -> $data');
      if (mounted) {
        setState(() {
          _viajeEnCurso = false;
          _viajeAsignado = false;
        });
      }
      _mostrarSnack('El viaje ha finalizado. ¡Gracias por usar GoApp!');
      // En este flujo normalmente ya estarías en otra pantalla.
    });

    // ❌ Evento: viaje cancelado (desde servidor / conductor / usuario)
    _socket.on('viaje_cancelado', (data) {
      debugPrint('❌ Evento: viaje_cancelado -> $data');

      try {
        // Filtrar por ID de viaje: solo reaccionamos si es ESTE viaje
        final rawId =
            data?['id_viajes'] ??
            data?['id_viaje'] ??
            data?['id']; // por las dudas
        if (rawId == null) return;

        final idSocket = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId.toString());

        if (idSocket == null || idSocket != widget.idViaje) {
          debugPrint(
            'ℹ️ viaje_cancelado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
          );
          return;
        }

        if (mounted) {
          setState(() {
            _viajeCancelado = true;
            _cancelando = false;
          });
        }
        _mostrarSnack('Tu viaje fue cancelado.');

        // 👉 Ir directamente al Home después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home', // 👈 ajustá el nombre de la ruta de tu home si es distinto
            (route) => false,
          );
        });
      } catch (e) {
        debugPrint('❌ Error procesando viaje_cancelado: $e');
      }
    });
  }

  Future<void> _cancelarViaje() async {
    if (_cancelando) return; // Evitar doble clic
    setState(() => _cancelando = true);

    try {
      // 1) Cancelar en el backend
      await _api.cancelarViaje(widget.idViaje);
      _mostrarSnack('Cancelando viaje...');

      // 2) El controlador cancelarViaje ya emite "viaje_cancelado"
      //    y el listener de arriba se encarga de navegar al home.
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
    // Dejamos la conexión global del socket, pero limpiamos listeners de esta pantalla
    _socket.off('viaje_asignado');
    _socket.off('viaje_en_curso');
    _socket.off('viaje_finalizado');
    _socket.off('viaje_cancelado');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String estadoActual = 'Buscando conductor...';
    if (_viajeAsignado) estadoActual = 'Conductor asignado 🚕';
    if (_viajeEnCurso) estadoActual = 'Viaje en curso ▶️';
    if (_viajeCancelado) estadoActual = 'Viaje cancelado ❌';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Buscando viaje'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_viajeCancelado && !_cancelando)
              const CircularProgressIndicator(color: Colors.amber),
            if (_cancelando) const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 20),
            Text(
              _cancelando ? 'Cancelando...' : estadoActual,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (!_viajeCancelado)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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
          ],
        ),
      ),
    );
  }
}
