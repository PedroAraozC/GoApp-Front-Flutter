import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'pasajero_viaje_en_curso_screen.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/user_preferences.dart';

class ViajeAsignadoScreen extends StatefulWidget {
  final int idViaje;
  final String direccionOrigen;
  final String direccionDestino;

  /// ✅ Precio fijo (pactado) que se mantiene hasta finalizar.
  final double precioFinal;

  final double latDestino;
  final double lngDestino;

  final double latOrigen;
  final double lngOrigen;

  const ViajeAsignadoScreen({
    super.key,
    required this.idViaje,
    required this.direccionOrigen,
    required this.direccionDestino,
    required this.latOrigen,
    required this.lngOrigen,
    required this.latDestino,
    required this.lngDestino,
    required this.precioFinal,
  });

  @override
  State<ViajeAsignadoScreen> createState() => _ViajeAsignadoScreenState();
}

class _ViajeAsignadoScreenState extends State<ViajeAsignadoScreen> {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService.instance;

  StreamSubscription<Position>? _posSub;
  int? _passengerId;

  GoogleMapController? _mapCtrl;

  LatLng? _posConductor;
  late LatLng _posPasajero;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _loading = true;
  bool _cancelando = false;

  String _distanceText = '--';
  String _durationText = '--';

  bool _navegando = false; // ✅ evita doble navegación

  // ✅ handlers para remover SOLO los listeners de esta pantalla
  Function(dynamic)? _hUbicacion;
  Function(dynamic)? _hConductorLlego;

  Function(dynamic)? _hViajeEnCursoWrapper;
  Function(dynamic)? _hViajeEnCursoDirect;

  Function(dynamic)? _hIniciarViaje;
  Function(dynamic)? _hViajeIniciado;

  Function(dynamic)? _hViajeFinalizado;
  Function(dynamic)? _hViajeCancelado;

  @override
  void initState() {
    super.initState();
    _posPasajero = LatLng(widget.latOrigen, widget.lngOrigen);
    _actualizarMarkers();
    _inicializarSocketListeners();
  }

  int? _readViajeId(dynamic data) {
    try {
      final raw = (data is Map)
          ? (data['id_viaje'] ?? data['id_viajes'] ?? data['id'])
          : null;
      if (raw == null) return null;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureLocationPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      debugPrint('⚠️ GPS desactivado.');
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      debugPrint('⚠️ Permisos de ubicación no otorgados.');
      return false;
    }

    return true;
  }

  Future<void> _startSharingPassengerLocation() async {
    if (_passengerId == null) return;

    final ok = await _ensureLocationPermissions();
    if (!ok) return;

    _posSub?.cancel();
    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((p) {
          if (_passengerId == null) return;

          _socket.enviarUbicacion(
            idViaje: widget.idViaje,
            lat: p.latitude,
            lng: p.longitude,
            idUsuario: _passengerId!,
            tipo: 'pasajero',
          );

          if (!mounted) return;
          setState(() => _posPasajero = LatLng(p.latitude, p.longitude));
          _actualizarMarkers();
        });
  }

  void _irAPasajeroViajeEnCurso(
    dynamic data, {
    String source = 'viaje_en_curso',
  }) {
    debugPrint("▶️ [$source] -> $data");

    final idSocket = _readViajeId(data);
    if (idSocket != null && idSocket != widget.idViaje) {
      debugPrint(
        'ℹ️ [$source] de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
      );
      return;
    }

    if (!mounted || _navegando) return;
    _navegando = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('▶️ El viaje comenzó'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PasajeroViajeEnCursoScreen(
          idViaje: widget.idViaje,
          latDestino: widget.latDestino,
          lngDestino: widget.lngDestino,
          direccionOrigen: widget.direccionOrigen,
          direccionDestino: widget.direccionDestino,
          latConductorInicial: _posConductor?.latitude,
          lngConductorInicial: _posConductor?.longitude,
        ),
      ),
    );
  }

  Future<void> _inicializarSocketListeners() async {
    _passengerId = await UserPreferences.getIdUsuario();
    final idUsuario = _passengerId;

    if (idUsuario == null) {
      debugPrint("⚠️ id_usuario es null. No se puede registrar en socket.");
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!_socket.isConnected) {
      await _socket.connect();
      debugPrint("🔌 Socket conectado (ViajeAsignadoScreen)");
    }

    await _socket.emitirConexionUsuario(idUsuario, 'pasajero');

    await _socket.unirseAViaje(
      idViaje: widget.idViaje,
      userId: idUsuario,
      tipo: 'pasajero',
    );

    await _startSharingPassengerLocation();

    // -------------------------
    // ✅ Ubicación en tiempo real
    // -------------------------
    _hUbicacion = _socket.onUbicacionEnTiempoReal((data) async {
      debugPrint("📍 UBICACIÓN EN TIEMPO REAL → $data");
      try {
        if (data is! Map) return;
        if (data['tipo'] != 'conductor') return;

        final lat = double.tryParse(data["lat"].toString());
        final lng = double.tryParse(data["lng"].toString());
        if (lat == null || lng == null) return;

        _posConductor = LatLng(lat, lng);

        if (!mounted) return;
        _actualizarMarkers();
        await _drawRoute();
        if (_posConductor != null) _moverCamara(_posConductor!);
      } catch (e) {
        debugPrint("❌ Error procesando ubicación del conductor: $e");
      }
    });

    _hConductorLlego = _socket.onConductorLlegoEncuentro((data) {
      debugPrint("🚕 Conductor llegó al punto de encuentro → $data");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚕 El conductor llegó al punto de encuentro'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    });

    // ✅ Wrapper
    _hViajeEnCursoWrapper = _socket.onViajeEnCurso(
      (data) =>
          _irAPasajeroViajeEnCurso(data, source: 'wrapper:onViajeEnCurso'),
    );

    // ✅ Directos / alias
    _hViajeEnCursoDirect = _socket.on(
      'viaje_en_curso',
      (data) => _irAPasajeroViajeEnCurso(data, source: 'socket:viaje_en_curso'),
    );
    _hIniciarViaje = _socket.on(
      'iniciar_viaje',
      (data) => _irAPasajeroViajeEnCurso(data, source: 'socket:iniciar_viaje'),
    );
    _hViajeIniciado = _socket.on(
      'viaje_iniciado',
      (data) => _irAPasajeroViajeEnCurso(data, source: 'socket:viaje_iniciado'),
    );

    _hViajeFinalizado = _socket.onViajeFinalizado((data) {
      debugPrint("✅ Viaje finalizado → $data");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Viaje finalizado'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    });

    _hViajeCancelado = _socket.onViajeCancelado((data) {
      debugPrint("❌ Viaje cancelado → $data");

      final idSocket = _readViajeId(data);
      if (idSocket != null && idSocket != widget.idViaje) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ El viaje fue cancelado'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    });

    if (mounted) setState(() => _loading = false);
  }

  void _actualizarMarkers() {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('pasajero'),
        position: _posPasajero,
        infoWindow: const InfoWindow(title: 'Vos'),
      ),
    );

    if (_posConductor != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: _posConductor!,
          infoWindow: const InfoWindow(title: 'Conductor'),
        ),
      );
    }

    if (!mounted) return;
    setState(() => _markers = markers);
  }

  Future<void> _drawRoute() async {
    if (_posConductor == null) return;

    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return;

      final origin = '${_posConductor!.latitude},${_posConductor!.longitude}';
      final dest = '${_posPasajero.latitude},${_posPasajero.longitude}';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&key=$apiKey',
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final jsonData = json.decode(resp.body);
      final routes = jsonData['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final leg = routes[0]['legs'][0];
      final distance = leg['distance']?['text']?.toString() ?? '--';
      final duration = leg['duration']?['text']?.toString() ?? '--';

      if (!mounted) return;
      setState(() {
        _distanceText = distance;
        _durationText = duration;
      });

      final points = routes[0]['overview_polyline']?['points'];
      if (points == null) return;

      final decoded = _decodePolyline(points.toString());

      if (!mounted) return;
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: decoded,
            width: 5,
          ),
        };
      });
    } catch (e) {
      debugPrint('❌ Error _drawRoute(): $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  void _moverCamara(LatLng pos) {
    _mapCtrl?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viaje asignado')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _posConductor ?? _posPasajero,
                      zoom: 15,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (c) => _mapCtrl = c,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place_outlined),
                              const SizedBox(width: 8),
                              Expanded(child: Text(widget.direccionOrigen)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.flag_outlined),
                              const SizedBox(width: 8),
                              Expanded(child: Text(widget.direccionDestino)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.route_outlined),
                              const SizedBox(width: 8),
                              Text('Distancia: $_distanceText'),
                              const SizedBox(width: 14),
                              Text('Tiempo: $_durationText'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.attach_money),
                              const SizedBox(width: 8),
                              Text(
                                'Precio final: ${widget.precioFinal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _cancelando || _passengerId == null
                                ? null
                                : () async {
                                    setState(() => _cancelando = true);
                                    try {
                                      final ok = await _api.cancelarViaje(
                                        idViaje: widget.idViaje,
                                        idUsuario: _passengerId!,
                                        tipo: 'pasajero',
                                      );
                                      if (!ok && mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Error al cancelar el viaje',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Error al cancelar: $e');
                                    } finally {
                                      if (mounted) {
                                        setState(() => _cancelando = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _cancelando
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Cancelar viaje"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();

    // ✅ remover SOLO listeners de esta pantalla
    _socket.off('ubicacion_en_tiempo_real', _hUbicacion);
    _socket.off('conductor_llego_encuentro', _hConductorLlego);

    _socket.off('viaje_en_curso', _hViajeEnCursoWrapper);
    _socket.off('viaje_en_curso', _hViajeEnCursoDirect);

    _socket.off('iniciar_viaje', _hIniciarViaje);
    _socket.off('viaje_iniciado', _hViajeIniciado);

    _socket.off('viaje_finalizado', _hViajeFinalizado);
    _socket.off('viaje_cancelado', _hViajeCancelado);

    super.dispose();
  }
}
