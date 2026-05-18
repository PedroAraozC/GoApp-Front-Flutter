import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/user_preferences.dart';
import 'widgets/rating_modal.dart';

class PasajeroViajeEnCursoScreen extends StatefulWidget {
  final int idViaje;
  final int idConductor;
  final double latDestino;
  final double lngDestino;

  final String direccionOrigen;
  final String direccionDestino;

  final double? latConductorInicial;
  final double? lngConductorInicial;

  const PasajeroViajeEnCursoScreen({
    super.key,
    required this.idViaje,
    required this.idConductor,
    required this.latDestino,
    required this.lngDestino,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.latConductorInicial,
    this.lngConductorInicial,
  });

  @override
  State<PasajeroViajeEnCursoScreen> createState() =>
      _PasajeroViajeEnCursoScreenState();
}

class _PasajeroViajeEnCursoScreenState
    extends State<PasajeroViajeEnCursoScreen> {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService.instance;

  GoogleMapController? _mapCtrl;

  String _conductorNombre = '';
  String _conductorApellido = '';
  bool _detalleCargado = false;
  String _fotoConductor = '';
  double _ratingConductor = 0;

  String _vehiculoModelo = '';
  String _vehiculoPatente = '';

  bool _conductorVerificado = false;

  LatLng? _posConductor;
  late final LatLng _posDestino;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _loading = true;
  bool _cancelando = false;

  String _distanceText = '--';
  String _durationText = '--';

  Timer? _routeDebounce;
  bool _pendingRouteUpdate = false;

  bool _endingHandled = false;

  // ✅ handlers para remover SOLO lo de esta pantalla
  Function(dynamic)? _hUbicacion;
  Function(dynamic)? _hFinalizadoWrapper;
  Function(dynamic)? _hFinalizadoDirect;
  Function(dynamic)? _hCompletadoPasajero;
  Function(dynamic)? _hCompletado; // por compat
  Function(dynamic)? _hCanceladoWrapper;
  Function(dynamic)? _hCanceladoDirect;

  @override
  void initState() {
    super.initState();

    _posDestino = LatLng(widget.latDestino, widget.lngDestino);

    if (widget.latConductorInicial != null &&
        widget.lngConductorInicial != null) {
      _posConductor = LatLng(
        widget.latConductorInicial!,
        widget.lngConductorInicial!,
      );
    }

    _actualizarMarkers();
    _initSocket();
    _fetchCarnetConductor();
  }

  Future<void> _fetchDetalleViaje() async {
    if (_detalleCargado) return;
    _detalleCargado = true;

    final r = await _api.getDetalleViaje(widget.idViaje);
    if (!mounted) return;
    if (r["ok"] != true) return;

    final data = r["data"];
    if (data is! Map) return;

    final conductor = data["conductor"];
    if (conductor is Map) {
      setState(() {
        _conductorNombre = (conductor["nombre"] ?? "").toString();
        _conductorApellido = (conductor["apellido"] ?? "").toString();
      });
    }
  }

  Future<void> _fetchCarnetConductor() async {
    try {
      final resp = await _api.obtenerCarnetConductor(widget.idConductor);

      if (!mounted) return;

      final data = resp["data"];

      setState(() {
        _conductorNombre = (data["nombre"] ?? "").toString();

        _conductorApellido = (data["apellido"] ?? "").toString();

        _fotoConductor = (data["foto_url"] ?? "").toString();

        _ratingConductor =
            double.tryParse(data["rating"]?.toString() ?? "0") ?? 0;

        _vehiculoModelo = (data["modelo_vehiculo"] ?? "").toString();

        _vehiculoPatente = (data["patente"] ?? "").toString();

        _conductorVerificado = data["verificado"] == true;
      });
    } catch (e) {
      debugPrint("❌ Error cargando carnet conductor: $e");
    }
  }

  int? _readViajeId(dynamic data) {
    try {
      if (data is! Map) return null;
      final raw = data['id_viaje'] ?? data['id_viajes'] ?? data['id'];
      if (raw == null) return null;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  double? _parseMoney(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  Future<void> _showFinalPriceDialog(double total) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Viaje finalizado'),
        content: Text(
          'Total a pagar: \$${total.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleViajeFinalizado(
    dynamic data, {
    String source = 'socket',
  }) async {
    debugPrint("🏁 [$source] viaje_finalizado -> $data");
    if (!mounted) return;
    if (_endingHandled) return;

    final idSocket = _readViajeId(data);
    if (idSocket != null && idSocket != widget.idViaje) {
      debugPrint(
        'ℹ️ [$source] finalizado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
      );
      return;
    }

    _endingHandled = true;

    final m = (data is Map) ? data : const <String, dynamic>{};

    final total =
        (_parseMoney(m['precio_final']) ??
                _parseMoney(m['precio_pactado']) ??
                _parseMoney(m['precio_estimado']) ??
                _parseMoney(m['valor']) ??
                0.0)
            .toDouble();

    await _showFinalPriceDialog(total);

    if (!mounted) return;

    final nombreCompleto = ('$_conductorNombre $_conductorApellido').trim();
    final titulo = nombreCompleto.isNotEmpty
        ? 'Calificá a $nombreCompleto'
        : 'Calificá al conductor';

    // ✅ Modal para calificar al conductor (1 sola vez)
    // _endingHandled ya evita duplicado, así que estamos seguros
    await RatingModal.show(
      context,
      idViaje: widget.idViaje,
      tipo: "PASAJERO_A_CONDUCTOR",
      titulo: "Calificá al conductor",
      subtitulo: "Contanos cómo fue el viaje.",
    );

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _handleViajeCancelado(dynamic data, {String source = 'socket'}) {
    debugPrint("❌ [$source] viaje_cancelado -> $data");
    if (!mounted) return;
    if (_endingHandled) return;

    final idSocket = _readViajeId(data);
    if (idSocket != null && idSocket != widget.idViaje) {
      debugPrint(
        'ℹ️ [$source] cancelado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
      );
      return;
    }

    _endingHandled = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ El viaje fue cancelado'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _initSocket() async {
    try {
      final idUsuario = await UserPreferences.getIdUsuario();
      if (idUsuario == null) {
        debugPrint("⚠️ id_usuario null (pasajero).");
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (!_socket.isConnected) {
        await _socket.connect();
      }

      await _socket.emitirConexionUsuario(idUsuario, 'pasajero');

      await _socket.unirseAViaje(
        idViaje: widget.idViaje,
        userId: idUsuario,
        tipo: 'pasajero',
      );

      // -------------------------
      // ✅ Ubicación conductor
      // -------------------------
      _hUbicacion = _socket.onUbicacionEnTiempoReal((data) async {
        try {
          if (!mounted) return;
          if (data == null) return;
          if (data is! Map) return;
          if (data['tipo'] != 'conductor') return;

          final lat = double.tryParse(data['lat'].toString());
          final lng = double.tryParse(data['lng'].toString());
          if (lat == null || lng == null) return;

          _posConductor = LatLng(lat, lng);

          _actualizarMarkers();
          _scheduleRouteUpdate();
        } catch (e) {
          debugPrint("❌ Error ubicacion conductor: $e");
        }
      });

      // -------------------------
      // ✅ FINALIZADO (wrapper + directos/alias)
      // -------------------------
      _hFinalizadoWrapper = _socket.onViajeFinalizado(
        (data) =>
            _handleViajeFinalizado(data, source: 'wrapper:onViajeFinalizado'),
      );

      _hFinalizadoDirect = _socket.on(
        'viaje_finalizado',
        (data) =>
            _handleViajeFinalizado(data, source: 'socket:viaje_finalizado'),
      );

      // si alguna vez lo emitís así
      _hCompletadoPasajero = _socket.on(
        'viaje_completado_pasajero',
        (data) => _handleViajeFinalizado(
          data,
          source: 'socket:viaje_completado_pasajero',
        ),
      );

      // compat extra (por si tu server manda "viaje_completado")
      _hCompletado = _socket.on(
        'viaje_completado',
        (data) =>
            _handleViajeFinalizado(data, source: 'socket:viaje_completado'),
      );

      // -------------------------
      // ✅ CANCELADO (wrapper + directo)
      // -------------------------
      _hCanceladoWrapper = _socket.onViajeCancelado(
        (data) =>
            _handleViajeCancelado(data, source: 'wrapper:onViajeCancelado'),
      );

      _hCanceladoDirect = _socket.on(
        'viaje_cancelado',
        (data) => _handleViajeCancelado(data, source: 'socket:viaje_cancelado'),
      );

      if (_posConductor != null) {
        await _drawRoute();
        _fitToBounds();
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('❌ _initSocket error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleRouteUpdate() {
    _pendingRouteUpdate = true;
    _routeDebounce ??= Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!_pendingRouteUpdate) return;
      _pendingRouteUpdate = false;
      await _drawRoute();
      _fitToBounds();
    });
  }

  void _actualizarMarkers() {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('destino'),
        position: _posDestino,
        infoWindow: const InfoWindow(title: 'Destino'),
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
      final dest = '${_posDestino.latitude},${_posDestino.longitude}';

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

      final points = routes[0]['overview_polyline']?['points'];
      if (points == null) return;

      final decoded = _decodePolyline(points.toString());

      if (!mounted) return;
      setState(() {
        _distanceText = distance;
        _durationText = duration;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: decoded,
            width: 6,
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

  void _fitToBounds() {
    if (_mapCtrl == null) return;
    if (_posConductor == null) return;

    final a = _posConductor!;
    final b = _posDestino;

    final sw = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );

    _mapCtrl!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ),
    );
  }

  Future<void> _cancelarViaje() async {
    if (_cancelando) return;
    setState(() => _cancelando = true);

    try {
      final idUsuario = await UserPreferences.getIdUsuario();
      if (idUsuario == null) return;

      final ok = await _api.cancelarViaje(
        idViaje: widget.idViaje,
        idUsuario: idUsuario,
        tipo: 'pasajero',
      );

      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cancelar el viaje')),
        );
      }
    } catch (e) {
      debugPrint('❌ Cancelar viaje error: $e');
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();

    // ✅ remover SOLO listeners de esta pantalla
    _socket.off('ubicacion_en_tiempo_real', _hUbicacion);

    _socket.off('viaje_finalizado', _hFinalizadoWrapper);
    _socket.off('viaje_finalizado', _hFinalizadoDirect);
    _socket.off('viaje_completado_pasajero', _hCompletadoPasajero);
    _socket.off('viaje_completado', _hCompletado);

    _socket.off('viaje_cancelado', _hCanceladoWrapper);
    _socket.off('viaje_cancelado', _hCanceladoDirect);

    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // =========================
                // MAPA
                // =========================
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _posConductor ?? _posDestino,
                      zoom: 15,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (c) {
                      _mapCtrl = c;
                      _fitToBounds();
                    },
                  ),
                ),

                // =========================
                // DEGRADADO SUPERIOR
                // =========================
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.30),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // =========================
                // HEADER
                // =========================
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.arrow_back_ios_new),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =========================
                // PANEL INFERIOR GRANDE
                // =========================
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    width: double.infinity,
                    height: size.height * 0.44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // =========================
                            // INDICADOR
                            // =========================
                            Center(
                              child: Container(
                                width: 50,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // =========================
                            // TITULO
                            // =========================
                            const Text(
                              'Viaje en curso',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Llegarás aproximadamente en $_durationText',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                              ),
                            ),

                            const SizedBox(height: 22),

                            // =========================
                            // CARD CONDUCTOR
                            // =========================
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 39, 35, 35),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // =========================
                                      // FOTO CONDUCTOR
                                      // =========================
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color.fromARGB(
                                              255,
                                              255,
                                              217,
                                              50,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 32,
                                          backgroundColor: Colors.grey.shade300,
                                          backgroundImage:
                                              _fotoConductor.isNotEmpty
                                              ? NetworkImage(_fotoConductor)
                                              : null,
                                          child: _fotoConductor.isEmpty
                                              ? Text(
                                                  _conductorNombre.isNotEmpty
                                                      ? _conductorNombre[0]
                                                      : 'C',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // =========================
                                      // INFO CONDUCTOR
                                      // =========================
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '$_conductorNombre $_conductorApellido',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),

                                                // =========================
                                                // VERIFICADO
                                                // =========================
                                                if (_conductorVerificado)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withOpacity(0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.verified,
                                                          color: Colors.green,
                                                          size: 15,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Verificado',
                                                          style: TextStyle(
                                                            color: Colors.green,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            // =========================
                                            // RATING
                                            // =========================
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.star,
                                                  size: 18,
                                                  color: Colors.amber.shade700,
                                                ),

                                                const SizedBox(width: 4),

                                                Text(
                                                  _ratingConductor <= 0
                                                      ? 'Nuevo'
                                                      : _ratingConductor
                                                            .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            // =========================
                                            // VEHICULO
                                            // =========================
                                            Text(
                                              _vehiculoModelo.isEmpty
                                                  ? 'Vehículo no disponible'
                                                  : _vehiculoModelo,
                                              style: TextStyle(
                                                color: Colors.grey.shade300,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            // =========================
                                            // PATENTE
                                            // =========================
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _vehiculoPatente.isEmpty
                                                    ? '---'
                                                    : _vehiculoPatente,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.5,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // =========================
                                      // ACCIONES
                                      // =========================
                                      Column(
                                        children: [
                                          _circleAction(Icons.call),

                                          const SizedBox(height: 10),

                                          _circleAction(Icons.message),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // =========================
                            // INFO VIAJE
                            // =========================
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),

                                      const SizedBox(width: 14),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Origen',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: const Color.fromARGB(
                                                  255,
                                                  0,
                                                  0,
                                                  0,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.direccionOrigen,
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                  255,
                                                  0,
                                                  0,
                                                  0,
                                                ),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    height: 28,
                                    width: 1.2,
                                    color: Colors.grey.shade300,
                                  ),

                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),

                                      const SizedBox(width: 14),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Destino',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: const Color.fromARGB(
                                                  255,
                                                  0,
                                                  0,
                                                  0,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.direccionDestino,
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                  255,
                                                  0,
                                                  0,
                                                  0,
                                                ),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // =========================
                            // DISTANCIA Y TIEMPO
                            // =========================
                            Row(
                              children: [
                                Expanded(
                                  child: _infoCard(
                                    icon: Icons.route,
                                    title: 'Distancia',
                                    value: _distanceText,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _infoCard(
                                    icon: Icons.access_time,
                                    title: 'Tiempo',
                                    value: _durationText,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 26),

                            // =========================
                            // BOTON CANCELAR
                            // =========================
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _cancelando ? null : _cancelarViaje,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  side: BorderSide(color: Colors.red.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: _cancelando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Cancelar viaje',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // =========================
  // WIDGETS AUXILIARES
  // =========================

  Widget _circleAction(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 22,
        color: Colors.black, // 👈 COLOR ICONO
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
