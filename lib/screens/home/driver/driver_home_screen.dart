import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/socket_service.dart';
import '../../../services/api_service.dart';
import '../../../services/user_preferences.dart';

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

  IncomingRide? _incomingRide;

  double _todayTotal = 0.0;

  bool _listening = false;
  bool _accepted = false;
  bool _loading = false;
  bool _isOnline = false;

  late AnimationController _islandPulse;

  @override
  void initState() {
    super.initState();
    _islandPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initDriverHome();
  }

  Future<void> _initDriverHome() async {
    final isDriver = await _checkRoleAccess();
    if (!mounted || !isDriver) return;

    await _initIcons();
    await _initLocation();
    await _loadTodayTotal();
  }

  Future<bool> _checkRoleAccess() async {
    try {
      final user = await UserPreferences.getUser();
      final rawRole = user?['id_rol'];
      final int roleId = rawRole is String
          ? int.tryParse(rawRole) ?? 0
          : rawRole is int
          ? rawRole
          : 0;

      if (!mounted) return false;

      if (roleId != 3) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error al verificar rol: $e');
      if (!mounted) return false;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      return false;
    }
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _islandPulse.dispose();
    _socket.off('viaje_creado');
    _socket.off('viaje_finalizado');
    super.dispose();
  }

  Future<void> _initIcons() async {
    _iconDriver = await _createBitmapDescriptorFromAsset(
      'assets/images/app_icon.png',
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
        _showSnack('Activa los servicios de ubicación.');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showSnack('Permiso de ubicación denegado permanentemente.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _driverLocation = LatLng(pos.latitude, pos.longitude);
      _addDriverMarker();

      setState(() {});
    } catch (e) {
      debugPrint('Error init location: $e');
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
    _socket.on('viaje_creado', (data) async {
      try {
        final ride = IncomingRide.fromSocket(data);
        setState(() {
          _incomingRide = ride;
          _accepted = false;
        });
        await _addPassengerMarker(ride);
        await _fitMapToDriverAndPassenger();
      } catch (e) {
        debugPrint('Error viaje_creado: $e');
      }
    });

    _socket.on('viaje_finalizado', (data) async {
      try {
        final amount = (data?['valor'] as num?)?.toDouble() ?? 0.0;
        await _addToTodayTotal(amount);
      } catch (e) {
        debugPrint('Error viaje_finalizado: $e');
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

    await _mapCtrl!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ),
    );
  }

  Future<void> _loadTodayTotal() async {
    try {
      final resp = await _api.getTodayEarnings();
      setState(() => _todayTotal = resp ?? 0.0);
    } catch (e) {
      setState(() => _todayTotal = 0.0);
    }
  }

  Future<void> _addToTodayTotal(double amount) async {
    setState(() => _todayTotal += amount);
    try {
      await _api.addEarning(amount);
    } catch (_) {}
  }

  Future<void> _goOnline() async {
    try {
      final user = await UserPreferences.getUser();
      final idUsuario = user?['id_usuario'];

      if (idUsuario == null) {
        _showSnack('No se encontró información del usuario.');
        return;
      }

      await _socket.connect();

      await _socket.registrarUsuario(idUsuario: idUsuario, tipo: 'conductor');

      final ok = await _api.cambiarEstadoConductor(
        idConductor: idUsuario,
        conectado: true,
      );

      if (!ok) {
        _showSnack('No se pudo actualizar el estado en el servidor.');
      }

      if (!_listening) {
        await _initSocketListeners();
      }

      if (!mounted) return;

      setState(() => _isOnline = true);

      _showSnack('Estás conectado y disponible para recibir viajes.');
    } catch (e) {
      _showSnack('Error al conectarse: $e');
    }
  }

  Future<void> _goOffline() async {
    try {
      final user = await UserPreferences.getUser();
      final idUsuario = user?['id_usuario'];

      if (idUsuario != null) {
        await _api.cambiarEstadoConductor(
          idConductor: idUsuario,
          conectado: false,
        );

        await _socket.notificarDesconexionUsuario(
          idUsuario: idUsuario,
          tipo: 'conductor',
        );
      }

      _socket.off('viaje_creado');
      _socket.off('viaje_finalizado');

      if (!mounted) return;

      setState(() {
        _isOnline = false;
        _incomingRide = null;
        _accepted = false;
      });

      _showSnack('Estás desconectado. Ya no recibirás viajes.');
    } catch (e) {
      _showSnack('Error al desconectarse: $e');
    }
  }

  Future<void> _logout() async {
    await UserPreferences.fullLogout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Panel Chofer'),
        actions: [
          TextButton(
            onPressed: _isOnline ? _goOffline : _goOnline,
            child: Text(
              _isOnline ? 'Desconectarse' : 'Conectarse',
              style: TextStyle(
                color: _isOnline ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
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

                // Recaudación arriba
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _islandPulse,
                      builder: (_, __) {
                        final alpha = 0.85 + 0.15 * _islandPulse.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(alpha),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
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
                                    '\$${_todayTotal.toStringAsFixed(2)}',
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

                // Panel de viaje entrante
                if (_incomingRide != null)
                  Positioned(
                    bottom: 18,
                    left: 12,
                    right: 12,
                    child: _buildIncomingRideCard(),
                  ),
              ],
            ),
    );
  }

  Widget _buildIncomingRideCard() {
    final r = _incomingRide!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                '\$${r.valor.toStringAsFixed(2)}',
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
                    onPressed: _accepted ? null : () => _acceptRide(),
                    icon: _loading
                        ? const CircularProgressIndicator()
                        : const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 36,
                          ),
                  ),
                  IconButton(
                    onPressed: _accepted ? null : () => _rejectRide(),
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 36),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _acceptRide() async {
    if (_incomingRide == null) return;
    setState(() => _loading = true);

    try {
      final user = await UserPreferences.getUser();
      final driverId = user?['id_usuario'];

      if (driverId == null) {
        _showSnack('ID de conductor no encontrado.');
        return;
      }

      final ok = await _api.acceptRide(_incomingRide!.idViajes, driverId);

      if (ok) {
        _socket.emit('viaje_aceptado', {
          'id_viajes': _incomingRide!.idViajes,
          'id_conductor': driverId,
        });

        setState(() => _accepted = true);
      }
    } catch (e) {
      _showSnack('Error al aceptar viaje: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectRide() async {
    if (_incomingRide == null) return;

    _socket.emit('viaje_rechazado', {'id_viajes': _incomingRide!.idViajes});

    setState(() => _incomingRide = null);

    _showSnack('Viaje rechazado.');
  }
}

// -------------------------------------------------------
// MODELO DE VIAJE
// -------------------------------------------------------
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
    final data = json is String ? jsonDecode(json) : json;

    return IncomingRide(
      idViajes: int.parse(data['id_viajes'].toString()),
      idPasajero: int.parse(data['id_pasajero'].toString()),
      idConductor: data['id_conductor'] != null
          ? int.parse(data['id_conductor'].toString())
          : null,
      direccionDesde: data['direccion_desde'] ?? '',
      latDesde: (data['lat_desde'] as num).toDouble(),
      lonDesde: (data['lon_desde'] as num).toDouble(),
      direccionHasta: data['direccion_hasta'] ?? '',
      latHasta: (data['lat_hasta'] as num).toDouble(),
      lonHasta: (data['lon_hasta'] as num).toDouble(),
      horaInicio: data['hora_inicio'] != null
          ? DateTime.parse(data['hora_inicio'])
          : null,
      horaFin: data['hora_fin'] != null
          ? DateTime.parse(data['hora_fin'])
          : null,
      valor: (data['valor'] as num).toDouble(),
      idEstado: int.parse(data['id_estado'].toString()),
    );
  }
}
