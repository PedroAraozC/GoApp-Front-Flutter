// lib/screens/home/driver/driver_en_camino_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:taxi_tuc/screens/home/driver/driver_viaje_en_curso_screen.dart';
import 'package:taxi_tuc/services/socket_service.dart';

import '../../../services/api_service.dart';
import 'driver_home_screen.dart'; // Para usar IncomingRide

class DriverEnCaminoScreen extends StatefulWidget {
  final IncomingRide ride; // viaje aceptado

  const DriverEnCaminoScreen({super.key, required this.ride});

  @override
  State<DriverEnCaminoScreen> createState() => _DriverEnCaminoScreenState();
}

class _DriverEnCaminoScreenState extends State<DriverEnCaminoScreen> {
  final ApiService _api = ApiService();

  GoogleMapController? _mapCtrl;
  LatLng? _driverPos;
  late LatLng _passengerPos;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  StreamSubscription<Position>? _positionSub;

  String _distanceText = '--';
  String _durationText = '--';
  bool _startingTrip = false;

  @override
  void initState() {
    super.initState();
    _passengerPos = LatLng(widget.ride.latDesde, widget.ride.lonDesde);
    _initLocationAndTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndTracking() async {
    final hasPerm = await _checkLocationPermissions();
    if (!hasPerm) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _driverPos = LatLng(pos.latitude, pos.longitude);

    _setMarkers();
    _moveCameraInitial();

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5, // metros
          ),
        ).listen((p) {
          _driverPos = LatLng(p.latitude, p.longitude);
          _setMarkers();
          _buildRoute();
          _enviarUbicacionAlPasajero(p.latitude, p.longitude);
        });
    await _buildRoute();
  }

  Future<bool> _checkLocationPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _msg('Activá los servicios de ubicación.');
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever ||
        p == LocationPermission.denied) {
      _msg('No tenés permisos de ubicación.');
      return false;
    }
    return true;
  }

  void _setMarkers() {
    if (_driverPos == null) return;

    final driverMarker = Marker(
      markerId: const MarkerId('driver'),
      position: _driverPos!,
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );

    final passengerMarker = Marker(
      markerId: const MarkerId('passenger'),
      position: _passengerPos,
      infoWindow: InfoWindow(
        title: 'Pasajero',
        snippet: widget.ride.direccionDesde,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      _markers
        ..clear()
        ..add(driverMarker)
        ..add(passengerMarker);
    });
  }

  Future<void> _moveCameraInitial() async {
    if (_mapCtrl == null || _driverPos == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _driverPos!.latitude < _passengerPos.latitude
            ? _driverPos!.latitude
            : _passengerPos.latitude,
        _driverPos!.longitude < _passengerPos.longitude
            ? _driverPos!.longitude
            : _passengerPos.longitude,
      ),
      northeast: LatLng(
        _driverPos!.latitude > _passengerPos.latitude
            ? _driverPos!.latitude
            : _passengerPos.latitude,
        _driverPos!.longitude > _passengerPos.longitude
            ? _driverPos!.longitude
            : _passengerPos.longitude,
      ),
    );

    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ================= DIRECTIONS API =================
  Future<void> _buildRoute() async {
    if (_driverPos == null) return;

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null) {
      debugPrint('❌ GOOGLE_API_KEY no configurada en .env');
      return;
    }

    final origin = '${_driverPos!.latitude},${_driverPos!.longitude}';
    final destination = '${_passengerPos.latitude},${_passengerPos.longitude}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination&mode=driving&key=$apiKey',
    );

    try {
      final resp = await http.get(url);
      final data = jsonDecode(resp.body);

      if (data['status'] != 'OK') {
        debugPrint('❌ Directions status: ${data['status']}');
        return;
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];

      final polyline = route['overview_polyline']['points'];
      final points = _decodePolyline(polyline);

      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('driver_to_passenger'),
              points: points,
              width: 6,
              color: Colors.blue,
            ),
          );
        _distanceText = leg['distance']['text'] ?? '--';
        _durationText = leg['duration']['text'] ?? '--';
      });

      await _fitPolyline(points);
    } catch (e) {
      debugPrint('❌ Error Directions: $e');
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
    if (_mapCtrl == null || points.isEmpty) return;
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

    await _mapCtrl!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // ================= INICIAR VIAJE =================
  // ================= INICIAR VIAJE =================
  Future<void> _onIniciarViaje() async {
    setState(() => _startingTrip = true);
    try {
      final ok = await _api.comenzarViaje(widget.ride.idViajes);
      if (!ok) {
        _msg('No se pudo marcar el viaje como "en curso".');
        return;
      }

      _msg('Viaje iniciado. Ahora vas con el pasajero. 🚕');

      if (!mounted) return;

      // 👉 Navegamos a la pantalla de viaje en curso
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DriverViajeEnCursoScreen(ride: widget.ride),
        ),
      );

      if (!mounted) return;

      // Si desde la pantalla de viaje en curso devolvemos true,
      // volvemos al Home avisando que se inició el viaje y se completó el flujo.
      Navigator.pop(context, result == true);
    } catch (e) {
      debugPrint('Error comenzar viaje: $e');
      _msg('Error al iniciar viaje: $e');
    } finally {
      if (mounted) setState(() => _startingTrip = false);
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('En camino al pasajero')),
      body: _driverPos == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _driverPos!,
                    zoom: 14,
                  ),
                  onMapCreated: (ctrl) {
                    _mapCtrl = ctrl;
                    _moveCameraInitial();
                  },
                  myLocationEnabled: true,
                  markers: _markers,
                  polylines: _polylines,
                ),

                // Panel superior con info de tiempo/distancia
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: cs.surface,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hacia el pasajero',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.ride.direccionDesde,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 18),
                              const SizedBox(width: 4),
                              Text('$_durationText'),
                              const SizedBox(width: 16),
                              const Icon(Icons.route, size: 18),
                              const SizedBox(width: 4),
                              Text('$_distanceText'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botón inferior: Iniciar viaje (cuando ya llegó)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: FilledButton.icon(
                    onPressed: _startingTrip ? null : _onIniciarViaje,
                    icon: _startingTrip
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flag),
                    label: const Text('Llegué al pasajero / Iniciar viaje'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _enviarUbicacionAlPasajero(double lat, double lng) {
    final ride = widget.ride;

    // Necesitamos el ID del pasajero
    final idPasajero = ride.idPasajero; // debes asegurarte que ride trae esto

    SocketService.instance.emit("ubicacion_conductor", {
      "id_usuario": ride.idConductor, // id del conductor (usuario)
      "id_pasajero": idPasajero,
      "lat": lat,
      "lng": lng,
      "id_viajes": ride.idViajes,
    });

    debugPrint("📤 Enviada ubicación del chofer → $lat, $lng");
  }
}
