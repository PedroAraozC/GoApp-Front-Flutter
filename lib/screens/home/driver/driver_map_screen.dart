// lib/screens/home/driver/driver_home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:taxi_tuc/main.dart';
import 'package:taxi_tuc/screens/carnet_conductor/carnet_digital_screen.dart';
import 'package:taxi_tuc/screens/home/driver/driver_perfil_screen.dart';

import '../../../services/socket_service.dart';
import '../../../services/api_service.dart';
import '../../../services/user_preferences.dart';
import '../../../services/taximetro_service.dart';
import 'driver_en_camino_screen.dart';
import './driver_taximetro_screen.dart';
import 'driver_map_screen.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen>
    with TickerProviderStateMixin {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();
  final taximetro = TaximetroService.instance;

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
  bool _isOnline = false; // conectado / desconectado para recibir viajes

  late AnimationController _islandPulse;
  Timer? _taximetroTimer;

  @override
  void initState() {
    super.initState();

    _islandPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initDriverHome();

    _taximetroTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && taximetro.viajeActivo) setState(() {});
    });
  }

  Future<void> _initDriverHome() async {
    final isDriver = await _checkRoleAccess();
    if (!mounted || !isDriver) return;

    await _initIcons();
    await _initLocation();
    await _loadTodayTotal();
  }

  @override
  void dispose() {
    _taximetroTimer?.cancel();
    _mapCtrl?.dispose();
    _islandPulse.dispose();
    _socket.off('viaje_creado');
    _socket.off('viaje_finalizado');
    _socket.off('viaje_cancelado_busqueda');
    super.dispose();
  }

  Future<bool> _checkRoleAccess() async {
    try {
      final user = await UserPreferences.getUser();
      final rawRole = user?['id_rol'];

      final int roleId = rawRole is String
          ? int.tryParse(rawRole) ?? 0
          : (rawRole is int ? rawRole : 0);

      if (!mounted) return false;

      if (roleId != 3) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error al verificar rol: $e');
      if (!mounted) return false;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      return false;
    }
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
        _showSnack('Activá los servicios de ubicación.');
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.deniedForever) {
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
    // viaje creado por pasajero → aparece tarjeta al chofer
    _socket.on('viaje_creado', (data) async {
      try {
        debugPrint('🚕 [Driver] Evento viaje_creado recibido: $data');

        if (data == null) {
          debugPrint('⚠️ [Driver] viaje_creado recibió data null');
          return;
        }

        final ride = IncomingRide.fromSocket(data);
        debugPrint(
          '✅ [Driver] Viaje parseado: ID=${ride.idViajes}, Origen=${ride.direccionDesde}',
        );

        if (!mounted) return;

        setState(() {
          _incomingRide = ride;
          _accepted = false;
        });

        await _addPassengerMarker(ride);
        await _fitMapToDriverAndPassenger();

        _showSnack('Nuevo viaje disponible 🚕');
        debugPrint('✅ [Driver] Tarjeta de viaje mostrada al conductor');
      } catch (e) {
        debugPrint('❌ [Driver] Error procesando viaje_creado: $e');
        debugPrint('❌ [Driver] Stack trace: ${StackTrace.current}');
      }
    });

    // viaje finalizado → actualizar recaudación
    _socket.on('viaje_finalizado', (data) async {
      try {
        debugPrint('socket viaje_finalizado: $data');
        final amount = (data?['precio_final'] is num)
            ? (data['precio_final'] as num).toDouble()
            : (data?['valor'] is num)
            ? (data['valor'] as num).toDouble()
            : 0.0;
        await _addToTodayTotal(amount);
      } catch (e) {
        debugPrint('Error viaje_finalizado socket: $e');
      }
    });

    // viaje cancelado mientras estaba "buscando" → limpiar tarjeta
    _socket.on('viaje_cancelado_busqueda', (data) {
      try {
        debugPrint('socket viaje_cancelado_busqueda: $data');
        final idCancelado =
            data?['id_viajes'] ??
            data?['id_viaje'] ??
            data?['id']; // por las dudas
        if (idCancelado == null || _incomingRide == null) return;

        final idInt = idCancelado is num
            ? idCancelado.toInt()
            : int.tryParse(idCancelado.toString());

        if (idInt == null) return;

        if (_incomingRide!.idViajes == idInt) {
          setState(() {
            _incomingRide = null;
            _accepted = false;
            _polylines.clear();
            _markers.removeWhere(
              (m) => m.markerId.value.startsWith('passenger_'),
            );
          });
          _showSnack('El pasajero canceló el viaje.');
        }
      } catch (e) {
        debugPrint('Error procesando viaje_cancelado_busqueda: $e');
      }
    });

    // viaje tomado por otro conductor → limpiar tarjeta
    _socket.onViajeTomado((data) {
      try {
        debugPrint('socket viaje_tomado: $data');
        final idTomado = data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
        if (idTomado == null || _incomingRide == null) return;

        final idInt = idTomado is num
            ? idTomado.toInt()
            : int.tryParse(idTomado.toString());

        if (idInt == null) return;

        if (_incomingRide!.idViajes == idInt) {
          setState(() {
            _incomingRide = null;
            _accepted = false;
            _polylines.clear();
            _markers.removeWhere(
              (m) => m.markerId.value.startsWith('passenger_'),
            );
          });
          _showSnack('Otro conductor tomó este viaje.');
        }
      } catch (e) {
        debugPrint('Error procesando viaje_tomado: $e');
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
    if (_mapCtrl == null || _driverLocation == null || _incomingRide == null) {
      return;
    }
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
      final resp = await _api.getTodayEarnings();
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
      await _api.addEarning(amount);
    } catch (e) {
      debugPrint('Error guardando recaudación en backend: $e');
    }
  }

  // Conectarse (ONLINE)
  Future<void> _goOnline() async {
    try {
      final user = await UserPreferences.getUser();
      final idUsuario = user?['id_usuario'];

      if (idUsuario == null) {
        _showSnack('No se encontró información del usuario.');
        debugPrint('❌ [Driver] id_usuario es null en _goOnline');
        return;
      }

      debugPrint('🔌 [Driver] Conectando conductor ${idUsuario}...');

      // 1) Conectar socket (con manejo de errores mejorado)
      try {
        await _socket.connect();
      } catch (e) {
        debugPrint('⚠️ [Driver] Error en connect(), pero continuando: $e');
        // Continuar aunque haya error, el socket intentará reconectar
      }

      // Esperar un momento para que la conexión se establezca
      await Future.delayed(const Duration(milliseconds: 1000));

      // Verificar conexión después de esperar
      if (!_socket.isConnected) {
        debugPrint(
          '⚠️ [Driver] Socket no conectado después de 1 segundo, pero continuando...',
        );
        _showSnack('Conectando al servidor... (puede tardar unos segundos)');
        // Continuar de todas formas, el socket intentará reconectar
      } else {
        debugPrint('✅ [Driver] Socket conectado exitosamente');
      }

      // 2) Registrar usuario en socket (esto lo une al room "conductores")
      // Intentar registrar aunque el socket no esté completamente conectado
      try {
        await _socket.registrarUsuario(idUsuario: idUsuario, tipo: 'conductor');
        debugPrint('✅ [Driver] Conductor ${idUsuario} registrado en socket');
      } catch (e) {
        debugPrint(
          '⚠️ [Driver] Error al registrar usuario, pero continuando: $e',
        );
        // El socket intentará reconectar y registrar automáticamente
      }

      // 3) Actualizar estado en BD
      final ok = await _api.cambiarEstadoConductor(
        idConductor: idUsuario,
        conectado: true,
      );
      if (!ok) {
        _showSnack('No se pudo actualizar el estado en el servidor.');
        debugPrint('⚠️ [Driver] No se pudo actualizar estado del conductor');
      } else {
        debugPrint('✅ [Driver] Estado del conductor actualizado a conectado');
      }

      // 4) Inicializar listeners si no están activos
      if (!_listening) {
        await _initSocketListeners();
        debugPrint('✅ [Driver] Listeners de socket inicializados');
      }

      if (!mounted) return;
      setState(() {
        _isOnline = true;
      });

      _showSnack('Estás conectado y disponible para recibir viajes.');
      debugPrint(
        '✅ [Driver] Conductor ${idUsuario} ONLINE y listo para recibir viajes',
      );
    } catch (e) {
      debugPrint('❌ [Driver] Error al ponerse online: $e');
      _showSnack('Error al conectarse: $e');
    }
  }

  // Desconectarse (OFFLINE)
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
      _socket.off('viaje_cancelado_busqueda');
      _socket.off('viaje_tomado');

      if (!mounted) return;
      setState(() {
        _isOnline = false;
        _incomingRide = null;
        _accepted = false;
        _polylines.clear();
      });

      _showSnack('Te desconectaste. Ya no recibirás nuevos viajes.');
    } catch (e) {
      debugPrint('Error al ponerse offline: $e');
      _showSnack('Error al desconectarse: $e');
    }
  }

  // CERRAR SESIÓN
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que querés cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // notificar desconexión por socket antes de borrar prefs
      final user = await UserPreferences.getUser();
      final idUsuario = user?['id_usuario'];
      if (idUsuario != null) {
        await _socket.disconnectAndNotify(
          idUsuario: idUsuario,
          tipo: 'conductor',
        );
      }

      await UserPreferences.fullLogout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      if (!mounted) return;
      _showSnack('Error al cerrar sesión');
    }
  }

  // Aceptar viaje → navegar a pantalla "en camino"
  Future<void> _acceptRide() async {
    if (_incomingRide == null) return;
    setState(() => _loading = true);

    try {
      final user = await UserPreferences.getUser();
      final driverId = user?['id_usuario'];
      if (driverId == null) {
        _showSnack('No se encontró id de conductor en preferencias.');
        setState(() => _loading = false);
        return;
      }

      // El nuevo acceptRide ya usa id_conductor internamente
      final res = await _api.acceptRide(_incomingRide!.idViajes, driverId);
      if (res == true) {
        setState(() {
          _accepted = true;
        });

        _showSnack('Viaje aceptado. En camino al pasajero...');

        if (!mounted) return;

        final started = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => DriverEnCaminoScreen(ride: _incomingRide!),
          ),
        );

        // Si en la otra pantalla iniciaron el viaje, limpiamos la tarjeta
        if (started == true && mounted) {
          setState(() {
            _incomingRide = null;
            _accepted = false;
            _polylines.clear();
          });
        }
      } else {
        _showSnack('Error al aceptar viaje');
      }
    } catch (e) {
      debugPrint('Error acceptRide: $e');
      _showSnack('Error al aceptar viaje: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Rechazar viaje
  Future<void> _rejectRide() async {
    if (_incomingRide == null) return;

    try {
      final user = await UserPreferences.getUser();
      final driverId = user?['id_usuario'];

      if (driverId == null) {
        _showSnack('No se encontró id de conductor.');
        return;
      }

      final idViaje = _incomingRide!.idViajes;

      // Usar el nuevo método rechazarViaje
      final ok = await _api.rechazarViaje(idViaje, driverId);

      if (ok) {
        setState(() {
          _incomingRide = null;
          _accepted = false;
          _polylines.clear();
          _markers.removeWhere(
            (m) => m.markerId.value.startsWith('passenger_'),
          );
        });

        _showSnack('Viaje rechazado.');
      } else {
        _showSnack('Error al rechazar el viaje.');
      }
    } catch (e) {
      debugPrint('Error al rechazar viaje: $e');
      _showSnack('Error al rechazar el viaje.');
    }
  }

  // --- Helpers polyline (lo podés dejar o borrar si no usás) ---

  Future<void> _drawRouteToPassenger() async {
    if (_driverLocation == null || _incomingRide == null) return;

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null) {
      debugPrint('❌ Google API KEY no encontrada en .env');
      return;
    }

    final origin = '${_driverLocation!.latitude},${_driverLocation!.longitude}';
    final destination = '${_incomingRide!.latDesde},${_incomingRide!.lonDesde}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination&mode=driving&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] != 'OK') {
        debugPrint('❌ Error Directions API: ${data['status']}');
        return;
      }

      final route = data['routes'][0]['overview_polyline']['points'];
      final polylinePoints = _decodePolyline(route);

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_to_passenger'),
            points: polylinePoints,
            width: 6,
            color: Colors.blue,
          ),
        );
      });

      await _fitPolyline(polylinePoints);
    } catch (e) {
      debugPrint('❌ Error solicitando ruta: $e');
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

      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatCurrency(double v) {
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // --- TU HEADER ORIGINAL ---
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.local_taxi, color: Colors.amber, size: 48),
                  SizedBox(height: 10),
                  Text(
                    'Menú',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),

            // --- SECCIÓN OPERATIVA ---
            ListTile(
              leading: const Icon(Icons.history, color: Colors.black87),
              title: const Text('Historial de viajes'),
              onTap: () {
                Navigator.pop(context);
                // Navigator.push(context, MaterialPageRoute(builder: (_) => HistorialScreen()));
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.payments,
                color: Colors.black87,
              ), // O attach_money
              title: const Text('Ingresos'),
              onTap: () {
                Navigator.pop(context);
                // Navigator.push(context, MaterialPageRoute(builder: (_) => IngresosScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.black87),
              title: const Text('Estadísticas'),
              onTap: () {
                Navigator.pop(context);
                // Navigator.push(context, MaterialPageRoute(builder: (_) => EstadisticasScreen()));
              },
            ),

            const Divider(), // Separador visual
            // --- SECCIÓN PERSONAL ---
            ListTile(
              leading: const Icon(Icons.person, color: Colors.black87),
              title: const Text('Mi perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DriverProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge, color: Colors.black87),
              title: const Text('Mi Carnet Digital'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CarnetDigitalScreen(),
                  ),
                );
              },
            ),

            const Divider(), // Separador visual
            // --- CONFIGURACIÓN ---
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.black87),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                // Navigator.push(context, MaterialPageRoute(builder: (_) => ConfiguracionScreen()));
              },
            ),

            // Opción extra recomendada: Cerrar Sesión (o Desconectar)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                // Tu lógica de logout
              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('TucuTaxi'),
        centerTitle: true,
        titleTextStyle: const TextStyle(color: Colors.yellow, fontSize: 25),
        backgroundColor: Colors.black87,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
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

                // if (taximetro.viajeActivo)
                //   Positioned(
                //     bottom: 100,
                //     right: 16,
                //     child: GestureDetector(
                //       onTap: () async {
                //         await Navigator.of(context).push(
                //           MaterialPageRoute(
                //             builder: (_) => const TaximetroScreen(),
                //           ),
                //         );
                //         setState(() {});
                //       },
                //       child: AnimatedContainer(
                //         duration: const Duration(milliseconds: 300),
                //         padding: const EdgeInsets.symmetric(
                //           vertical: 10,
                //           horizontal: 16,
                //         ),
                //         decoration: BoxDecoration(
                //           color: Colors.black87,
                //           borderRadius: BorderRadius.circular(30),
                //           boxShadow: const [
                //             BoxShadow(
                //               color: Colors.black26,
                //               offset: Offset(0, 3),
                //               blurRadius: 6,
                //             ),
                //           ],
                //         ),
                //         child: Row(
                //           mainAxisSize: MainAxisSize.min,
                //           children: [
                //             const Icon(
                //               Icons.local_taxi,
                //               color: Colors.greenAccent,
                //             ),
                //             const SizedBox(width: 8),
                //             Text(
                //               '${taximetro.total.toStringAsFixed(0)}',
                //               style: const TextStyle(
                //                 color: Colors.white,
                //                 fontSize: 18,
                //                 fontWeight: FontWeight.bold,
                //               ),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ),
                //   ),
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

                // Botón conectar / desconectar
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: _incomingRide != null ? 100 : 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isOnline ? _goOffline : _goOnline,
                          icon: Icon(
                            _isOnline
                                ? Icons.wifi_off_rounded
                                : Icons.wifi_rounded,
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            backgroundColor: _isOnline
                                ? Colors.redAccent
                                : Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          label: Text(
                            _isOnline
                                ? 'Desconectarse (no recibir viajes)'
                                : 'Conectarse (recibir viajes)',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!mounted) return;
                            await Navigator.of(context).pushNamed("/taximetro");
                          },
                          icon: const Icon(Icons.attach_money),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          label: const Text(
                            'Viaje Rápido',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Panel inferior: tarjeta del viaje entrante
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
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
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

// Modelo ligero del JSON
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

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory IncomingRide.fromSocket(dynamic json) {
    try {
      final parsed = json is String ? jsonDecode(json) : json;
      debugPrint('📦 [IncomingRide] Parsing: $parsed');

      return IncomingRide(
        idViajes: (parsed['id_viajes']) is num
            ? (parsed['id_viajes'] as num).toInt()
            : int.parse(parsed['id_viajes'].toString()),
        idPasajero: (parsed['id_pasajero']) is num
            ? (parsed['id_pasajero'] as num).toInt()
            : int.parse(parsed['id_pasajero'].toString()),
        idConductor: parsed['id_conductor'] is num
            ? (parsed['id_conductor'] as num).toInt()
            : null,
        direccionDesde:
            parsed['direccion_desde'] ?? parsed['direccionDesde'] ?? '',
        latDesde: _parseDouble(parsed['lat_desde'] ?? parsed['latDesde'] ?? 0),
        lonDesde: _parseDouble(parsed['lon_desde'] ?? parsed['lonDesde'] ?? 0),
        direccionHasta:
            parsed['direccion_hasta'] ?? parsed['direccionHasta'] ?? '',
        latHasta: _parseDouble(
          parsed['lat_hasta'] ?? parsed['latHasta'] ?? parsed['lat_desde'] ?? 0,
        ),
        lonHasta: _parseDouble(
          parsed['lon_hasta'] ?? parsed['lonHasta'] ?? parsed['lon_desde'] ?? 0,
        ),
        horaInicio: parsed['hora_inicio'] != null
            ? DateTime.parse(parsed['hora_inicio'].toString())
            : null,
        horaFin: parsed['hora_fin'] != null
            ? DateTime.parse(parsed['hora_fin'].toString())
            : null,
        valor: _parseDouble(parsed['valor'] ?? 0),
        idEstado: (parsed['id_estado'] ?? parsed['estado'] ?? 1) is num
            ? (parsed['id_estado'] ?? parsed['estado'] ?? 1 as num).toInt()
            : int.tryParse(
                    (parsed['id_estado'] ?? parsed['estado'] ?? 1).toString(),
                  ) ??
                  1,
      );
    } catch (e) {
      debugPrint('❌ [IncomingRide] Error parsing: $e');
      debugPrint('❌ [IncomingRide] JSON recibido: $json');
      rethrow;
    }
  }
}
