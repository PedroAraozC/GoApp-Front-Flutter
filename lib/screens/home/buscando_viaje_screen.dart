import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class BuscandoViajeScreen extends StatefulWidget {
  final int id_viaje;

  const BuscandoViajeScreen({super.key, required this.id_viaje});

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

  GoogleMapController? _mapCtrl;
  LatLng? _passengerLocation;
  LatLng? _driverLocation;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final PolylinePoints _polylinePoints = PolylinePoints();
  final String _googleApiKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'] ?? '';

  StreamSubscription<Position>? _positionSub;
  
  @override
  void initState() {
    super.initState();
     _initLocation();  
    _inicializarSocketListeners();
  }

  Future<void> _initLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _passengerLocation = LatLng(pos.latitude, pos.longitude);

    _markers.add(
      Marker(
        markerId: const MarkerId('passenger'),
        position: _passengerLocation!,
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ),
    );
    setState(() {});
  } catch (e) {
    debugPrint('Error init location pasajero: $e');
  }
}

  Future<void> _inicializarSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');

    // Conectamos si no está conectado todavía
    if (!_socket.isConnected) {
      await _socket.connect();
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('🔌 Socket conectado desde BuscandoViajeScreen');
    }

    // ✅ Registramos al usuario en el socket
    if (idUsuario != null) {
      await _socket.emitirConexionUsuario(idUsuario, 'pasajero');
      debugPrint(
        '✅ Usuario $idUsuario registrado en socket desde BuscandoViajeScreen',
      );
      _mostrarSnack('Conectado al servidor.');
    }

    // 🆕 Evento: viaje creado
    _socket.on('viaje_creado', (data) {
      debugPrint('🆕 Evento: viaje_creado -> $data');
      _mostrarSnack('Tu solicitud de viaje fue enviada correctamente.');
    });

    // 🚕 Evento: viaje asignado
    _socket.on('viaje_asignado', (data) {
      debugPrint('🚕 Evento: viaje_asignado -> $data');
      if (mounted) setState(() => _viajeAsignado = true);
      _mostrarSnack('Un conductor fue asignado a tu viaje 🚕');
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
    });

    // ❌ Evento: viaje cancelado
    _socket.on('viaje_cancelado', (data) {
      debugPrint('❌ Evento: viaje_cancelado -> $data');
      if (mounted) {
        setState(() {
          _viajeCancelado = true;
          _cancelando = false;
        });
      }
      _mostrarSnack('Tu viaje fue cancelado.');

      // Opcional: Volver a la pantalla anterior después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      });
    });
  }

  Future<void> _cancelarViaje() async {
    if (_cancelando) return; // Evitar doble clic
    setState(() => _cancelando = true);

    try {
      debugPrint('📤 Cancelando viaje con ID: ${widget.id_viaje}');
      // 1) Llamar al backend para cancelar el viaje
      final resp = await _api.cancelarViaje(widget.id_viaje!);

      if (!mounted) return;

      final msg = resp['message']?.toString() ?? 'Respuesta desconocida';

      if (resp['message'] == 'Viaje cancelado exitosamente') {
        _mostrarSnack('Viaje cancelado correctamente');

        // 2) Ir al menú principal del usuario
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home', // 👈 ruta de tu HomeScreen de pasajero
          (route) => false,
        );
      } else {
        _mostrarSnack(msg);
      }
    } catch (e) {
      debugPrint('❌ Error al cancelar viaje: $e');
      if (mounted) {
        _mostrarSnack('Error al cancelar el viaje');
      }
    } finally {
      if (mounted) {
        setState(() => _cancelando = false);
      }
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
    // ⚠️ No desconectamos el socket: queremos mantener la sesión global
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
