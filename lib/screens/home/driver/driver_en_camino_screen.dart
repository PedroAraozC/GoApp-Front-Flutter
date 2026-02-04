// lib/screens/home/driver/driver_en_camino_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:taxi_tuc/screens/home/driver/driver_viaje_en_curso_screen.dart';
import 'package:taxi_tuc/services/socket_service.dart';
import 'package:taxi_tuc/services/user_preferences.dart';

import '../../../services/api_service.dart';
import 'driver_map_screen.dart'; // Para IncomingRide

class DriverEnCaminoScreen extends StatefulWidget {
  final IncomingRide ride;

  const DriverEnCaminoScreen({super.key, required this.ride});

  @override
  State<DriverEnCaminoScreen> createState() => _DriverEnCaminoScreenState();
}

class _DriverEnCaminoScreenState extends State<DriverEnCaminoScreen> {
  final ApiService _api = ApiService();

  GoogleMapController? _mapCtrl;
  LatLng? _driverPos;
  late LatLng _passengerPos;

  final SocketService _socket = SocketService.instance;

  int? _driverId;
  bool _socketReady = false;

  StreamSubscription<Position>? _positionSub;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _loadingMap = true;
  bool _llegueAlEncuentro = false;
  bool _llegandoEncuentro = false;
  bool _comenzandoViaje = false;

  // UI
  String _distanceText = '--';
  String _durationText = '--';

  // ✅ PINS UNIFICADOS + SOMBRA
  BitmapDescriptor? _iconDriver;
  BitmapDescriptor? _iconPassenger;
  BitmapDescriptor? _iconShadow;

  @override
  void initState() {
    super.initState();
    _passengerPos = LatLng(widget.ride.latDesde, widget.ride.lonDesde);
    _init();
  }

  Future<void> _init() async {
    await _initIcons(); // ✅ primero cargar assets
    await _resolveDriverId();
    await _inicializarSocket();
    _listenPassengerLocation();
    await _initLocationAndTracking();
  }

  Future<void> _initIcons() async {
    // Conductor online (pantalla de viaje => estás activo)
    _iconDriver = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_online.png',
      80,
    );
    // Pasajero
    _iconPassenger = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_passenger.png',
      76,
    );
    // Sombra
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
      '🧩 [DriverEnCamino] idConductor ride=$fromRide prefs=$fromPrefs -> usando=$_driverId',
    );
  }

  void _listenPassengerLocation() {
    _socket.onUbicacionEnTiempoReal((data) async {
      try {
        if (!mounted) return;

        final idViaje = int.tryParse('${data['id_viaje']}') ?? -1;
        if (idViaje != widget.ride.idViajes) return;

        if (data['tipo'] != 'pasajero') return;

        final lat = double.tryParse('${data['lat']}');
        final lng = double.tryParse('${data['lng']}');
        if (lat == null || lng == null) return;

        setState(() {
          _passengerPos = LatLng(lat, lng);
        });

        _setMarkers();
        await _buildRoute();
      } catch (e) {
        debugPrint('❌ Error ubicacion pasajero (driver): $e');
      }
    });
  }

  Future<void> _inicializarSocket() async {
    if (_driverId == null) {
      debugPrint(
        '⚠️ No hay idConductor (ride/prefs). No se puede unir al viaje.',
      );
      return;
    }

    await _socket.emitirConexionUsuario(_driverId!, 'conductor');

    await _socket.unirseAViaje(
      idViaje: widget.ride.idViajes,
      userId: _driverId!,
      tipo: 'conductor',
    );

    if (mounted) setState(() => _socketReady = true);
  }

  @override
  void dispose() {
    _socket.off('ubicacion_en_tiempo_real');
    _positionSub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndTracking() async {
    final hasPerm = await _checkLocationPermissions();
    if (!hasPerm) return;

    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _driverPos = LatLng(current.latitude, current.longitude);

    _setMarkers();
    await _buildRoute();

    if (mounted) setState(() => _loadingMap = false);

    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) async {
          if (!mounted) return;

          _driverPos = LatLng(pos.latitude, pos.longitude);

          _setMarkers();
          await _buildRoute();

          _enviarUbicacionAlPasajero(pos.latitude, pos.longitude);
        });
  }

  Future<bool> _checkLocationPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _msg('Activá el GPS para continuar');
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _msg('Permisos de ubicación no otorgados');
      return false;
    }
    return true;
  }

  void _setMarkers() {
    final markers = <Marker>{};

    // ✅ Pasajero: sombra + pin
    if (_iconShadow != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('passenger_shadow'),
          position: _passengerPos,
          icon: _iconShadow!,
          anchor: const Offset(0.5, 0.5),
          zIndex: 0,
          flat: true,
        ),
      );
    }

    markers.add(
      Marker(
        markerId: const MarkerId('pasajero'),
        position: _passengerPos,
        infoWindow: const InfoWindow(title: 'Pasajero'),
        icon:
            _iconPassenger ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 1.0),
        zIndex: 1,
      ),
    );

    // ✅ Conductor: sombra + pin
    if (_driverPos != null) {
      if (_iconShadow != null) {
        markers.add(
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

      markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: _driverPos!,
          infoWindow: const InfoWindow(title: 'Vos'),
          icon:
              _iconDriver ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          anchor: const Offset(0.5, 1.0),
          zIndex: 1,
        ),
      );
    }

    setState(() => _markers = markers);
  }

  Future<void> _buildRoute() async {
    if (_driverPos == null) return;

    try {
      final apiKey =
          dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return;

      final origin = '${_driverPos!.latitude},${_driverPos!.longitude}';
      final dest = '${_passengerPos.latitude},${_passengerPos.longitude}';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin&destination=$dest&key=$apiKey',
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final jsonData = json.decode(resp.body);
      final routes = jsonData['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final leg = routes[0]['legs'][0];
      final distance = leg['distance']?['text']?.toString() ?? '--';
      final duration = leg['duration']?['text']?.toString() ?? '--';

      setState(() {
        _distanceText = distance;
        _durationText = duration;
      });

      final points = routes[0]['overview_polyline']?['points'];
      if (points == null) return;

      final decoded = _decodePolyline(points.toString());

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: decoded,
            width: 5,
            color: Colors.blue,
          ),
        };
      });
    } catch (e) {
      debugPrint('❌ Error _buildRoute(): $e');
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

  // ================= LLEGAR AL ENCUENTRO =================
  Future<void> _onLlegarEncuentro() async {
    if (_driverId == null) {
      _msg('Error: No se encontró el ID del conductor');
      return;
    }

    setState(() => _llegandoEncuentro = true);
    try {
      final ok = await _api.llegarEncuentro(
        idViaje: widget.ride.idViajes,
        idConductor: _driverId!,
      );

      if (!ok) {
        _msg('No se pudo marcar llegada');
        return;
      }

      setState(() => _llegueAlEncuentro = true);

      _msg('Llegada registrada. Esperando pasajero...');
    } catch (e) {
      debugPrint('❌ Error llegar encuentro: $e');
      _msg('Error al marcar llegada');
    } finally {
      if (mounted) setState(() => _llegandoEncuentro = false);
    }
  }

  // ================= COMENZAR VIAJE =================
  Future<void> _onComenzarViaje() async {
    if (_driverId == null) {
      _msg('Error: No se encontró el ID del conductor');
      return;
    }

    setState(() => _comenzandoViaje = true);
    try {
      final ok = await _api.comenzarViaje(widget.ride.idViajes, _driverId!);

      if (!ok) {
        _msg('No se pudo comenzar el viaje');
        return;
      }

      if (!mounted) return;

      final finished = await Navigator.pushReplacement<bool, bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DriverViajeEnCursoScreen(ride: widget.ride),
        ),
      );

      if (!mounted) return;

      if (finished == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error comenzar viaje: $e');
      _msg('Error al comenzar viaje');
    } finally {
      if (mounted) setState(() => _comenzandoViaje = false);
    }
  }

  // ================= SOCKET + REST: ENVIAR UBICACIÓN =================
  void _enviarUbicacionAlPasajero(double lat, double lng) {
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

    debugPrint("📤 Enviada ubicación del chofer → $lat, $lng");
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('En camino al pasajero')),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loadingMap
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _driverPos ?? _passengerPos,
                      zoom: 15,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (c) => _mapCtrl = c,
                  ),
          ),

          // Tarjeta info
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
                        Expanded(
                          child: Text(
                            widget.ride.direccionDesde,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.route_outlined),
                        const SizedBox(width: 8),
                        Text('Distancia: $_distanceText'),
                        const SizedBox(width: 14),
                        Text('Tiempo: $_durationText'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_llegueAlEncuentro) ...[
                      ElevatedButton(
                        onPressed: _comenzandoViaje ? null : _onComenzarViaje,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _comenzandoViaje
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Iniciar viaje'),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _llegandoEncuentro
                            ? null
                            : _onLlegarEncuentro,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _llegandoEncuentro
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Llegué al punto de encuentro'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
