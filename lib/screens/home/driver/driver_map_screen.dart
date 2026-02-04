// lib/screens/home/driver/driver_map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';

import 'package:taxi_tuc/screens/carnet_conductor/carnet_digital_screen.dart';
import 'package:taxi_tuc/screens/home/driver/driver_perfil_screen.dart';
import 'package:taxi_tuc/screens/home/driver/driver_configuracion_screen.dart';
import 'package:taxi_tuc/screens/home/driver/ingresos_screen.dart';
import 'package:taxi_tuc/screens/home/driver/estadisticas_screen.dart';

import '../../../services/socket_service.dart';
import '../../../services/api_service.dart';
import '../../../services/user_preferences.dart';
import '../../../services/taximetro_service.dart';
import '../../../services/earnings_service.dart';

import 'driver_en_camino_screen.dart';

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

  final GlobalKey _bottomButtonsKey = GlobalKey();
  final GlobalKey _incomingCardKey = GlobalKey();

  double _panicBottom = 16.0; // se recalcula según tamaños reales
  double _bottomButtonsH = 0.0;
  double _incomingCardH = 0.0;

  final _earningsService = EarningsService.instance;
  final _money = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  GoogleMapController? _mapCtrl;
  LatLng? _driverLocation;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // ==========================
  // ✅ Pins unificados + sombra
  // ==========================
  BitmapDescriptor? _iconDriverOnline;
  BitmapDescriptor? _iconDriverOffline;
  BitmapDescriptor? _iconDriverOnlineBig;
  BitmapDescriptor? _iconDriverOfflineBig;

  BitmapDescriptor? _iconPassenger;
  BitmapDescriptor? _iconShadow;

  // ==========================
  // ✅ Bounce suave al recibir viaje
  // (usa icono "big" por frames)
  // ==========================
  late final AnimationController _bounceCtrl;
  bool _useBigIcon = false;

  IncomingRide? _incomingRide;

  bool _listening = false;
  bool _accepted = false;
  bool _loading = false;
  bool _isOnline = false;
  int? _myDriverId;

  late AnimationController _islandPulse;
  Timer? _taximetroTimer;

  // ✅ Recaudación de hoy (desde EarningsService)
  double _recaudacionHoy = 0.0;
  Timer? _earningsTimer;

  @override
  void initState() {
    super.initState();

    _resolveMyDriverId();

    _islandPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bounceCtrl.addListener(() {
      // curva tipo "salto" (sin actualizar 60fps al pedo)
      final scale = 1.0 + 0.12 * math.sin(_bounceCtrl.value * math.pi);
      final shouldBig = scale > 1.06;
      if (shouldBig != _useBigIcon) {
        _useBigIcon = shouldBig;
        _updateDriverMarkers();
      }
    });
    _bounceCtrl.addStatusListener((st) {
      if (st == AnimationStatus.completed || st == AnimationStatus.dismissed) {
        if (_useBigIcon) {
          _useBigIcon = false;
          _updateDriverMarkers();
        }
      }
    });

    _initDriverHome();

    // ✅ actualiza la recaudación hoy automáticamente
    _loadRecaudacionHoy();
    _earningsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadRecaudacionHoy(),
    );

    _taximetroTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && taximetro.viajeActivo) setState(() {});
    });
  }

  @override
  void dispose() {
    _taximetroTimer?.cancel();
    _earningsTimer?.cancel();

    _mapCtrl?.dispose();
    _islandPulse.dispose();
    _bounceCtrl.dispose();

    _socket.off('viaje_creado');
    _socket.off('viaje_finalizado');
    _socket.off('viaje_cancelado_busqueda');
    _socket.off('viaje_tomado');

    super.dispose();
  }

  void _resetIncomingRideUI() {
    setState(() {
      _incomingRide = null;
      _accepted = false;
      _loading = false;

      _polylines.clear();
      _markers.removeWhere((m) => m.markerId.value.startsWith('passenger_'));
    });

    // dejar markers del driver (sombra + pin)
    _updateDriverMarkers();

    // opcional: re-centrar mapa
    if (_mapCtrl != null && _driverLocation != null) {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(_driverLocation!, 14));
    }
  }

  Future<void> _resolveMyDriverId() async {
    final fromPrefs = await UserPreferences.getIdUsuario();
    if (!mounted) return;
    setState(() {
      _myDriverId = fromPrefs;
    });

    debugPrint('🧑‍✈️ myDriverId = $_myDriverId');
  }

  Future<void> _initDriverHome() async {
    final isDriver = await _checkRoleAccess();
    if (!mounted || !isDriver) return;

    await _initIcons();
    await _initLocation();

    // si ya tenemos ubicación, refrescamos recaudación
    await _loadRecaudacionHoy();
  }

  Future<void> _loadRecaudacionHoy() async {
    final idUsuario = await UserPreferences.getIdUsuario();
    if (idUsuario == null || !mounted) return;

    final totalHoy = await _earningsService.getTotalHoy(idUsuario: idUsuario);

    if (!mounted) return;
    setState(() {
      _recaudacionHoy = totalHoy;
    });
  }

  Future<void> _openIngresos() async {
    final idUsuario = await UserPreferences.getIdUsuario();
    if (!mounted || idUsuario == null) {
      _showSnack('No se encontró el ID del usuario');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IngresosScreen(idUsuario: idUsuario)),
    );

    // ✅ al volver, refrescar por si hubo nuevos ingresos
    await _loadRecaudacionHoy();
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

  int _px(BuildContext context, double logicalPx) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return (logicalPx * dpr).round();
  }

  // ==========================
  // ✅ ICONOS (pins + sombra)
  // ==========================
  Future<void> _initIcons() async {
    // Conductor online/offline
    _iconDriverOnline = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_online.png',
      _px(context, 80),
    );
    _iconDriverOffline = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_offline.png',
      _px(context, 80),
    );

    // versión "big" para bounce (solo un poquito más grande)
    _iconDriverOnlineBig = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_online.png',
      _px(context, 92),
    );
    _iconDriverOfflineBig = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_offline.png',
      _px(context, 92),
    );

    // Pasajero unificado (mismo estilo)
    _iconPassenger = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_passenger.png',
      _px(context, 76),
    );

    // sombra fake (más chica)
    _iconShadow = await _createBitmapDescriptorFromAsset(
      'assets/markers/taxi_pin_shadow.png',
      _px(context, 60),
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

  // ==========================
  // ✅ LOCATION
  // ==========================
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

      // ✅ actualiza markers (sombra + pin)
      _updateDriverMarkers();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error init location driver: $e');
    }
  }

  // ==========================
  // ✅ MARKERS helpers
  // ==========================
  BitmapDescriptor? _currentDriverIcon() {
    final online = _isOnline;
    if (_useBigIcon) {
      return online ? _iconDriverOnlineBig : _iconDriverOfflineBig;
    }
    return online ? _iconDriverOnline : _iconDriverOffline;
  }

  Marker _buildShadowMarker(LatLng pos) {
    return Marker(
      markerId: const MarkerId('driver_shadow'),
      position: pos,
      icon: _iconShadow!,
      // para la sombra conviene centro
      anchor: const Offset(0.5, 0.5),
      zIndex: 0,
      flat: true,
    );
  }

  Marker _buildDriverMarker(LatLng pos) {
    return Marker(
      markerId: const MarkerId('driver_pin'),
      position: pos,
      icon: _currentDriverIcon()!,
      // ✅ pin: punta al GPS
      anchor: const Offset(0.5, 1.0),
      zIndex: 1,
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
    );
  }

  void _updateDriverMarkers() {
    if (!mounted) return;
    if (_driverLocation == null) return;
    if (_iconShadow == null) return;
    if (_iconDriverOnline == null || _iconDriverOffline == null) return;

    final pos = _driverLocation!;

    setState(() {
      _markers.removeWhere(
        (m) =>
            m.markerId.value == 'driver_shadow' ||
            m.markerId.value == 'driver_pin' ||
            m.markerId.value == 'driver',
      );

      // sombra fake + pin
      _markers.add(_buildShadowMarker(pos));
      _markers.add(_buildDriverMarker(pos));
    });
  }

  void _triggerBounce() {
    // bounce suave cuando entra un viaje
    if (_bounceCtrl.isAnimating) return;
    _bounceCtrl.forward(from: 0);
  }

  // ==========================
  // ✅ SOCKET listeners
  // ==========================
  Future<void> _initSocketListeners() async {
    // viaje creado por pasajero → aparece tarjeta al chofer
    _socket.on('viaje_creado', (data) async {
      try {
        debugPrint('🚕 [Driver] Evento viaje_creado recibido: $data');

        if (data == null) return;

        final ride = IncomingRide.fromSocket(data);

        if (!mounted) return;

        setState(() {
          _incomingRide = ride;
          _accepted = false;
        });

        // ✅ bounce suave (pro)
        _triggerBounce();

        await _addPassengerMarker(ride);
        await _fitMapToDriverAndPassenger();

        _showSnack('Nuevo viaje disponible 🚕');
      } catch (e) {
        debugPrint('❌ [Driver] Error procesando viaje_creado: $e');
      }
    });

    // viaje finalizado → refrescamos recaudación y limpiamos si coincide
    _socket.on('viaje_finalizado', (data) async {
      try {
        final id = int.tryParse(
          '${data?['id_viajes'] ?? data?['id_viaje'] ?? ''}',
        );
        if (id != null &&
            _incomingRide != null &&
            _incomingRide!.idViajes == id) {
          _resetIncomingRideUI();
        }
      } catch (_) {}
      await _loadRecaudacionHoy();
    });

    // viaje cancelado mientras estaba "buscando" → limpiar tarjeta
    _socket.on('viaje_cancelado_busqueda', (data) {
      try {
        final idCancelado =
            data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
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
    _socket.on('viaje_tomado', (data) {
      final idViaje = int.tryParse('${data['id_viajes']}') ?? -1;
      final ganador = int.tryParse('${data['id_conductor_ganador']}');

      // Si no es el viaje que estoy viendo, ignoro
      if (_incomingRide == null || idViaje != _incomingRide!.idViajes) return;

      // 👇 SI YO SOY EL GANADOR, NO CIERRO
      if (ganador != null && ganador == _myDriverId) {
        debugPrint('🏆 Soy el conductor ganador, ignoro viaje_tomado');
        return;
      }

      // Si NO soy el ganador → cierro
      setState(() {
        _incomingRide = null;
      });

      _showSnack('Otro conductor aceptó el viaje');
    });

    _socket.on('viaje_ya_tomado', (data) {
      final idViaje = int.tryParse('${data['id_viajes']}') ?? -1;
      if (_incomingRide == null || idViaje != _incomingRide!.idViajes) return;

      setState(() => _incomingRide = null);
      _showSnack('Este viaje ya fue tomado por otro conductor');
    });

    setState(() => _listening = true);
  }

  Future<void> _addPassengerMarker(IncomingRide ride) async {
    final mk = Marker(
      markerId: MarkerId('passenger_${ride.idViajes}'),
      position: LatLng(ride.latDesde, ride.lonDesde),
      icon:
          _iconPassenger ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      anchor: const Offset(0.5, 1.0), // pin: punta al GPS
      infoWindow: InfoWindow(
        title: 'Origen pasajero',
        snippet: ride.direccionDesde,
      ),
      zIndex: 1,
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

  // Conectarse (ONLINE)
  Future<void> _goOnline() async {
    try {
      final user = await UserPreferences.getUser();
      final idUsuario = user?['id_usuario'];

      if (idUsuario == null) {
        _showSnack('No se encontró información del usuario.');
        return;
      }

      // 1) Conectar socket
      try {
        await _socket.connect();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 800));

      // 2) Registrar usuario en socket
      try {
        await _socket.registrarUsuario(idUsuario: idUsuario, tipo: 'conductor');
      } catch (_) {}

      // 3) Actualizar estado en BD
      await _api.cambiarEstadoConductor(
        idConductor: idUsuario,
        conectado: true,
      );

      // 4) Listeners
      if (!_listening) {
        await _initSocketListeners();
      }

      if (!mounted) return;
      setState(() => _isOnline = true);

      // ✅ refrescar icono driver (online)
      _updateDriverMarkers();

      _showSnack('Estás conectado y disponible para recibir viajes.');
    } catch (e) {
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

      // ✅ refrescar icono driver (offline)
      _updateDriverMarkers();

      _showSnack('Te desconectaste. Ya no recibirás nuevos viajes.');
    } catch (e) {
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
    } catch (_) {
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
      final dynamic rawDriverId = user?['id_usuario'];
      final int? driverId = (rawDriverId is int)
          ? rawDriverId
          : int.tryParse('$rawDriverId');

      if (driverId == null) {
        _showSnack('No se encontró id de conductor en preferencias.');
        setState(() => _loading = false);
        return;
      }

      // snapshot del viaje actual
      final rideToSend = _incomingRide!;
      final idViaje = rideToSend.idViajes;

      final ok = await _api.acceptRide(idViaje, driverId);
      if (ok != true) {
        _showSnack('Error al aceptar viaje');
        if (mounted) setState(() => _loading = false);
        return;
      }

      // ✅ limpiamos el modal ANTES de navegar
      if (mounted) _resetIncomingRideUI();

      _showSnack('Viaje aceptado. En camino al pasajero...');

      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DriverEnCaminoScreen(ride: rideToSend),
        ),
      );

      // ✅ vuelvas con true / null / false → dejá el home limpio igual
      if (!mounted) return;

      _resetIncomingRideUI();

      // si el flujo terminó bien, avisamos
      if (result == true) {
        await _loadRecaudacionHoy();
        _showSnack('✅ Listo para recibir nuevos viajes');
      }
    } catch (e) {
      _showSnack('Error al aceptar viaje: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Rechazar viaje
  Future<void> _rejectRide() async {
    if (_incomingRide == null) return;

    try {
      final driverId = _myDriverId;

      if (driverId == null) {
        _showSnack('No se encontró id de conductor.');
        return;
      }

      final idViaje = _incomingRide!.idViajes;
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
    } catch (_) {
      _showSnack('Error al rechazar el viaje.');
    }
  }

  // --- Helpers polyline ---
  Future<void> _drawRouteToPassenger() async {
    if (_driverLocation == null || _incomingRide == null) return;

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
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

      if (data['status'] != 'OK') return;

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
    } catch (_) {}
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

  void _recalcPanicBottom() {
    if (!mounted) return;

    final safeBottom = MediaQuery.of(context).padding.bottom;

    final btnSize = _bottomButtonsKey.currentContext?.size;
    final cardSize = _incomingCardKey.currentContext?.size;

    final double btnH = btnSize?.height ?? 0.0;
    final double cardH = _incomingRide != null
        ? (cardSize?.height ?? 0.0)
        : 0.0;

    const double gap = 12.0;

    final double desired =
        safeBottom + 16.0 + btnH + gap + (cardH > 0 ? (cardH + gap) : 0.0);

    final double newBottom = math.max(safeBottom + 16.0, desired).toDouble();

    if ((newBottom - _panicBottom).abs() > 0.5 ||
        (btnH - _bottomButtonsH).abs() > 0.5 ||
        (cardH - _incomingCardH).abs() > 0.5) {
      setState(() {
        _panicBottom = newBottom;
        _bottomButtonsH = btnH;
        _incomingCardH = cardH;
      });
    }
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

  String _formatCurrency(double v) => '\$${v.toStringAsFixed(0)}';

  Future<void> _onPanicPressed() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Botón antipánico'),
        content: const Text(
          '¿Querés enviar una alerta 911?\n'
          'Esto notificará al sistema con tu ubicación actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final idUsuario = await UserPreferences.getIdUsuario();

    _socket.emit('panic_911', {
      'id_usuario': idUsuario,
      'lat': _driverLocation?.latitude,
      'lng': _driverLocation?.longitude,
      'ts': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    _showSnack('🚨 Alerta 911 enviada');
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recalcPanicBottom();
    });

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
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
            ListTile(
              leading: const Icon(Icons.history, color: Colors.black87),
              title: const Text('Historial de viajes'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.payments, color: Colors.black87),
              title: const Text('Ingresos'),
              onTap: () async {
                Navigator.pop(context);
                await _openIngresos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.black87),
              title: const Text('Estadísticas'),
              onTap: () async {
                Navigator.pop(context);
                final idUsuario = await UserPreferences.getIdUsuario();
                if (!mounted || idUsuario == null) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EstadisticasScreen(idUsuario: idUsuario),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.black87),
              title: const Text('Mi perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverProfileScreen(),
                  ),
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.black87),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConfiguracionScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: ui.Color.fromARGB(221, 163, 1, 1),
              ),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: ui.Color.fromARGB(221, 163, 1, 1)),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('A.CO.T.T'),
        centerTitle: true,
        titleTextStyle: const TextStyle(color: Colors.yellow, fontSize: 25),
        backgroundColor: Colors.black87,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
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

                // ✅ Botón antipánico
                Positioned(
                  right: 16,
                  bottom: _panicBottom,
                  child: GestureDetector(
                    onTap: _onPanicPressed,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '911',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                // ✅ Isla superior (estado + recaudación hoy clickable)
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
                              Icon(
                                _isOnline
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_off_rounded,
                                color: _isOnline
                                    ? Colors.green
                                    : Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isOnline ? 'ONLINE' : 'OFFLINE',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 14),

                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openIngresos,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.attach_money,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Recaudación hoy',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          _money.format(_recaudacionHoy),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: Colors.black38,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ✅ Botones inferiores
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: _incomingRide != null ? 100 : 24,
                  child: Container(
                    key: _bottomButtonsKey,
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
                              await Navigator.of(
                                context,
                              ).pushNamed("/taximetro");
                              await _loadRecaudacionHoy();
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
                ),

                // ✅ Tarjeta del viaje entrante
                if (_incomingRide != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 18,
                    child: Container(
                      key: _incomingCardKey,
                      child: _buildIncomingRideCard(),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildIncomingRideCard() {
    final r = _incomingRide!;
    return GestureDetector(
      onTap: () async {
        await _drawRouteToPassenger();
      },
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
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
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

  static int _parseInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? fallback;
  }

  static double _parseDouble(dynamic v, {double fallback = 0.0}) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? fallback;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory IncomingRide.fromSocket(dynamic json) {
    final parsed = (json is String) ? jsonDecode(json) : json;

    // IDs (acepta varias claves posibles)
    final int idViaje = _parseInt(
      parsed['id_viajes'] ?? parsed['id_viaje'] ?? parsed['id'],
      fallback: -1,
    );

    final int idPasajero = _parseInt(
      parsed['id_pasajero'] ?? parsed['idUsuario'] ?? parsed['id_usuario'],
      fallback: -1,
    );

    // Coordenadas (acepta varias claves posibles)
    final double latDesde = _parseDouble(
      parsed['lat_desde'] ??
          parsed['latDesde'] ??
          parsed['lat_origen'] ??
          parsed['latOrigen'],
    );
    final double lonDesde = _parseDouble(
      parsed['lon_desde'] ??
          parsed['lonDesde'] ??
          parsed['lng_desde'] ??
          parsed['lngDesde'] ??
          parsed['lon_origen'] ??
          parsed['lng_origen'] ??
          parsed['lngOrigen'],
    );

    final double latHasta = _parseDouble(
      parsed['lat_hasta'] ??
          parsed['latHasta'] ??
          parsed['lat_destino'] ??
          parsed['latDestino'],
      fallback: latDesde,
    );
    final double lonHasta = _parseDouble(
      parsed['lon_hasta'] ??
          parsed['lonHasta'] ??
          parsed['lng_hasta'] ??
          parsed['lngHasta'] ??
          parsed['lon_destino'] ??
          parsed['lng_destino'] ??
          parsed['lngDestino'],
      fallback: lonDesde,
    );

    final int estado = _parseInt(
      parsed['id_estado'] ?? parsed['estado'],
      fallback: 1,
    );

    if (idViaje <= 0 || idPasajero <= 0) {
      throw Exception(
        'Payload inválido: idViaje=$idViaje idPasajero=$idPasajero parsed=$parsed',
      );
    }

    return IncomingRide(
      idViajes: idViaje,
      idPasajero: idPasajero,
      idConductor: (parsed['id_conductor'] == null)
          ? null
          : _parseInt(parsed['id_conductor']),
      direccionDesde: _str(
        parsed['direccion_desde'] ??
            parsed['direccionDesde'] ??
            parsed['origen'],
      ),
      latDesde: latDesde,
      lonDesde: lonDesde,
      direccionHasta: _str(
        parsed['direccion_hasta'] ??
            parsed['direccionHasta'] ??
            parsed['destino'],
      ),
      latHasta: latHasta,
      lonHasta: lonHasta,
      horaInicio: (parsed['hora_inicio'] != null)
          ? DateTime.tryParse('${parsed['hora_inicio']}')
          : null,
      horaFin: (parsed['hora_fin'] != null)
          ? DateTime.tryParse('${parsed['hora_fin']}')
          : null,
      valor: _parseDouble(parsed['valor'], fallback: 0.0),
      idEstado: estado,
    );
  }
}
