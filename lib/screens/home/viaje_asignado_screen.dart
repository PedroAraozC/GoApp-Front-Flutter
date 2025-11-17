import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

  GoogleMapController? _mapController;

  LatLng? _posPasajero;
  LatLng? _posConductor;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

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

    // Registrar usuario en socket
    if (idUsuario == null) {
      debugPrint("⚠️ id_usuario es null. No se enviará usuario_conectado.");
      return;
    }

    await _socket.emitirConexionUsuario(idUsuario, 'pasajero');

    // 🔊 ESCUCHAR UBICACIÓN DEL CONDUCTOR
    _socket.on('ubicacion_conductor', (data) {
      try {
        debugPrint("📍 Ubicación conductor recibida → $data");

        final lat = double.tryParse(data["lat"].toString());
        final lng = double.tryParse(data["lng"].toString());

        if (lat == null || lng == null) return;

        setState(() {
          _posConductor = LatLng(lat, lng);
        });

        _actualizarMarkers();
        _drawRoute(); // 👈 NUEVO
        _moverCamara(_posConductor!);
      } catch (e) {
        debugPrint("❌ Error procesando ubicación del conductor: $e");
      }
    });
  }

  // ---------------------------------------------------------------
  // MAPA
  // ---------------------------------------------------------------
  void _actualizarMarkers() {
    _markers.clear();

    if (_posPasajero != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("pasajero"),
          position: _posPasajero!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    if (_posConductor != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("conductor"),
          position: _posConductor!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),
      );
    }
  }

  void _moverCamara(LatLng posicion) {
    if (_mapController == null) return;

    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(posicion, 15));
  }

  @override
  void dispose() {
    _socket.off('ubicacion_conductor');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu viaje')),
      body: Column(
        children: [
          // ---------------------------------------
          // MAPA
          // ---------------------------------------
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-26.8241, -65.2226),
                zoom: 13,
              ),
              markers: _markers,
              polylines: _polylines, // 👈 AGREGAR
              onMapCreated: (controller) async {
                _mapController = controller;

                // Obtener ubicación del pasajero (último punto)
                final prefs = await SharedPreferences.getInstance();
                final lat = prefs.getDouble('ultimo_lat');
                final lng = prefs.getDouble('ultimo_lng');

                if (lat != null && lng != null) {
                  _posPasajero = LatLng(lat, lng);
                  _actualizarMarkers();
                  _moverCamara(_posPasajero!);
                }
              },
            ),
          ),

          // ---------------------------------------
          // DETALLES DEL VIAJE
          // ---------------------------------------
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'El conductor está en camino 🚕',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // Dirección origen
                  Row(
                    children: [
                      const Icon(Icons.my_location),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.direccionOrigen)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dirección destino
                  Row(
                    children: [
                      const Icon(Icons.location_on),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.direccionDestino)),
                    ],
                  ),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: _cancelando
                        ? null
                        : () => _api.cancelarViaje(widget.idViaje),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text("Cancelar viaje"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _drawRoute() async {
    if (_posConductor == null || _posPasajero == null) return;

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];

    final origin = '${_posConductor!.latitude},${_posConductor!.longitude}';
    final dest = '${_posPasajero!.latitude},${_posPasajero!.longitude}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$dest&mode=driving&key=$apiKey',
    );

    try {
      final resp = await http.get(url);
      final data = jsonDecode(resp.body);

      if (data['status'] != 'OK') {
        debugPrint('❌ Directions status: ${data['status']}');
        return;
      }

      final polyline = data['routes'][0]['overview_polyline']['points'];
      final points = _decodePolyline(polyline);

      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('conductor_pasajero'),
              points: points,
              width: 6,
              color: Colors.blue,
            ),
          );
      });

      _fitPolyline(points);
    } catch (e) {
      debugPrint("❌ Error obteniendo ruta: $e");
    }
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Future<void> _fitPolyline(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }
}
