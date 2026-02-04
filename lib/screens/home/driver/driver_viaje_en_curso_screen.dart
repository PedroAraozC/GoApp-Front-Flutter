// lib/screens/home/driver/driver_viaje_en_curso_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../services/user_preferences.dart';
import '../../../services/earnings_service.dart';

import '../../../services/api_service.dart';
import '../../../services/socket_service.dart';
import 'driver_map_screen.dart'; // IncomingRide

class DriverViajeEnCursoScreen extends StatefulWidget {
  final IncomingRide ride;

  const DriverViajeEnCursoScreen({super.key, required this.ride});

  @override
  State<DriverViajeEnCursoScreen> createState() =>
      _DriverViajeEnCursoScreenState();
}

class _DriverViajeEnCursoScreenState extends State<DriverViajeEnCursoScreen> {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService.instance;

  GoogleMapController? _mapCtrl;
  LatLng? _driverPos;
  late LatLng _destPos;

  int? _driverId;
  bool _socketReady = false;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  StreamSubscription<Position>? _positionSub;

  String _distanceText = '--';
  String _durationText = '--';
  bool _finishingTrip = false;

  // ✅ PINS UNIFICADOS + SOMBRA
  BitmapDescriptor? _iconDriver;
  BitmapDescriptor? _iconTarget; // destino con mismo estilo que pasajero
  BitmapDescriptor? _iconShadow;

  @override
  void initState() {
    super.initState();
    _destPos = LatLng(widget.ride.latHasta, widget.ride.lonHasta);
    _init();
  }

  Future<void> _init() async {
    await _initIcons();
    await _resolveDriverId();
    await _inicializarSocket();
    await _initLocationAndTracking();
  }

  Future<void> _initIcons() async {
    _iconDriver = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_online.png',
      80,
    );
    _iconTarget = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_passenger.png',
      76,
    );
    _iconShadow = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_shadow.png',
      60,
    );
  }

  Future<BitmapDescriptor> _createBitmapDescriptorFromAsset(
    String path,
    int size,
  ) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _resolveDriverId() async {
    final fromRide = widget.ride.idConductor;
    final fromPrefs = await UserPreferences.getIdUsuario();
    _driverId = fromRide ?? fromPrefs;

    debugPrint(
      '🧩 [DriverViajeEnCurso] idConductor ride=$fromRide prefs=$fromPrefs -> usando=$_driverId',
    );
  }

  Future<void> _inicializarSocket() async {
    if (_driverId == null) {
      debugPrint(
        '⚠️ No hay idConductor (ride/prefs). No se puede unir al viaje',
      );
      return;
    }

    await _socket.unirseAViaje(
      idViaje: widget.ride.idViajes,
      userId: _driverId!,
      tipo: 'conductor',
    );

    if (mounted) setState(() => _socketReady = true);
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
    await _moveCameraInitial();

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen((p) {
          _driverPos = LatLng(p.latitude, p.longitude);
          _setMarkers();
          _buildRoute();
          _enviarUbicacion(p.latitude, p.longitude);
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

    final next = <Marker>{};

    // ✅ Sombra + pin conductor
    if (_iconShadow != null) {
      next.add(
        Marker(
          markerId: const MarkerId('driver_shadow'),
          position: _driverPos!,
          icon: _iconShadow!,
          anchor: const Offset(0.5, 0.5),
          zIndex: 0,
          flat: true,
        ),
      );
    }

    next.add(
      Marker(
        markerId: const MarkerId('driver_pin'),
        position: _driverPos!,
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
        icon:
            _iconDriver ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        anchor: const Offset(0.5, 1.0),
        zIndex: 1,
      ),
    );

    // ✅ Sombra + pin destino (mismo estilo)
    if (_iconShadow != null) {
      next.add(
        Marker(
          markerId: const MarkerId('dest_shadow'),
          position: _destPos,
          icon: _iconShadow!,
          anchor: const Offset(0.5, 0.5),
          zIndex: 0,
          flat: true,
        ),
      );
    }

    next.add(
      Marker(
        markerId: const MarkerId('dest_pin'),
        position: _destPos,
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: widget.ride.direccionHasta,
        ),
        icon:
            _iconTarget ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 1.0),
        zIndex: 1,
      ),
    );

    setState(() {
      _markers
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _moveCameraInitial() async {
    if (_mapCtrl == null || _driverPos == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _driverPos!.latitude < _destPos.latitude
            ? _driverPos!.latitude
            : _destPos.latitude,
        _driverPos!.longitude < _destPos.longitude
            ? _driverPos!.longitude
            : _destPos.longitude,
      ),
      northeast: LatLng(
        _driverPos!.latitude > _destPos.latitude
            ? _driverPos!.latitude
            : _destPos.latitude,
        _driverPos!.longitude > _destPos.longitude
            ? _driverPos!.longitude
            : _destPos.longitude,
      ),
    );

    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // =============== DIRECTIONS API ===============
  Future<void> _buildRoute() async {
    if (_driverPos == null) return;

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null) {
      debugPrint('❌ GOOGLE_API_KEY no configurada en .env');
      return;
    }

    final origin = '${_driverPos!.latitude},${_driverPos!.longitude}';
    final destination = '${_destPos.latitude},${_destPos.longitude}';

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
              polylineId: const PolylineId('route_to_dest'),
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

  // =============== ENVIAR UBICACIÓN ===============
  void _enviarUbicacion(double lat, double lng) {
    if (_driverId == null || !_socketReady) return;

    _socket.enviarUbicacion(
      idViaje: widget.ride.idViajes,
      lat: lat,
      lng: lng,
      idUsuario: _driverId!,
      tipo: 'conductor',
    );

    _api.actualizarUbicacion(
      idViaje: widget.ride.idViajes,
      lat: lat,
      lng: lng,
      idUsuario: _driverId!,
      tipo: 'conductor',
    );
  }

  // =============== FINALIZAR VIAJE ===============
  Future<void> _onFinalizarViaje() async {
    if (_driverId == null) {
      _msg('Error: No se encontró el ID del conductor');
      return;
    }

    setState(() => _finishingTrip = true);
    try {
      final ok = await _api.finalizarViaje(
        idViaje: widget.ride.idViajes,
        idConductor: _driverId!,
      );

      if (!ok) {
        _msg('No se pudo finalizar el viaje.');
        return;
      }

      _msg('Viaje finalizado. ¡Buen trabajo! 🏁');

      if (!mounted) return;

      final idUsuario = await UserPreferences.getIdUsuario();
      if (idUsuario != null) {
        await EarningsService.instance.addEarning(
          idUsuario: idUsuario,
          uniqueId: 'app_${widget.ride.idViajes}',
          idViaje: widget.ride.idViajes,
          monto: widget.ride.valor,
          fecha: DateTime.now(),
          tipo: EarningType.viajeApp,
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error al finalizar viaje: $e');
      _msg('Error al finalizar viaje: $e');
    } finally {
      if (mounted) setState(() => _finishingTrip = false);
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
      appBar: AppBar(title: const Text('Viaje en curso')),
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
                            'Hacia el destino',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.ride.direccionHasta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 18),
                              const SizedBox(width: 4),
                              Text(_durationText),
                              const SizedBox(width: 16),
                              const Icon(Icons.route, size: 18),
                              const SizedBox(width: 4),
                              Text(_distanceText),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: FilledButton.icon(
                    onPressed: _finishingTrip ? null : _onFinalizarViaje,
                    icon: _finishingTrip
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flag),
                    label: const Text('Finalizar viaje'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
