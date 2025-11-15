// driver_home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/user_preferences.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with TickerProviderStateMixin {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();

  GoogleMapController? _mapCtrl;
  LatLng? _driverLocation;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _iconDriver;
  BitmapDescriptor? _iconPassenger;

  // Incoming ride model (la estructura que proveíste)
  IncomingRide? _incomingRide;

  // Recaudación del día (se actualiza en tiempo real)
  double _todayTotal = 0.0;

  // Estado UI
  bool _listening = false;
  bool _accepted = false;
  bool _loading = false;

  late AnimationController _islandPulse;

  @override
  void initState() {
    super.initState();
    _islandPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initIcons();
    _initLocation();
    _initSocketListeners();
    _loadTodayTotal();
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _islandPulse.dispose();
    _socket.off('nuevo_viaje');
    _socket.off('viaje_aceptado');
    _socket.off('viaje_cancelado');
    super.dispose();
  }

  Future<void> _initIcons() async {
    _iconDriver = await _createBitmapDescriptorFromAsset(
      'assets/images/taxi_icon.png',
      96,
    );
    _iconPassenger = await _createBitmapDescriptorFromAsset(
      'assets/images/pin_origen.png',
      80,
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

  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activá los servicios de ubicación.')),
        );
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado permanentemente.'),
          ),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _driverLocation = LatLng(pos.latitude, pos.longitude);
      _addDriverMarker();
      setState(() {});
    } catch (e) {
      debugPrint('Error init location driver: $e');
    }
  }

  void _addDriverMarker() {
    if (_driverLocation == null || _iconDriver == null) return;
    final m = Marker(
      markerId: const MarkerId('driver'),
      position: _driverLocation!,
      icon: _iconDriver!,
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(m);
    });
  }

  Future<void> _initSocketListeners() async {
    // Escuchar evento enviado cuando un pasajero crea viaje
    // En tu flujo previo: emit 'viaje_creado'
    _socket.on('viaje_creado', (data) async {
      try {
        debugPrint('socket viaje_creado: $data');
        final ride = IncomingRide.fromSocket(data);
        // Mostrar en UI
        setState(() {
          _incomingRide = ride;
          _accepted = false;
        });
        // Agregar marker de origen del pasajero
        _addPassengerMarker(ride);
        // Ajustar cámara para ver driver + origen del pasajero
        await _fitMapToDriverAndPassenger();
      } catch (e) {
        debugPrint('Error procesando viaje_creado: $e');
      }
    });

    // Escuchar cuando un viaje finaliza (para actualizar recaudación en tiempo real)
    _socket.on('viaje_finalizado', (data) async {
      try {
        debugPrint('socket viaje_finalizado: $data');
        final amount = (data?['valor'] is num)
            ? (data['valor'] as num).toDouble()
            : 0.0;
        await _addToTodayTotal(amount);
      } catch (e) {
        debugPrint('Error viaje_finalizado socket: $e');
      }
    });

    setState(() => _listening = true);
  }

  Future<void> _addPassengerMarker(IncomingRide ride) async {
    final mk = Marker(
      markerId: MarkerId('passenger_${ride.idViajes}'),
      position: LatLng(ride.latDesde, ride.lonDesde),
      icon:
          _iconPassenger ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: 'Origen pasajero',
        snippet: ride.direccionDesde,
      ),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId.value.startsWith('passenger_'));
      _markers.add(mk);
    });
  }

  Future<void> _fitMapToDriverAndPassenger() async {
    if (_mapCtrl == null || _driverLocation == null || _incomingRide == null)
      return;
    final p = LatLng(_incomingRide!.latDesde, _incomingRide!.lonDesde);
    final sw = LatLng(
      _driverLocation!.latitude < p.latitude
          ? _driverLocation!.latitude
          : p.latitude,
      _driverLocation!.longitude < p.longitude
          ? _driverLocation!.longitude
          : p.longitude,
    );
    final ne = LatLng(
      _driverLocation!.latitude > p.latitude
          ? _driverLocation!.latitude
          : p.latitude,
      _driverLocation!.longitude > p.longitude
          ? _driverLocation!.longitude
          : p.longitude,
    );
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _loadTodayTotal() async {
    try {
      // Intenta cargar desde backend (si existe) - si no la API devuelve 0
      final resp = await _api
          .getTodayEarnings(); // Implementá este método en ApiService
      setState(() {
        _todayTotal = resp ?? 0.0;
      });
    } catch (e) {
      debugPrint('Error cargando recaudación: $e');
      setState(() => _todayTotal = 0.0);
    }
  }

  Future<void> _addToTodayTotal(double amount) async {
    setState(() => _todayTotal += amount);
    try {
      await _api.addEarning(amount); // Persiste en backend
    } catch (e) {
      debugPrint('Error guardando recaudación en backend: $e');
    }
  }

  // Aceptar viaje
  Future<void> _acceptRide() async {
    if (_incomingRide == null) return;
    setState(() => _loading = true);
    try {
      final user = await UserPreferences.getUser();
      final driverId = user?['id_usuario'];
      if (driverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró id de conductor en preferencias.'),
          ),
        );
        setState(() => _loading = false);
        return;
      }

      // Llamada al backend para asignar conductor
      final res = await _api.acceptRide(_incomingRide!.idViajes, driverId);
      if (res == true) {
        // Notificar via socket que aceptaste
        _socket.emit('viaje_aceptado', {
          'id_viajes': _incomingRide!.idViajes,
          'id_conductor': driverId,
        });

        setState(() {
          _accepted = true;
        });

        // Opción: abrir pantalla para conducir / paso siguiente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje aceptado. Dirigiéndote al origen...'),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al aceptar viaje')));
      }
    } catch (e) {
      debugPrint('Error acceptRide: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al aceptar viaje: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectRide() async {
    if (_incomingRide == null) return;
    _socket.emit('viaje_rechazado', {'id_viajes': _incomingRide!.idViajes});
    setState(() => _incomingRide = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Viaje rechazado')));
  }

  String _formatCurrency(double v) {
    // Simple formatting. Ajustá a locales si querés
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Panel Chofer')),
      body: _driverLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (ctl) => _mapCtrl = ctl,
                  initialCameraPosition: CameraPosition(
                    target: _driverLocation!,
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                ),

                // Isla superior: recaudación del día
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _islandPulse,
                      builder: (_, __) {
                        final alpha = (0.85 + 0.15 * _islandPulse.value);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(alpha),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 8),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_money,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Recaudación hoy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(_todayTotal),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Panel inferior tipo "card" para el viaje entrante
                if (_incomingRide != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 18,
                    child: _buildIncomingRideCard(),
                  ),
              ],
            ),
    );
  }

  Widget _buildIncomingRideCard() {
    final r = _incomingRide!;
    return GestureDetector(
      onTap: () {
        // Expandir o mostrar detalles si quisieras
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con estado
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _accepted ? Colors.green : Colors.orange,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Solicitud de viaje #${r.idViajes}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _formatCurrency(r.valor),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Direcciones
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Desde',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.68,
                      child: Text(
                        r.direccionDesde,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hacia',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.68,
                      child: Text(
                        r.direccionHasta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  children: [
                    IconButton(
                      onPressed: _accepted ? null : _acceptRide,
                      icon: _loading
                          ? const CircularProgressIndicator()
                          : const Icon(
                              Icons.check_circle,
                              size: 36,
                              color: Colors.green,
                            ),
                    ),
                    IconButton(
                      onPressed: _accepted ? null : _rejectRide,
                      icon: const Icon(
                        Icons.cancel,
                        size: 36,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Info extra
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Duración estimada: -- min',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'Distancia: -- km',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  _accepted ? 'ACEPTADO' : 'PENDIENTE',
                  style: TextStyle(
                    color: _accepted ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Modelo ligero del JSON que enviaste
class IncomingRide {
  final int idViajes;
  final int idPasajero;
  final int? idConductor;
  final String direccionDesde;
  final double latDesde;
  final double lonDesde;
  final String direccionHasta;
  final double latHasta;
  final double lonHasta;
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final double valor;
  final int idEstado;

  IncomingRide({
    required this.idViajes,
    required this.idPasajero,
    required this.idConductor,
    required this.direccionDesde,
    required this.latDesde,
    required this.lonDesde,
    required this.direccionHasta,
    required this.latHasta,
    required this.lonHasta,
    required this.horaInicio,
    required this.horaFin,
    required this.valor,
    required this.idEstado,
  });

  factory IncomingRide.fromSocket(dynamic json) {
    // Asegurate de que los nombres coincidan con lo que emite tu socket
    final parsed = json is String ? jsonDecode(json) : json;
    return IncomingRide(
      idViajes:
          (parsed['id_viajes'] ??
                  parsed['id_viajes'] ??
                  parsed['id_viajes'] ??
                  parsed['id_viajes'])
              is num
          ? (parsed['id_viajes'] as num).toInt()
          : int.parse(parsed['id_viajes'].toString()),
      idPasajero: (parsed['id_pasajero'] ?? parsed['id_pasajero']) is num
          ? (parsed['id_pasajero'] as num).toInt()
          : int.parse(parsed['id_pasajero'].toString()),
      idConductor: parsed['id_conductor'] is num
          ? (parsed['id_conductor'] as num).toInt()
          : null,
      direccionDesde:
          parsed['direccion_desde'] ?? parsed['direccionDesde'] ?? '',
      latDesde: (parsed['lat_desde'] as num).toDouble(),
      lonDesde: (parsed['lon_desde'] as num).toDouble(),
      direccionHasta:
          parsed['direccion_hasta'] ?? parsed['direccionHasta'] ?? '',
      latHasta: (parsed['lat_hasta'] as num).toDouble(),
      lonHasta: (parsed['lon_hasta'] as num).toDouble(),
      horaInicio: parsed['hora_inicio'] != null
          ? DateTime.parse(parsed['hora_inicio'].toString())
          : null,
      horaFin: parsed['hora_fin'] != null
          ? DateTime.parse(parsed['hora_fin'].toString())
          : null,
      valor: (parsed['valor'] as num).toDouble(),
      idEstado: (parsed['id_estado'] as num).toInt(),
    );
  }
}
